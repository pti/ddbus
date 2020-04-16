import 'message.dart';

/// Defines well-known core errors that might appear in the value of [Header.errorName].
/// https://freedesktop.org/wiki/Software/DBusBindingErrors/
class ErrorName {

  static const failed = 'org.freedesktop.DBus.Error.Failed';
  static const noMemory = 'org.freedesktop.DBus.Error.NoMemory';
  static const serviceUnknown = 'org.freedesktop.DBus.Error.ServiceUnknown';
  static const nameHasNoOwner = 'org.freedesktop.DBus.Error.NameHasNoOwner';
  static const noReply = 'org.freedesktop.DBus.Error.NoReply';
  static const ioError = 'org.freedesktop.DBus.Error.IOError';
  static const badAddress = 'org.freedesktop.DBus.Error.BadAddress';
  static const notSupported = 'org.freedesktop.DBus.Error.NotSupported';
  static const limitsExceeded = 'org.freedesktop.DBus.Error.LimitsExceeded';
  static const accessDenied = 'org.freedesktop.DBus.Error.AccessDenied';
  static const authFailed = 'org.freedesktop.DBus.Error.AuthFailed';
  static const noServer = 'org.freedesktop.DBus.Error.NoServer';
  static const timeout = 'org.freedesktop.DBus.Error.Timeout';
  static const noNetwork = 'org.freedesktop.DBus.Error.NoNetwork';
  static const addressInUse = 'org.freedesktop.DBus.Error.AddressInUse';
  static const disconnected = 'org.freedesktop.DBus.Error.Disconnected';
  static const invalidArgs = 'org.freedesktop.DBus.Error.InvalidArgs';
  static const fileNotFound = 'org.freedesktop.DBus.Error.FileNotFound';
  static const unknownMethod = 'org.freedesktop.DBus.Error.UnknownMethod';
  static const timedOut = 'org.freedesktop.DBus.Error.TimedOut';
  static const matchRuleNotFound = 'org.freedesktop.DBus.Error.MatchRuleNotFound';
  static const matchRuleInvalid = 'org.freedesktop.DBus.Error.MatchRuleInvalid';
  static const spawnExecFailed = 'org.freedesktop.DBus.Error.Spawn.ExecFailed';
  static const spawnForkFailed = 'org.freedesktop.DBus.Error.Spawn.ForkFailed';
  static const spawnChildExited = 'org.freedesktop.DBus.Error.Spawn.ChildExited';
  static const spawnChildSignaled = 'org.freedesktop.DBus.Error.Spawn.ChildSignaled';
  static const spawnFailed = 'org.freedesktop.DBus.Error.Spawn.Failed';
  static const unixProcessIdUnknown = 'org.freedesktop.DBus.Error.UnixProcessIdUnknown';
  static const invalidSignature = 'org.freedesktop.DBus.Error.InvalidSignature';
  static const seLinuxSecurityContextUnknown = 'org.freedesktop.DBus.Error.SELinuxSecurityContextUnknown';

  ErrorName._internal();
}
