import 'dart:math';

import 'dbus_client.dart';
import 'dbus_types.dart';
import 'match_rule.dart';

extension DBusMethods on DBusClient {

  Future<String> hello() async {
    return await _callSpecialMethod<String>(member: 'Hello');
  }

  Future<RequestNameReply> requestName(String name, {Set<RequestNameFlag> flags = const {}}) async {
    final flagMask = flags?.map((f) => pow(2, f.index).toInt())?.fold(0, (int a, b) => a | b) ?? 0;

    final reply = await _callSpecialMethod<int>(
        member: 'RequestName',
        body: [DString(name), DUint32(flagMask)]);
    return RequestNameReply.values[reply - 1];
  }

  Future<ReleaseNameReply> releaseName(String name) async {
    final reply = await _callSpecialMethod<int>(
        member: 'ReleaseName',
        body: DString(name));
    return ReleaseNameReply.values[reply - 1];
  }

  Future<List<String>> listQueuedOwners(String busName) async {
    return await _callSpecialMethod<List<String>>(
        member: 'ListQueuedOwners',
        body: DString(busName));
  }

  Future<List<String>> listNames() async {
    return await _callSpecialMethod<List<String>>(member: 'ListNames');
  }

  Future<List<String>> listActivatableNames() async {
    return await _callSpecialMethod<List<String>>(member: 'ListActivatableNames');
  }

  Future<bool> nameHasOwner(String name) async {
    return await _callSpecialMethod<bool>(
        member: 'NameHasOwner',
        body: DString(name));
  }

  Future<StartServiceReply> startServiceByName(String name, {int flags}) async {
    final reply = await _callSpecialMethod<int>(
        member: 'StartServiceByName',
        body: [DString(name), DUint32(flags)]);
    return StartServiceReply.values[reply - 1];
  }

  Future<void> updateActivationEnvironment(Map<String, String> variables) async {
    final arg = DArray(variables.entries.map((e) => DDictEntry(DString(e.key), DString(e.value))).toList());

    final reply = await _callSpecialMethod<int>(
        member: 'UpdateActivationEnvironment',
        body: arg);
    return StartServiceReply.values[reply - 1];
  }

  Future<String> getNameOwner(String name) async {
    return await _callSpecialMethod<String>(
        member: 'GetNameOwner',
        body: DString(name));
  }

  Future<int> getConnectionUnixUser(String busName) async {
    return await _callSpecialMethod<int>(
        member: 'GetConnectionUnixUser',
        body: DString(busName));
  }

  Future<int> getConnectionUnixProcessID(String busName) async {
    return await _callSpecialMethod<int>(
        member: 'GetConnectionUnixProcessID',
        body: DString(busName));
  }

  Future<Map<String, dynamic>> getConnectionCredentials(String busName) async {
    final result = await _callSpecialMethod<Map>(
        member: 'GetConnectionCredentials',
        body: DString(busName));
    return result.map((key, value) => MapEntry(key as String, value));
  }

  /// See [MatchRule.createRule] for creating a match rule string.
  Future<void> addMatch(String rule) async {
    await _callSpecialMethod(
        member: 'AddMatch',
        body: DString(rule));
  }

  Future<void> removeMatch(String rule) async {
    await _callSpecialMethod(
        member: 'RemoveMatch',
        body: DString(rule));
  }

  Future<String> getId() async {
    return await _callSpecialMethod<String>(member: 'GetId');
  }

  Future<void> becomeMonitor(List<String> rules) async {
    await _callSpecialMethod(
        member: 'BecomeMonitor',
        body: [DArray(rules.map((r) => DString(r)).toList()), DUint32(0)]);
  }

  Future<T> _callSpecialMethod<T>({String member, dynamic body}) {
    return callMethod<T>(
        destination: 'org.freedesktop.DBus',
        path: '/org/freedesktop/DBus',
        interface: 'org.freedesktop.DBus',
        member: member,
        body: body
    );
  }

  Future<void> peerPing(String destination, String path) async {
    await callMethod(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Peer',
        member: 'Ping');
  }

  Future<String> peerGetMachineId(String destination, String path) async {
    return await callMethod<String>(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Peer',
        member: 'GetMachineId');
  }

  Future<String> introspect(String destination, String path) async {
    return await callMethod<String>(
        destination: destination,
        path: path,
        interface: 'org.freedesktop.DBus.Introspectable',
        member: 'Introspect');
  }
}

enum RequestNameFlag {
  allowReplacement,
  replaceExisting,
  doNotQueue
}

enum RequestNameReply {
  primaryOwner,
  inQueue,
  exists,
  alreadyOwner
}

enum ReleaseNameReply {
  released,
  nonExistent,
  notOwner
}

enum StartServiceReply {
  success,
  alreadyRunning
}
