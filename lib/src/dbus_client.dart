import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:rxdart/rxdart.dart';

import 'authenticator.dart';
import 'byte_reader.dart';
import 'byte_writer.dart';
import 'dbus_exception.dart';
import 'dbus_types.dart';
import 'error_name.dart';
import 'extensions.dart';
import 'match_rule.dart';
import 'message.dart';
import 'methods.dart';

class DBusClient {

  bool _closing = false;
  Socket _socket;
  var _nextSerial = 1;
  String _guid;
  String _busName;
  Stream<Uint8List> _inputStream;
  StreamSubscription<Message> _unmarshalSubscription;
  StreamSubscription<Message> _defaultMethodCallReplier;
  final _messageController = StreamController<Message>.broadcast();
  final _methodCallMatchers = <_MethodCallMatcher>[];

  static void Function(LogLevel level, LogType type, String text, Message message, dynamic error, StackTrace stack) logger;

  DBusClient._internal();

  Future<void> close() async {
    if (!isOpen) return;

    _closing = true;

    await _defaultMethodCallReplier?.cancel();
    _defaultMethodCallReplier = null;

    if (!_messageController.isClosed) await _messageController?.close();

    await _unmarshalSubscription?.cancel();
    _unmarshalSubscription = null;

    if (_socket != null) {
      await _socket.destroy();
      _socket = null;
    }

    _closing = false;
  }

  bool get isOpen => !_closing && _socket != null;

  /// The unique connection name acquired automatically after opening the connection with a [hello] call.
  String get busName => _busName;

  String get guid => _guid;

  int get nextSerial => _nextSerial++;

  static Future<DBusClient> session({String address, String uid}) async {
    address ??= _acquireSessionAddress(uid);
    return DBusClient._internal()._open(address, uid);
  }

  static Future<DBusClient> system({String address, String uid}) async {
    address ??= Platform.environment['DBUS_SYSTEM_BUS_ADDRESS'] ?? 'unix:path=/run/dbus/system_bus_socket';
    uid ??= _extractUid(_acquireSessionAddress(null));
    return DBusClient._internal()._open(address, uid);
  }

  Future<DBusClient> _open(String address, String uid) async {
    uid = uid ?? Platform.environment['UID'] ?? _extractUid(address);

    _socket = await _connectSocket(address, uid);
    _inputStream = _socket.asBroadcastStream(onListen: (_) => print('LISTEN'), onCancel: (_) => print('CANCEL'));
    _guid = await Authenticator.externalAuthenticate(uid, _inputStream, _socket);

    _inputStream.listen(null,
      onError: (err) {
        _log(level: LogLevel.error, text: 'Error reading socket', error: err);
        close();
      },
      onDone: () {
        close();
      },
      cancelOnError: true
    );

    _unmarshalSubscription = _inputStream
      .map(_unmarshalMessages)
      .expand((message) => message)
      .listen((message) => _messageController.add(message));

    _defaultMethodCallReplier = _messageController.stream
        .where((msg) => msg.header.type == MessageType.methodCall && !_methodCallMatchers.any((m) => m.isMatch(msg.header)))
        .listen((msg) => sendReply(msg, errorName: ErrorName.unknownMethod));

    _busName = await hello();

    return this;
  }

  Stream<Message> methodCallStream({Pattern path, Pattern interface, Pattern member}) {
    final matcher = _MethodCallMatcher(path, interface, member);
    _methodCallMatchers.add(matcher);

    return _messageController.stream
        .where((msg) => msg.header.type == MessageType.methodCall && matcher.isMatch(msg.header));
  }

  Stream<Message> signalStream({String path, String interface, String member, String sender}) {
    final rule = MatchRule(type: MessageType.signal, sender: sender, path: path, interface: interface,
        member: member);
    final ruleStr = rule.toRuleString();
    var stream = _messageController.stream;

    if (rule != null) {
      stream = stream
          .doOnListen(() => _setMatch(ruleStr, true))
          .doOnCancel(() => _setMatch(ruleStr, false));
    }

    return stream.where((msg) => rule.isMatch(msg));
  }

  void _setMatch(String rule, bool enabled) async {

    try {
      // Avoid sending messages if client is closed or being closed.
      if (isOpen) await (enabled ? addMatch(rule) : removeMatch(rule));
    } catch (err, stack) {
      if (!isOpen && err is DBusCallException && err.message == 'Connection closed') return;
      _log(text: 'error ${enabled ? 'adding' : 'removing'} match rule', error: err, stack: stack, level: LogLevel.error);
    }
  }

  /// Calls the specified method, waits for the reply and returns the reply's body.
  Future<T> callMethod<T>({
    String destination,
    String path,
    String interface,
    String member,
    dynamic body,
  }) async {
    final header = Header.methodCall(
        serial: nextSerial,
        destination: destination,
        path: path,
        interface: interface,
        member: member,
    );

    sendMessage(header, body);
    return (await waitForReply(header)).body as T;
  }

