import 'byte_writer.dart';
import 'dbus_exception.dart';
import 'extensions.dart';
import 'message.dart';
import 'type_code.dart';

mixin Marshalable {
  void marshal(ByteWriter out);
}

/// D-Bus -type specific classes are used for marshaling purposes (writing D-Bus messages).
///
/// Assuming that the type specific classes serve no purpose on the application layer
/// other than writing messages, so unmarshaling a message results in values of standard Dart types.
/// Thus, no unmarshal functions are provided for these classes.
abstract class DValue with Marshalable {

  final String signature;

  const DValue(this.signature);

  @override
  void marshal(ByteWriter out);
}

abstract class DBasicType extends DValue {
  const DBasicType(String signature): super(signature);

  dynamic get value;

  @override
  String toString() => '${runtimeType}($value)';
}

abstract class DContainerType extends DValue {
  const DContainerType(String signature): super(signature);
}

class DStruct extends DContainerType {

  final List<DValue> fields;
  final String fieldSignature;

  DStruct([List<DValue> fields, String fieldSignature]):
        fields = fields ?? [],
        fieldSignature = fieldSignature ?? fields.signatures,
        assert(!fields.any((f) => f is DDictEntry)),
        super(TypeCode.struct);

  @override
  String get signature => '(' + fieldSignature + ')';

  @override
  void marshal(ByteWriter out) {
    if (fields.isEmpty) throw DBusException('Empty structs are not allowed');
    out.align(8);
    fields.forEach((f) => f.marshal(out));
  }

  @override
  String toString() => '${runtimeType}$fields';
}

class DArray<T extends DValue> extends DContainerType {

  final String itemSignature;
  final List<T> items;

  /// All items must be of the same type.
  /// Item signature must be provided for container types ([DArray], [DStruct] or [DDictEntry]).
  DArray([this.items = const [], String itemSignature]):
        itemSignature = itemSignature ?? items.firstOrNull?.signature ?? codeForType(T),
        super(TypeCode.array)
  {
    if (this.itemSignature == null) {
      throw DBusException('Item signature not defined');
    }
  }

  static DArray<DDictEntry> dictionary(Map<DBasicType, DValue> dictionary, [String itemSignature]) {

    if (dictionary.isEmpty && itemSignature == null) {
      throw DBusException('Cannot derive item signature from an empty map');
    }

    final items = dictionary.entries.map((e) => DDictEntry(e.key, e.value)).toList();
    return DArray<DDictEntry>(items, '{$itemSignature}');
  }

  @override
  String get signature => TypeCode.array + itemSignature;

  @override
  void marshal(ByteWriter out) => DByteWriter(out).writeArray(items);

  @override
  String toString() => '${runtimeType}($itemSignature, $items)';
}

extension DByteWriter on ByteWriter {

  void writeArray<T extends DValue>(List<T> items) {
    final lengthOffset = byteOffset;
    writeUint32(0);

    // Presumably the item alignment is required for empty arrays too, so do it here rather than in item.marshal().
    // https://lists.freedesktop.org/archives/dbus/2016-July/016972.html
    align(_alignmentForType(T));

    final dataOffset = byteOffset;
    items.forEach((item) => item.marshal(this));

    final itemBytes = byteOffset - dataOffset;
    setUint32(lengthOffset, itemBytes);
  }

  void writeMessage(Header header, [dynamic body]) {
    assert(body == null || body is DValue || body is List<DValue>);

    if (body != null && header.bodySignature == null) {
      header.fields[HeaderField.signature] = _bodySignature(body);
    }

    header.marshal(this);

    if (body != null) {
      final bodyStart = byteOffset;

      if (body is DValue) {
        body.marshal(this);
      } else if (body is List<DValue>) {
        body.forEach((arg) => arg.marshal(this));
      } else {
        throw DBusException('body must be a DValue or List<DValue>');
      }

      final bodyLen = byteOffset - bodyStart;
      setUint32(4, bodyLen); // Update body length now that it is known.
    }
  }

  String _bodySignature(dynamic body) {
    return body is DValue ? body.signature : (body as List<DValue>).signatures;
  }
}

/// Dict entries should only be used inside arrays.
class DDictEntry extends DContainerType {

  final DBasicType key;
  final DValue value;

  DDictEntry(this.key, this.value):
        assert(value is! DDictEntry),
        super(TypeCode.dictEntry);

  @override
  String get signature => '{' + key.signature + value.signature + '}';

  @override
  void marshal(ByteWriter out) {
    out.align(8);
    key.marshal(out);
    value.marshal(out);
  }

  @override
  String toString() => '$runtimeType(key=$key, value=$value)';
}

class DVariant extends DContainerType {

  final DValue value;

