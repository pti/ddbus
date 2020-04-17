import 'dart:convert';
import 'dart:typed_data';

import 'dbus_exception.dart';
import 'extensions.dart';
import 'type_code.dart';

class ByteReader {

  ByteData data;
  Endian endian;
  int byteOffset;

  ByteReader(this.data, {this.byteOffset = 0, this.endian = Endian.little});

  ByteReader.from(ByteBuffer buffer, [Endian endian = Endian.little]): this(ByteData.view(buffer), endian: endian);

  int get remaining => data.lengthInBytes - byteOffset;

  /// Resets the reader's start offset to the current [byteOffset].
  /// This is useful when reading multiple consecutive messages from the same buffer as the
  /// alignment is always relative to the first byte of a message.
  void markStart() {
    if (remaining <= 0) return;
    data = ByteData.view(data.buffer, data.offsetInBytes + byteOffset, remaining);
    byteOffset = 0;
  }

  int readByte() => data.getUint8(byteOffset++);
  bool readBoolean() => readUint32() == 1;

  int readUint16() => data.getUint16(_offset(2), endian);
  int readInt16() => data.getInt16(_offset(2), endian);
  int readUint32() => data.getUint32(_offset(4), endian);
  int readInt32() => data.getInt32(_offset(4), endian);
  int readUint64() => data.getUint64(_offset(8), endian);
  int readInt64() => data.getInt64(_offset(8), endian);
  double readDouble() => data.getFloat64(_offset(8), endian);
  int readUnixFd() => readUint32();

  String readString() {
    final len = readUint32();
    return _readStringBytes(len);
  }

  String _readStringBytes(int len) {
    final bytes = data.buffer.asUint8List(data.offsetInBytes + byteOffset, len);
    final str = utf8.decode(bytes);
    byteOffset += len + 1; // Skip the terminating null byte.
    return str;
  }

  String readObjectPath() => readString();

  String readSignature() {
    final len = readByte();
    return _readStringBytes(len);
  }

  dynamic readVariant() {
    final signature = readSignature();

    if (signature.isEmpty) {
      return null;
    }

    final handlers = _parseSignature(signature) as List;

    if (handlers.length != 1) {
      throw DBusException('Variant can only contain a single complete type (was "$signature")');
    }

    return _callHandler(handlers.first);
  }

  /// Return value is either a List or a Map. The latter is used when the array item type
  /// is an dict_entry. If the item type is a basic type (int, double, bool, String) then
  /// the returned List is typed accordingly.
  dynamic readArray(String itemSignature) {
    final handlers = _parseSignature(itemSignature, insideArray: true) as List;
    if (handlers.length != 1) throw DBusException('Array item type must be a single complete type (was "$itemSignature")');
    return _readArray(handlers.first, itemSignature);
  }

  dynamic _readArray(dynamic subHandler, String itemSignature) {
    final itemAlignment = TypeCode.alignmentBoundary(itemSignature);

    if (subHandler is _ContainerReader && subHandler.handler == _readDictEntry) {
      final map = {};

      consumeArray(itemAlignment, (src) {
        final items = _readDictEntry(subHandler.subHandler, itemSignature);
        map[items[0]] = items[1];
      });

      return map;

    } else if (subHandler is _ContainerReader) {
      final items = [];
      consumeArray(itemAlignment, (src) =>
          items.add(subHandler.handler(subHandler.subHandler, subHandler.subSignature)));
      return items;

    } else {
      final items = _newTypedArray(itemSignature);
      consumeArray(itemAlignment, (src) => items.add(subHandler()));
      return items;
    }
  }

  void consumeArray(int itemAlignment, void Function(ByteReader src) itemReader) {
    if (byteOffset >= data.lengthInBytes) return;

    final dataBytes = readUint32();
    align(itemAlignment);
    final endOffset = byteOffset + dataBytes;

    while (byteOffset < endOffset) {
      itemReader(this);

      // Assuming that item alignment needs to be done before testing whether array end has been reached.
      align(itemAlignment);
    }
  }

  List<dynamic> readStruct(String signature) {
    if (signature.isEmpty) throw DBusException('Empty structs are not allowed');

    final handlers = _parseSignature(signature);
    return _readStruct(handlers, signature);
  }

  List<dynamic> _readStruct(dynamic subHandlers, String subSignature) {
    align(8);
    return subHandlers.map(_callHandler).toList(growable: false);
  }

  List<dynamic> _readDictEntry(dynamic subHandlers, String subSignature) {
    return _readStruct(subHandlers, subSignature);
  }

