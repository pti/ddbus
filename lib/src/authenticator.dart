import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rxdart/rxdart.dart';

import 'dbus_exception.dart';

/// Implements part of the DBUS authentication protocol described in https://dbus.freedesktop.org/doc/dbus-specification.html#auth-protocol.
class Authenticator {

  final IOSink _output;
  final LineHandler _lineHandler;

  Authenticator._internal(Stream<Uint8List> input, IOSink output):
    _lineHandler = LineHandler(output, input, lineEnd: '\r\n', timeout: Duration(seconds: 10)),
    _output = output;

  /// This function must be called immediately after opening the connection.
  void _start() {
    _output.add([0]);
  }

  /// Performs authentication using the EXTERNAL mechanism.
  /// https://dbus.freedesktop.org/doc/dbus-specification.html#auth-mechanisms.
  ///
  /// If the client was successfully authenticated, returns the GUID of the server (as a hex string).
  Future<String> _doExtAuth(String id) async {
    final idStr = id.toHexAsciiCodes();
    _lineHandler.writeLine('AUTH EXTERNAL $idStr');

    final resp = await _lineHandler.readLine();
    final match = RegExp(r'^OK ([a-fA-F0-9]+)$').firstMatch(resp);

    if (match == null) {
      throw DBusException('Authentication failure: $resp');
    }

    return match.group(1);
  }
  
  void _begin() {
    _lineHandler.writeLine('BEGIN');
  }

  static Future<String> externalAuthenticate(String id, Stream<Uint8List> input, IOSink output) async {
    final auth = Authenticator._internal(input, output);
    auth._start();
    final guid = await auth._doExtAuth(id);
    auth._begin();
    return guid;
  }
}

class LineHandler {

  final String _lineEnd;
  final IOSink _out;
  final Encoding _encoding;
  final Stream<Uint8List> _in;

  LineHandler(this._out, Stream<Uint8List> input, {String lineEnd = '\n', Duration timeout}):
        _in = timeout == null ? input : input.timeout(timeout),
        _lineEnd = lineEnd,
        _encoding = _out.encoding;

  void writeLine(String line) {
    _out.write(line);
    _out.write(_lineEnd);
  }

  Future<String> readLine() async {
    // TODO handle chars after the line end (if that is possible).
    final line = (await _in
        .map((data) => _encoding.decode(data))
        .bufferTest((str) => str.contains(_lineEnd))
        .first)
        .join();
    return line.substring(0, line.indexOf(_lineEnd));
  }
}

extension on String {
  String toHexAsciiCodes() => ascii.encode(this).map((e) => e.toRadixString(16)).join();
}