  const DVariant(this.value):
        assert(value != null),
        super(TypeCode.variant);

  @override
  void marshal(ByteWriter out) {
    out.writeSignature(value.signature);
    value.marshal(out);
  }

  @override
  String toString() => '$runtimeType($value)';
}

class DBoolean extends DBasicType {

  @override
  final bool value;

  const DBoolean(this.value): assert(value != null), super(TypeCode.boolean);

  @override
  void marshal(ByteWriter out) => out.writeBoolean(value);
}

class DByte extends DBasicType {

  @override
  final int value;

  const DByte(this.value): assert(value != null), super(TypeCode.byte);

  @override
  void marshal(ByteWriter out) => out.writeByte(value);
}

class DUint16 extends DBasicType {

  @override
  final int value;

  const DUint16(this.value): assert(value != null), super(TypeCode.uint16);

  @override
  void marshal(ByteWriter out) => out.writeUint16(value);
}

class DInt16 extends DBasicType {

  @override
  final int value;

  const DInt16(this.value): assert(value != null), super(TypeCode.int16);

  @override
  void marshal(ByteWriter out) => out.writeInt16(value);
}

class DUint32 extends DBasicType {

  @override
  final int value;

  const DUint32(this.value): assert(value != null), super(TypeCode.uint32);

  @override
  void marshal(ByteWriter out) => out.writeUint32(value);
}

class DInt32 extends DBasicType {

  @override
  final int value;

  const DInt32(this.value): assert(value != null), super(TypeCode.int32);

  @override
  void marshal(ByteWriter out) => out.writeInt32(value);
}

class DUint64 extends DBasicType {

  @override
  final int value;

  const DUint64(this.value): assert(value != null), super(TypeCode.uint64);

  @override
  void marshal(ByteWriter out) => out.writeUint64(value);
}

class DInt64 extends DBasicType {

  @override
  final int value;

  const DInt64(this.value): assert(value != null), super(TypeCode.int64);

  @override
  void marshal(ByteWriter out) => out.writeInt64(value);
}

class DDouble extends DBasicType {

  @override
  final double value;

  const DDouble(this.value): assert(value != null), super(TypeCode.double);

  @override
  void marshal(ByteWriter out) => out.writeDouble(value);
}

class DUnixFD extends DBasicType {

  @override
  final int value;

  const DUnixFD(this.value): assert(value != null), super(TypeCode.unixFD);

  @override
  void marshal(ByteWriter out) => out.writeUnixFd(value);
}

class DString extends DBasicType {

  @override
  final String value;

  const DString(this.value): assert(value != null), super(TypeCode.string);

  @override
  void marshal(ByteWriter out) => out.writeString(value);
}

class DObjectPath extends DBasicType {

  @override
  final String value;

  const DObjectPath(this.value): assert(value != null), super(TypeCode.objectPath);

  @override
  void marshal(ByteWriter out) => out.writeObjectPath(value);
}

class DSignature extends DBasicType {

  @override
  final String value;

  const DSignature(this.value): assert(value != null), super(TypeCode.signature);

  @override
  void marshal(ByteWriter out) => out.writeSignature(value);
}

extension on List<DValue> {
  String get signatures => map((v) => v.signature).join();
}

String codeForType(Type type) {

  switch (type) {
    case DByte: return TypeCode.byte;
    case DBoolean: return TypeCode.boolean;
    case DInt16: return TypeCode.int16;
    case DUint16: return TypeCode.uint16;
    case DInt32: return TypeCode.int32;
    case DUint32: return TypeCode.uint32;
    case DInt64: return TypeCode.int64;
    case DUint64: return TypeCode.uint64;
    case DDouble: return TypeCode.double;
    case DUnixFD: return TypeCode.unixFD;
    case DString: return TypeCode.string;
    case DObjectPath: return TypeCode.objectPath;
    case DSignature: return TypeCode.signature;
    case DVariant: return TypeCode.variant;

    case DStruct:
    case DArray:
    case DDictEntry:
    default:
      return null;
  }
}

int _alignmentForType(Type type) {

  switch (type) {
    case DByte:
    case DSignature:
    case DVariant:
      return 1;

    case DInt16:
    case DUint16:
      return 2;

    case DBoolean:
    case DInt32:
    case DUint32:
    case DUnixFD:
    case DString:
    case DObjectPath:
      return 4;

    case DInt64:
    case DUint64:
    case DDouble:
    case DStruct:
    case DDictEntry:
      return 8;

    case DArray:
    default:
      // Questionable code yes, but couldn't figure a way to check if Type is a DArray<?> type
      // + there aren't other supported types left. An instance isn't necessarily available
      // when this function gets called (empty array).
      return 4;
  }
}
