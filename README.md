_ddbus_ is a [D-Bus](https://dbus.freedesktop.org/doc/dbus-specification.html) client library for Dart.

#### Status
This is the first version, and the implementation hasn't been tested extensively or systematically.

#### Usage
See the `example` directory for examples on how to use `DBusClient`.

#### Limitations
- Only supports the external authentication mechanism.
- Unix domain sockets is the only supported transport.
- Uses Dart's built-in Unix domain sockets so Dart version 2.8.0 or newer is required.
