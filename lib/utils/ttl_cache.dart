/// Simple in-memory cache where each entry expires after [ttl].
class TtlCache<T> {
  final Duration ttl;
  final Map<String, _TtlEntry<T>> _entries = {};

  TtlCache(this.ttl);

  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  void set(String key, T value) {
    _entries[key] = _TtlEntry(value, DateTime.now().add(ttl));
  }
}

class _TtlEntry<T> {
  final T value;
  final DateTime expiresAt;
  _TtlEntry(this.value, this.expiresAt);
}
