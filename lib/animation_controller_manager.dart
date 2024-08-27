import 'package:flutter/animation.dart';

/// Manages the lifecycle of a list of [AnimationController]s.
///
/// Each controller is accessible using a key of type [T]. All keys must be of
/// the same type.
/// Useful for managing a dynamic number of [AnimationControllers] to prevent
/// dangling references and to ensure that a controller is properly disposed if a key is overwritten with a new controller..
class AnimationControllerManager<T> {
  final Map<T, AnimationController> _controllerMap;

  AnimationControllerManager() : _controllerMap = {};

  void clear() {
    for(AnimationController controller in _controllerMap.values) {
      controller.dispose();
    }
    _controllerMap.clear();
  }

  AnimationController? get(Object? key) => _controllerMap[key];

  void set(T key, AnimationController value) {
    if(_controllerMap[key] == value) return;
    _controllerMap[key]?.dispose();
    _controllerMap[key] = value;
  }

  AnimationController? remove(Object? key) {
    _controllerMap[key]?.dispose();
    return _controllerMap.remove(key);
  }

  bool containsKey(T key) => _controllerMap.containsKey(key);
}
