import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'byte_reader.dart';
import 'byte_writer.dart';
import 'dbus_exception.dart';
import 'dbus_types.dart';
import 'extensions.dart';

const supportedMajorProtocolVersion = 1;

class Message {

  final Header header;
  final dynamic body;

  Message(this.header, this.body);

  @override
  String toString() => 'Message{$header, $body}';
}

class Header with Marshalable {

  static const Endian _defaultEndian = Endian.little;

  final Endian endian;
  final MessageType type;
  final Set<MessageFlag> flags;
  final int majorProtocolVersion;
  final int bodyBytes;
  final int serial;
  final Map<HeaderField, dynamic> fields;

  Header({
    this.endian = _defaultEndian,
    this.type,
    this.flags = const {},
    this.majorProtocolVersion = supportedMajorProtocolVersion,
    this.bodyBytes = 0,
    this.serial,
    this.fields = const {}
  });

  factory Header.methodCall({@required int serial, int bodyBytes = 0,
    Endian endian = _defaultEndian, Set<MessageFlag> flags = const {},
    String destination, String path, String interface, String member})
  {
    return Header(
        type: MessageType.methodCall,
        serial: serial,
        bodyBytes: bodyBytes ?? 0,
        endian: endian ?? _defaultEndian,
        flags: flags,
        fields: {
          HeaderField.destination: destination,
          HeaderField.path: path,
          HeaderField.interface: interface,
          HeaderField.member: member
        }.withoutNullValues()
      );
  }

  Header replyHeader({@required int serial, String errorName}) {
    return Header(
        endian: endian,
        type: errorName == null ? MessageType.methodReturn : MessageType.error,
        serial: serial,
        fields: {
          HeaderField.replySerial: this.serial,
          HeaderField.destination: sender,
          HeaderField.errorName: errorName
        }.withoutNullValues()
    );
  }

  factory Header.unmarshal(ByteReader msg) {
    msg.endian = msg.readByte().toEndian();
    final type = msg.readByte();

    if (type < _minValidMessageType || type > _maxValidMessageType) {
      throw DBusException('Invalid message type: $type');
    }

    final result = Header(
        endian: msg.endian,
        type: MessageType.values[min(type, MessageType.unknown.index)],
        flags: _parseFlags(msg.readByte()),
        majorProtocolVersion: msg.readByte(),
        bodyBytes: msg.readUint32(),
        serial: msg.readUint32(),
        fields: _readFields(msg)
    );

    msg.align(8);
    return result;
  }

  String get path => fields[HeaderField.path];
  String get interface => fields[HeaderField.interface];
  String get member => fields[HeaderField.member];
  String get errorName => fields[HeaderField.errorName];
  String get bodySignature => fields[HeaderField.signature];
  String get sender => fields[HeaderField.sender];
  String get destination => fields[HeaderField.destination];
  int get replySerial => fields[HeaderField.replySerial];

  static Map<HeaderField, dynamic> _readFields(ByteReader msg) {
    // Since the header item signature is predefined (yv) we can provide
    // a more explicit consumer and bypass the signature parsing part.
    final ret = <HeaderField, dynamic>{};

    msg.consumeArray(8, (src) {
      final index = src.readByte();
      if (index == 0 || index >= HeaderField.values.length) throw DBusException('Invalid header index $index');

      final field = HeaderField.values[index];
      final value = src.readVariant();
      ret[field] = value;
    });

    return ret;
  }

  static Set<MessageFlag> _parseFlags(int flagMask) {
    return MessageFlag.values
        .where((e) => flagMask & pow(2, e.index) > 0)
        .toSet();
  }

  int get _flagMask {
    if (flags == null || flags.isEmpty) return 0;
    return flags.map((f) => pow(2, f.index).toInt()).reduce((a, b) => a | b);
  }

  @override
  void marshal(ByteWriter out) {
    out.writeChar(out.endian == Endian.little ? 'l' : 'B');
    out.writeByte(type.index);
    out.writeByte(_flagMask);
    out.writeByte(majorProtocolVersion);
    out.writeUint32(bodyBytes ?? 0);
    out.writeUint32(serial);

    final fieldStructs = fields.entries
        .where((entry) => entry.value != null)
        .map((field) => DStruct([DByte(field.key.index), DVariant(field.key.asMarshalable(field.value))]))
        .toList(growable: false);
    out.writeArray(fieldStructs);

    out.align(8);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Header &&
          runtimeType == other.runtimeType &&
          endian == other.endian &&
          type == other.type &&
          majorProtocolVersion == other.majorProtocolVersion &&
          bodyBytes == other.bodyBytes &&
          serial == other.serial &&
          const SetEquality<MessageFlag>().equals(flags, other.flags) &&
          const MapEquality<HeaderField, dynamic>().equals(fields, other.fields);

  @override
  int get hashCode =>
      endian.hashCode ^
      type.hashCode ^
      flags.hashCode ^
      majorProtocolVersion.hashCode ^
      bodyBytes.hashCode ^
      serial.hashCode ^
      fields.hashCode;

  @override
  String toString() {
    final fieldStr = fields?.entries?.map((e) => '${e.key.name}=${e.value}')?.join(', ');
    final flagStr = flags?.map((e) => '${e.toString().lastPart()}')?.join(',');
    return 'Header{${type?.toString()?.lastPart()}, #$serial, '
        '$fieldStr, flags=$flagStr, v=$majorProtocolVersion, '
        'endian=${endian?.identifier}, bodyBytes=$bodyBytes}';
  }
}

enum MessageType {
  invalid,
  methodCall,
  methodReturn,
  error,
  signal,
  unknown
}

const _minValidMessageType = 1;
const _maxValidMessageType = 4;
const _messageTypeNames = ['invalid', 'method_call', 'method_return', 'error', 'signal', 'unknown'];

extension ExtraMessageType on MessageType {
  String get name => _messageTypeNames[index];
}

enum MessageFlag {
  noReplyExpected,
  noAutoStart,
  allowInteractiveAuthorization
}

enum HeaderField {
  invalid,
  path,
  interface,
  member,
  errorName,
  replySerial,
  destination,
  sender,
  signature,
  unixFds
}

extension on HeaderField {

  DValue asMarshalable(dynamic value) {
    if (value == null) return null;

    switch (this) {
      case HeaderField.path: return DObjectPath(value);
      case HeaderField.replySerial: return DUint32(value);
      case HeaderField.unixFds: return DUint32(value);
      case HeaderField.signature: return DSignature(value);
      case HeaderField.invalid: throw DBusException('Invalid header field');
      default: return DString(value);
    }
  }

  String get name => toString().lastPart();
}

extension on Endian {
  String get identifier => this == Endian.little ? 'l' : 'B';
}

extension on int {
  Endian toEndian() {

    switch (this) {
      case 0x6C: return Endian.little; // 'l'
      case 0x42: return Endian.big;    // 'B'
      default: throw DBusException('Invalid endian specifier: $this');
    }
  }
}
