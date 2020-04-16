import 'dbus_exception.dart';

class TypeCode {

  static const byte = 'y';
  static const boolean = 'b';
  static const int16 = 'n';
  static const uint16 = 'q';
  static const int32 = 'i';
  static const uint32 = 'u';
  static const int64 = 'x';
  static const uint64 = 't';
  static const double = 'd';
  static const unixFD = 'h';

  static const string = 's';
  static const objectPath = 'o';
  static const signature = 'g';

  static const struct = 'r';
  static const array = 'a';
  static const variant = 'v';
  static const dictEntry = 'e';

  static const intTypes = {byte, boolean, int16, uint16, int32, uint32,
    int64, uint64, double, unixFD};

  static const stringTypes = {string, objectPath, signature};

  static const basicTypes = {byte, boolean, int16, uint16, int32, uint32,
    int64, uint64, double, unixFD, string, objectPath, signature};

  /// Returns the alignment boundary (in bytes) of the first type specified in [signature].
  static int alignmentBoundary(String signature) {
    final typeCode = signature[0];

    if (typeCode == '(' || typeCode == '{') return 8; // Struct or dict entry:

    switch (typeCode) {
      case byte:
      case TypeCode.signature:
      case variant:
        return 1;

      case int16:
      case uint16:
        return 2;

      case boolean:
      case int32:
      case uint32:
      case unixFD:
      case array:
      case string:
      case objectPath:
        return 4;

      case int64:
      case uint64:
      case double:
        return 8;

      default:
        throw DBusException('Unsupported signature: $signature}');
    }
  }

  TypeCode._internal();
}
