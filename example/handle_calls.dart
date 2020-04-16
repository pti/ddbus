import 'dart:io';

import 'package:ddbus/ddbus.dart';
import 'package:rxdart/rxdart.dart';

/// Example commands to test handling method calls:
/// ```
/// gdbus call --session --dest com.example.DartDBus --object-path /foo/bar --method com.example.DartDBus.Echo 'message to echo'
/// ```
void main() async {

  DBusClient.logger = (LogLevel level, LogType type, String text, Message message, dynamic error, StackTrace stack) {
    print ('${type?.name}: ${text ?? ''} ${message?.header} ${message?.body} $error $stack');
  };

  final client = await DBusClient.session();
  final interface = 'com.example.DartDBus';
  final reply = await client.requestName(interface);

  if (reply == RequestNameReply.alreadyOwner || reply == RequestNameReply.primaryOwner) {

    final subscription = client.methodCallStream(path: RegExp(r'^/foo/.+'), interface: interface, member: 'Echo')
        .listen((call) => client.sendReply(call, body: DString(call.body?.toString() ?? '')));
    // DBusClient will handle method calls that do not match any of the registered handlers by replying with an error.

    await MergeStream([ProcessSignal.sigint.watch(), ProcessSignal.sigterm.watch()]).first;
    await subscription.cancel();

  } else {
    print('Name $interface not available');
  }

  await client.close();
}
