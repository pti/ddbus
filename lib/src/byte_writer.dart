import 'dart:convert';
import 'dart:typed_data';

import 'extensions.dart';

/// Maintains a byte buffer and provides functions for writing basic D-Bus data types into it.
class ByteWriter {

  final Endian endian;
  final int _initialCapacity;
  Uint8List _buffer;
  ByteData _view;
  var _offset = 0;

  ByteWriter(this.endian, {int initialCapacity = 128}):
        _buffer = Uint8List(initialCapacity),
        _initialCapacity = initialCapacity,
        assert(initialCapacity > 0)
  {
    _view = ByteData.sublistView(_buffer);
  }

  /// Ensures that all bytes have been written and returns the underlying buffer.
  Uint8List takeBytes() {
    _ensureCapacity(0, extra: 0);
    return _buffer.buffer.asUint8List(_buffer.offsetInBytes, _offset);
  }

  int get byteOffset => _offset;

  void align(int boundary) => _offset += _offset.toNextMultiple(boundary);
  
  void writeByte(int value) => _prepare(1, (offset) => _view.setUint8(offset, value));
  void writeUint16(int value) => _prepare(2, (offset) => _view.setUint16(offset, value, endian));
  void writeInt16(int value) => _prepare(2, (offset) => _view.setInt16(offset, value, endian));
  void writeUint32(int value) => _prepare(4, (offset) => _view.setUint32(offset, value, endian));
  void writeInt32(int value) => _prepare(4, (offset) => _view.setInt32(offset, value, endian));
  void writeUint64(int value) => _prepare(8, (offset) => _view.setUint64(offset, value, endian));
  void writeInt64(int value) => _prepare(8, (offset) => _view.setInt64(offset, value, endian));
  void writeDouble(double value) => _prepare(8, (offset) => _view.setFloat64(offset, value, endian));
  void writeUnixFd(int value) => writeUint32(value);
  void writeBoolean(bool value) => writeUint32(value ? 1 : 0);
  void writeChar(String char) => writeByte(char.codeUnitAt(0));

  void setUint32(int byteOffset, int value) => _view.setUint32(byteOffset, value, endian);

  void writeString(String value) => _writeString(value, 4);
  void writeObjectPath(String value) => writeString(value);
  void writeSignature(String value) => _writeString(value, 1);

  void _writeString(String value, int lengthSize) {

    if (value.isEmpty) {
      // No need to write 0-bytes yet.
      align(lengthSize);
      _offset += lengthSize + 1;
      return;
    }
    
    final bytes = utf8.encode(value);
    _ensureCapacity(bytes.length + lengthSize + 1);
    lengthSize == 1 ? writeByte(bytes.length) : writeUint32(bytes.length);
    writeBytes(bytes);
    writeByte(0);
  }

  void writeBytes(Uint8List bytes) {
    _ensureCapacity(bytes.lengthInBytes);

    final end = _offset + bytes.lengthInBytes;
    _buffer.setRange(_offset, end, bytes, _buffer.offsetInBytes);
    _offset = end;
  }
  
  void _prepare(int bytes, void Function(int offset) writer) {
    align(bytes);
    _ensureCapacity(bytes);
    writer(_offset);
    _offset += bytes;
  }

  void _ensureCapacity(int bytes, {int extra}) {
    final requiredCapacity = _offset + bytes;

    if (requiredCapacity > _buffer.lengthInBytes) {
      final tmp = Uint8List(requiredCapacity + (extra ?? _initialCapacity));
      tmp.setRange(0, _buffer.lengthInBytes, _buffer, _buffer.offsetInBytes);
      _buffer = tmp;
      _view = ByteData.sublistView(_buffer);
    }
  }
}
