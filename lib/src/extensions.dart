
extension ExtraInt on int {

  int toNextMultiple(int n) {
    final rem = this % n;
    return rem > 0 ? n - rem : 0;
  }
}

extension ExtraString on String {

  /// Finds the closing bracket for its opening counterpart specified by index [opening].
  /// Returns [opening] if it doesn't point to a opening bracket.
  int findClosingBracket(int opening, {String open = '(', String close = ')'}) {
    var depth = 0;
    final openCode = open.codeUnitAt(0);
    final closeCode = close.codeUnitAt(0);

    for (var i = opening; i < codeUnits.length; i++) {

      if (codeUnits[i] == openCode) {
        depth++;
      } else if (codeUnits[i] == closeCode) {
        depth--;
      }

      if (depth == 0) {
        return i;
      }
    }

    return -1;
  }

  String lastPart({Pattern separator = '.'}) {
    final lastSeparator = lastIndexOf(separator);
    return lastSeparator == -1 ? this : substring(lastSeparator + 1);
  }

  bool hasNamespace(String namespace) {
    if (this == namespace) return true;
    if (!namespace.endsWith('.')) namespace += '.';
    return startsWith(namespace);
  }

  bool isPathMatch(String other) {
    String a, b;

    if (length < other.length) {
      a = this;
      b = other;
    } else {
      a = other;
      b = this;
    }

    return a.endsWith('/') && b.startsWith(a);
  }
}

extension ExtraMap<K, V> on Map<K, V> {

  Map<K, V> withoutNullValues() {
    removeWhere((key, value) => value == null);
    return this;
  }
}

extension ExtraIterable<T> on Iterable<T> {
  T get firstOrNull => isEmpty ? null : first;
}

bool valueNotNull<T>(T value) => value != null;
