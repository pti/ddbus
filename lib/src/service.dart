import 'package:ddbus/ddbus.dart';

/// Simplifies calling methods of a specific service instance.
class DService {

  final DBusClient client;
  final String destination;
  final String path;
  final String interface;

  DService(this.client, this.destination, this.path, this.interface);

  Future<T> callMethod<T>(String member) => client.callMethod<T>(
      destination: destination,
      path: path,
      interface: interface,
      member: member
  );
}