  dynamic read(String signature, {bool insideArray = false}) {
    final handlers = _parseSignature(signature) as List;

    if (handlers.length == 1) {
      return _callHandler(handlers.first);
    } else {
      return handlers.map(_callHandler).toList(growable: false);
    }
  }

  int _offset(int delta) {
    align(delta);

    final current = byteOffset;
    byteOffset += delta;
    return current;
  }

  void align(int boundary) => byteOffset += byteOffset.toNextMultiple(boundary);

  List _newTypedArray(String itemSignature) {

    if (itemSignature.length == 1) {

      if (TypeCode.stringTypes.contains(itemSignature)) {
        return <String>[];

      } else if (TypeCode.intTypes.contains(itemSignature)) {
        return <int>[];

      } else if (itemSignature == TypeCode.double) {
        return <double>[];

      } else if (itemSignature == TypeCode.boolean) {
        return <bool>[];
      }
    }

    return [];
  }
  
  dynamic _parseSignature(String signature, {bool insideArray = false, bool single = false}) {
    final handlers = [];
    var i = 0;
    
    while (i < signature.length) {
      final char = signature[i];
      
      if (char == TypeCode.variant) {
        handlers.add(readVariant);
        i += 1;
        
      } else if (char == '(') {
        final end = signature.findClosingBracket(i);
        if (end == -1 || end <= i) throw DBusException('Invalid struct signature in "$signature" (index=$i)');

        final subSignature = signature.substring(i + 1, end);
        final subHandlers = _parseSignature(subSignature);
        handlers.add(_ContainerReader(signature.substring(i, end + 1), _readStruct, subHandlers, subSignature));
        i = end + 1;

      } else if (char == '{') {
        if (!insideArray) throw DBusException('dict_entry can only be used as an array item type');
        final end = signature.findClosingBracket(i, open: '{', close: '}');
        if (end == -1 || end <= i) throw DBusException('Invalid dict_entry signature in "$signature" (index=$i)');

        final subSignature = signature.substring(i + 1, end);
        final subHandlers = _parseSignature(subSignature);

        if (subHandlers is! List || (subHandlers as List).length != 2) {
          throw DBusException('dict_entry must have two single complete types (was "$subSignature")');
        }

        final keySignature = subSignature[0];

        if (!TypeCode.basicTypes.contains(keySignature)) {
          throw DBusException('dict_entry key type "$keySignature" is not a basic type');
        }

        handlers.add(_ContainerReader(signature.substring(i, end + 1), _readDictEntry, subHandlers, subSignature));
        i = end + 1;

      } else if (char == TypeCode.array) {
        if (i == signature.length - 1) throw DBusException('Undefined array item type');

        final remainingSignatures = signature.substring(i + 1);
        final subHandler = _parseSignature(remainingSignatures, insideArray: true, single: true);

        var subSignature = signature[i + 1];
        if (subHandler is _ContainerReader) {
          subSignature = subHandler.signature;
        }

        final end = i + subSignature.length;
        handlers.add(_ContainerReader(signature.substring(i, end + 1), _readArray, subHandler, subSignature));
        i = end + 1;

      } else {
        handlers.add(_readerForBasicSignature(char));
        i += 1;
      }

      if (single) {
        return handlers.first;
      }
    }

    return handlers;
  }
  
  _SingleTypeReader _readerForBasicSignature(String signature) {
    
    switch (signature) {
      case TypeCode.boolean: return readBoolean;
      case TypeCode.byte: return readByte;
      case TypeCode.int16: return readInt16;
      case TypeCode.uint16: return readUint16;
      case TypeCode.int32: return readInt32;
      case TypeCode.uint32: return readUint32;
      case TypeCode.int64: return readInt64;
      case TypeCode.uint64: return readUint64;
      case TypeCode.double: return readDouble;
      case TypeCode.string: return readString;
      case TypeCode.objectPath: return readObjectPath;
      case TypeCode.signature: return readSignature;
      case TypeCode.unixFD: return readUnixFd;
      default: throw DBusException('Invalid signature: $signature');
      break;
    }
  }
  
  dynamic _callHandler(dynamic handler) {

    if (handler is _SingleTypeReader) {
      return handler.call();

    } else {
      final cs = handler as _ContainerReader;

      final ret = cs.handler(cs.subHandler, cs.subSignature);
      return ret;
    }
  }
}

typedef _SingleTypeReader = dynamic Function();

class _ContainerReader {

  final dynamic subHandler;
  final String signature;
  final String subSignature;
  final dynamic Function(dynamic subHandler, String subSignature) handler;

  _ContainerReader(this.signature, this.handler, this.subHandler, this.subSignature);
}
