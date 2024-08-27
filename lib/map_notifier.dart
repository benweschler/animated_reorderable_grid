import 'package:flutter/foundation.dart';
import 'dart:collection';

class MapNotifier<K, V extends Object?> extends ChangeNotifier with MapMixin {
  final Map<K, V> _map;

  MapNotifier(this._map);

  @override
  V? operator [](Object? key) => _map[key];

  @override
  void operator []=(key, value) {
    if (_map[key] == value) return;
    _map[key] = value;
    notifyListeners();
  }

  @override
  void clear() {
    _map.clear();
    notifyListeners();
  }

  @override
  Iterable get keys => _map.keys;

  @override
  V? remove(Object? key) {
    if (!_map.containsKey(key)) return null;
    notifyListeners();
    return _map.remove(key);
  }
}