  /// Sends a reply to message [call]. Optional [body] parameter is the reply message body.
  /// [body] can be a single [DValue] or a list of [DValue] objects.
  void sendReply(Message call, {dynamic body, String errorName}) {
    final header = call.header.replyHeader(serial: nextSerial, errorName: errorName);
    sendMessage(header, body);
  }

  /// [body] can be a single [DValue] or a list of [DValue] objects.
  void sendMessage(Header header, [dynamic body]) {
    if (!isOpen) throw DBusException('Client is closed');

    _log(type: LogType.send, message: Message(header, body));
    final out = ByteWriter(header.endian);
    out.writeMessage(header, body);
    final bytes = out.takeBytes();
    _socket.add(bytes);
  }

  Future<Message> waitForReply(Header header, {Duration timeout = const Duration(seconds: 3)}) async {

    final reply = await _messageController.stream
        .firstWhere((msg) => msg.header.replySerial == header.serial, orElse: () => null)
        .timeout(timeout);

    if (reply == null) {
      throw DBusCallException(header, null, isOpen ? 'Call timed out' : 'Connection closed');
    }

    if (reply.header.type == MessageType.error) {
      throw DBusCallException(header, reply);
    }

    return reply;
  }

  void _log({String text, LogLevel level = LogLevel.debug, Message message,
    LogType type = LogType.other, dynamic error, StackTrace stack})
  {
    if (logger != null) logger(level, type, text, message, error, stack);
  }
  
  List<Message> _unmarshalMessages(Uint8List event) {
    final result = <Message>[];
    
    try {
      const minHeaderBytes = 16;
      final br = ByteReader.from(event.buffer);

      // A single event can sometimes contain multiple messages.
      // Assuming that a message is always included completely in a single event.
      while (br.remaining >= minHeaderBytes) {
        final header = Header.unmarshal(br);
        final msgEnd = br.byteOffset + header.bodyBytes;

        try {
          final bodySig = header.bodySignature;
          final body = bodySig?.isNotEmpty == true ? br.read(bodySig) : null;
          final msg = Message(header, body);

          _log(type: LogType.received, message: msg);
          result.add(msg);

        } catch (err, stack) {
          // Invalid body or more likely a bug in ByteReader implementation. Since the header
          // was read ok, skip to the end of the message (and ignore the message) in case there
          // are more messages after this one.
          _log(type: LogType.unmarshaling, text: 'Error reading message body', error: err, stack: stack);
          br.byteOffset = msgEnd;
        }

        br.markStart();
      }

    } catch (err, stack) {
      _log(type: LogType.unmarshaling, error: err, stack: stack);
    }

    return result;
  }
}

Future<Socket> _connectSocket(String address, String uid) {

  if (uid == null) {
    throw DBusException('UID unknown - cannot proceed with authentication');
  }

  const prefix = 'unix:path=';

  if (!address.startsWith(prefix)) {
    throw DBusException('D-Bus address type not supported: $address');
  }

  final path = address.substring(prefix.length);
  return Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0);
}

String _acquireSessionAddress(String uid) {
  var address = Platform.environment['DBUS_SESSION_BUS_ADDRESS'];

  if (address == null) {
    var runtimeDir = Platform.environment['XDG_USER_DIR'];

    if (runtimeDir == null) {
      uid = uid ?? Platform.environment['UID'];

      if (uid == null) {
        throw DBusException('UID undefined - cannot figure out runtime path');
      }

      runtimeDir = '/run/user/${uid}';
    }

    address = 'unix:path=${runtimeDir}/bus';
  }

  return address;
}

String _extractUid(String address) {
  if (address == null) return null;
  final match = RegExp(r'/([0-9]+)/bus$').firstMatch(address);
  return match?.group(1);
}

enum LogLevel {
  error,
  debug
}

enum LogType {
  unmarshaling,
  received,
  send,
  other
}

extension LogTypeExtra on LogType {
  String get name => toString().lastPart();
}

class _MethodCallMatcher {

  final Pattern path;
  final Pattern interface;
  final Pattern member;

  _MethodCallMatcher(this.path, this.interface, this.member);

  bool isMatch(Header header) {
    return (path == null || _isMatch(header.path, path))
        && (interface == null || _isMatch(header.interface, interface))
        && (member == null || _isMatch(header.member, member));
  }

  bool _isMatch(String str, Pattern pattern) {

    if (pattern is String) {
      return str == pattern;
    } else if (pattern is RegExp) {
      return pattern.hasMatch(str);
    } else {
      return pattern.matchAsPrefix(str) != null;
    }
  }
}
