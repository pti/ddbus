import 'package:ddbus/ddbus.dart';

import 'extensions.dart';
import 'message.dart';

class MatchRule {

  final MessageType type;
  final String sender;
  final String interface;
  final String member;
  final String path;
  final String pathNamespace;
  final String destination;
  final String arg0namespace;
  final List<String> arg;
  final List<String> argPath;

  MatchRule({this.type, this.sender, this.interface, this.member, this.path, this.pathNamespace,
    this.destination, this.arg, this.argPath, this.arg0namespace});

  bool isMatch(Message message) {
    final header = message.header;

    return (type == null || type == header.type)
        && (sender == null || header.sender == sender)
        && (interface == null || header.interface == interface)
        && (member == null || header.member == member)
        && (path == null || header.path == path)
        && (destination == null || header.destination == destination)
        && (arg == null || _checkArgs(message.body, arg))
        && (argPath == null || _checkArgs(message.body, argPath, pathMatch: true))
        && (arg0namespace == null || message.arg(0)?.hasNamespace(arg0namespace) == true);
  }

  String toRuleString() {

    final pairs = <String, String>{
      'type': type?.name,
      'sender': sender,
      'interface': interface,
      'member': member,
      'path': path,
      'pathNamespace': pathNamespace,
      'destination': destination,
      'arg0namespace': arg0namespace
    }.withoutNullValues();

    void populateIndexed(List<String> values, String Function(int index) keyFormatter) {
      values.asMap().entries
          .where((e) => e.value != null)
          .forEach((e) => pairs[keyFormatter(e.key)] = e.value);
    }

    if (arg != null) populateIndexed(arg, (i) => 'arg$i');
    if (argPath != null) populateIndexed(argPath, (i) => 'arg${i}path');

    return pairs.entries
        .map((e) => "${e.key}='${e.value}'")
        .join(',');
  }

  bool _checkArgs(dynamic body, List<String> matches, {bool pathMatch = false}) {
    if (body is! List<String>) return false;
    final args = body as List<String>;
    if (args.length < matches.length) return false;

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      if (match == null) continue;
      if (!(match == args[i] || (pathMatch && match.isPathMatch(args[i])))) return false;
    }

    return true;
  }
}

extension on Message {

  String arg(int index) {
    if (body is! List<String>) return null;
    final args = body as List<String>;
    return index < args.length ? args[index] : null;
  }
}
