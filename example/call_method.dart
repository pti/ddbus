import 'package:ddbus/ddbus.dart';

void main() async {
  DBusClient client;

  try {
    client = await DBusClient.system();

    final cid = await client.getId();
    print('client id: $cid');

    final service = Hostname1(client);
    final hostname = await service.getProperty<String>('Hostname');
    print('hostname: $hostname');
    final properties = await service.getAllProperties();
    print('properties: $properties');

    final names = await client.listNames();
    print('names: $names');

    try {
      await client.callMethod(
          destination: 'org.freedesktop.hostname1',
          path: '/org/freedesktop/hostname1',
          interface: 'org.freedesktop.DBus.Peer',
          member: 'Ping2',
          body: <DValue>[]);
    } on DBusCallException catch (e) {
      print(e);
    }

  } finally {
    await client.close();
  }
}

class Hostname1 with DProperties {

  @override
  final DService service;

  Hostname1(DBusClient client):
        service = DService(client, 'org.freedesktop.hostname1', '/org/freedesktop/hostname1', 'org.freedesktop.hostname1');
}
