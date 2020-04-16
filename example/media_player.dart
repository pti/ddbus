import 'package:ddbus/ddbus.dart';
import 'package:ddbus/src/extensions.dart';
import 'package:rxdart/rxdart.dart';

void main() async {
  final client = await DBusClient.session();

  try {
    final playerName = 'org.mpris.MediaPlayer2.spotify';
    //final playerName = (await client.findPlayerDestinations()).firstOrNull;

    if (playerName == null) {
      print('No player instance found');
      return;
    }

    final destination = await client.getNameOwner(playerName);
    print('Using destination "$destination" ($playerName)');
    final player = MediaPlayer(client, destination);

    print(await player.getAllProperties());

    print('Current status is ${await player.getStatus()}');

    final subscription1 = player.playbackStatus
        .where((status) => status == 'Playing')
        .debounceTime(Duration(seconds: 2))
        .asyncMap((event) => player.pause())
        .listen((status) => print('Auto paused'));

    final subscription2 = player.propertiesChanged(limitSender: true)
        .distinct()
        .listen((event) => print('Changed properties: ${event.changed}'));

    await Future.delayed(Duration(seconds: 10));
    await subscription1.cancel();
    await subscription2.cancel();

  } finally {
    await client.close();
  }
}

class MediaPlayer with DProperties {

  static const propertyPlaybackStatus = 'PlaybackStatus';
  static const propertyVolume = 'Volume';

  @override
  final DService service;

  MediaPlayer(DBusClient client, String destination):
        service = DService(client, destination,
            '/org/mpris/MediaPlayer2', 'org.mpris.MediaPlayer2.Player');

  Future<String> getStatus() => getProperty<String>(propertyPlaybackStatus);

  Future<double> getVolume() => getProperty<double>(propertyVolume);
  Future<void> setVolume(double volume) => setProperty(propertyVolume, DDouble(volume));

  Future<void> playPause() => service.callMethod('PlayPause');
  Future<void> play() => service.callMethod('Play');
  Future<void> pause() => service.callMethod('Pause');

  Stream<String> get playbackStatus => propertiesChanged(limitSender: true)
      // Multiple players can exist so limit signals to the chosen one.
      .map((signal) => signal.changed[propertyPlaybackStatus] as String)
      .where(valueNotNull)
      .distinct();
      // Spotify at least seems to send the same signal (different serial though) multiple times so skip duplicates.
}

extension on DBusClient {

  Future<Iterable<String>> findPlayerDestinations() async {
    return (await listNames())
        .where((name) => name.startsWith('org.mpris.MediaPlayer2'));
  }
}
