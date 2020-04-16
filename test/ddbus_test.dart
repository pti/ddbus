import 'dart:convert';
import 'dart:typed_data';

import 'package:ddbus/ddbus.dart';
import 'package:ddbus/src/byte_reader.dart';
import 'package:ddbus/src/byte_writer.dart';
import 'package:ddbus/src/extensions.dart';
import 'package:test/test.dart';

void main() {

  group('ByteWriter', () {

    test('WriteBytesBeyondTmpCapacity', () {
      final bw = ByteWriter(Endian.little, initialCapacity: 10);
      final len = 16;

      for (var i = 0; i < len; i++) {
        bw.writeByte(i);
      }

      final bytes = bw.takeBytes();
      expect(bytes.lengthInBytes, len);

      for (var i = 0; i < len; i++) {
        expect(bytes[i], i);
      }
    });

    test('WriteString1', () {
      final bw = ByteWriter(Endian.big, initialCapacity: 10);
      final value1 = 0x1102CAFE;
      final value2 = 0x7F;
      final str = 'Hello world!';
      bw.writeUint32(value1);
      bw.writeString(str);
      bw.writeByte(value2);

      final bytes = bw.takeBytes();
      final expectedLen = 4 + (4 + str.length + 1) + 1;
      expect(bytes.lengthInBytes, expectedLen);

      final b = ByteData(expectedLen);
      var offset = 0;

      b.setUint32(0, value1);
      offset += 4;

      b.setUint32(offset, str.length);
      offset += 4;
      utf8.encode(str).forEach((c) => b.setUint8(offset++, c));
      b.setUint8(offset++, 0);

      b.setUint8(offset, value2);

      expect(b.buffer.asUint8List(), bytes);
    });

    test('WriteEmptyString', () {
      final bw = ByteWriter(Endian.big, initialCapacity: 1);
      bw.writeString('');

      final bytes = bw.takeBytes();
      expect(bytes.lengthInBytes, 5);
    });

    test('Struct1', () {
      final orig = DStruct([
        DUint32(101),
        DArray([DByte(1), DByte(2), DByte(3)]),
        DStruct([DString('foo'), DString('bar')]),
        DArray.dictionary({DUint16(1): DString('aa'), DUint16(2): DString('bb')}),
        DString('hello')
      ]);

      final bw = ByteWriter(Endian.big, initialCapacity: 1);
      orig.marshal(bw);
      final bytes = bw.takeBytes();

      final br = ByteReader.from(bytes.buffer, bw.endian);
      final res = br.readStruct('uay(ss)a{qs}s');
      expect(res[0], 101);
      expect(res[1], [1, 2, 3]);
      expect(res[2], ['foo', 'bar']);
      expect(res[3], {1: 'aa', 2: 'bb'});
      expect(res[4], 'hello');
    });
  });

  group('Array marshaling', () {

    test('Dictionary1', () {
      final orig = <String, int>{'a': 1, 'b': 2, 'c': 3};
      final array = DArray.dictionary(orig.map((key, value) => MapEntry(DString(key), DUint32(value))));
      _testArray(orig, array, 'a{su}');
    });

    test('ArrayStruct', () {
      final orig = {'a': 1, 'b': 2, 'c': 3}.entries.map((e) => [e.key, e.value]).toList();
      final array = DArray(orig.map((e) => DStruct([DString(e[0]), DUint32(e[1])])).toList());
      _testArray(orig, array, 'a(su)');
    });

    test('ArrayInt', () {
      final orig = [1, 2, 3, 4, 5, 7];
      final array = DArray(orig.map((e) => DByte(e)).toList());
      _testArray(orig, array, 'ay');
    });

    test('ArrayString', () {
      final orig = ['foo', 'bar'];
      final array = DArray(orig.map((e) => DString(e)).toList());
      _testArray(orig, array, 'as');
    });

    test('ArrayArray', () {
      final orig = [[0xCA, 0xFE], [0xDA, 0x75, 0x17]];
      final array = DArray(orig.map((e) => DArray(e.map((v) => DInt64(v)).toList())).toList());
      _testArray(orig, array, 'aax');
    });
  });

  group('Header tests', () {

    test('HeaderNoFields', () {
      _testHeader(Header(
        bodyBytes: 0,
        endian: Endian.little,
        type: MessageType.signal,
        majorProtocolVersion: supportedMajorProtocolVersion,
        serial: 42,
      ));
    });

    test('HeaderMethodCall1', () {
      _testHeader(Header.methodCall(
        endian: Endian.big,
        serial: 0x42,
        bodyBytes: 0xABCDEF12,
        member: 'Test',
      ));
    });

    test('HeaderMethodCall2a', () {
      _testHeader(Header.methodCall(
        serial: 0x42,
        bodyBytes: 0xABCDEF12,
        destination: 'org.freewilly.Fish',
        path: '/org.freewilly.Fish',
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Test',
      ), initialCapacity: 300);
    });

    test('HeaderMethodCall2b', () {
      _testHeader(Header.methodCall(
        serial: 0x42,
        bodyBytes: 0xABCDEF12,
        destination: 'org.freewilly.Fish',
        path: '/org.freewilly.Fish',
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Test',
      ), initialCapacity: 1);
    });

    test('Header+Body1', () {
      final header = Header.methodCall(
        serial: 1,
        destination: 'org.freewilly.Fish',
        path: '/org.freewilly.Fish',
        interface: 'org.freedesktop.DBus.Properties',
        member: 'Test',
        bodyBytes: 10
      );

      final bw = ByteWriter(header.endian);
      bw.writeMessage(header, DString('Hello'));

      final bytes = bw.takeBytes();

      final br = ByteReader.from(bytes.buffer, header.endian);
      final result = Header.unmarshal(br);

      expect(result, header);
    });
  });

  group('RuleTests', () {

    test('NameSpace', () {
      expect('com.example.backend1'.hasNamespace('com.example.backend1'), true);
      expect('com.example.backend1.foo'.hasNamespace('com.example.backend1'), true);
      expect('com.example.backend1.foo.bar'.hasNamespace('com.example.backend1'), true);
      expect('org.example.backend1.foo.bar'.hasNamespace('com.example.backend1'), false);
      expect('com.example.backend2'.hasNamespace('com.example.backend1'), false);
    });

    test('PathMatch', () {
      expect('/aa/bb/'.isPathMatch('/'), true);
      expect('/aa/bb/'.isPathMatch('/aa/'), true);
      expect('/aa/bb/'.isPathMatch('/aa/bb/'), true);
      expect('/aa/bb/'.isPathMatch('/aa/bb/cc/'), true);
      expect('/aa/bb/'.isPathMatch('/aa/bb/cc'), true);

      expect('/aa/bb/'.isPathMatch('/aa/b'), false);
      expect('/aa/bb/'.isPathMatch('/aa'), false);
      expect('/aa/bb/'.isPathMatch('/aa/bb'), false);
    });
  });
}

void _testHeader(Header header, {int initialCapacity = 32}) {
  final bw = ByteWriter(header.endian, initialCapacity: initialCapacity);
  header.marshal(bw);
  final bytes = bw.takeBytes();
  expect(bytes.lengthInBytes % 8, 0);

  final br = ByteReader.from(bytes.buffer, header.endian);
  final res = Header.unmarshal(br);

  expect(res, header);
}

void _testArray(dynamic expected, DArray array, String signature) {
  __testArray(expected, array, signature, Endian.little);
  __testArray(expected, array, signature, Endian.big);
}

void __testArray(dynamic expected, DArray array, String signature, Endian endian) {
  final bw = ByteWriter(endian);
  array.marshal(bw);
  final bytes = bw.takeBytes();

  final br = ByteReader.from(bytes.buffer, bw.endian);
  final result = br.read(signature);
  expect(result, expected);
}

Uint8List _parseBytes(String str) {
  final bytes = RegExp('([0-9a-f]{2})').allMatches(str).map((m) => int.parse(m.group(1), radix: 16)).toList();
  return Uint8List.fromList(bytes);
}
