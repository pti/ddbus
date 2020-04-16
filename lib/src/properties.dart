import 'package:collection/collection.dart';

import 'dbus_client.dart';
import 'dbus_types.dart';
import 'message.dart';
import 'service.dart';

mixin DProperties {

  DService get service;

  DBusClient get client => service.client;
  String get destination => service.destination;
  String get path => service.path;
  String get interface => service.interface;

  Future<T> getProperty<T>(String name) =>
      client.getProperty(destination: destination, path: path, interface: interface, name: name);

  Future<void> setProperty(String name, DValue value) =>
      client.setProperty(destination: destination, path: path, interface: interface, name: name, value: value);

  Future<Map<String, dynamic>> getAllProperties() =>
      client.getAllProperties(destination: destination, path: path, interface: interface);

  /// If [limitSender] is true, then limit signals to those sent by [destination]. In that case
  /// the [destination] must be a unique connection name.
  Stream<PropertiesChanged> propertiesChanged({bool limitSender = false}) =>
      client.signalStream(
        sender: limitSender ? destination : null,
        path: path,
        interface: PropertiesClient.propertiesInterface,
        member: 'PropertiesChanged',
      )
          .map((signal) => PropertiesChanged.from(signal))
          .where((signal) => interface == null || signal.interface == interface);
}

extension PropertiesClient on DBusClient {

  static const propertiesInterface = 'org.freedesktop.DBus.Properties';

  Future<T> getProperty<T>({String destination, String path, String interface, String name}) async {
    return await callMethod<T>(
        destination: destination,
        path: path,
        interface: propertiesInterface,
        member: 'Get',
        body: [DString(interface), DString(name)]);
  }

  Future<void> setProperty({String destination, String path,
    String interface, String name, DValue value}) async
  {
    await callMethod(
        destination: destination,
        path: path,
        interface: propertiesInterface,
        member: 'Set',
        body: [DString(interface), DString(name), DVariant(value)]);
  }

  Future<Map<String, dynamic>> getAllProperties({String destination, String path, String interface}) async {
    final result = await callMethod<Map>(
        destination: destination,
        path: path,
        interface: propertiesInterface,
        member: 'GetAll',
        body: DString(interface));
    return result.map((key, value) => MapEntry(key as String, value));
  }
}

class PropertiesChanged {

  final String interface;
  final Map<String, dynamic> changed;
  final List<String> invalidated;

  PropertiesChanged(this.interface, this.changed, this.invalidated);

  PropertiesChanged.from(Message signal): this(
      signal.body[0] as String,
      (signal.body[1] as Map).map((key, value) => MapEntry(key as String, value)),
      signal.body[2] as List<String>);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PropertiesChanged &&
            runtimeType == other.runtimeType &&
            interface == other.interface &&
            const DeepCollectionEquality.unordered().equals(changed, other.changed) &&
            const ListEquality<String>().equals(invalidated, other.invalidated);
  }

  @override
  int get hashCode => interface.hashCode ^ changed.hashCode ^ invalidated.hashCode;
}
