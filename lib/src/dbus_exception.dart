import 'message.dart';

class DBusException implements Exception {

  final String message;

  const DBusException(this.message);

  @override
  String toString() {
    if (message == null) return 'DBusException';
    return 'DBusException: $message';
  }
}

class DBusCallException extends DBusException {

  final String errorName;
  final Header call;
  final Message reply;

  DBusCallException(this.call, this.reply, [String message]):
        errorName = reply?.header?.errorName,
        super(message ?? (reply.body is String ? reply.body : null));

  @override
  String toString() {
    if (message == null) return 'DBusCallException';
    return 'DBusCallException(name=$errorName, message=$message)';
  }
}
