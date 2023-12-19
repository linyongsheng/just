import 'package:flutter/widgets.dart';

abstract class Disposable {
  void dispose();
}

mixin DisposableHolder implements Disposable {
  final _bagOfTag = <String, dynamic>{};
  var _disposed = false;

  /// Sets a tag associated with this viewmodel and a key.
  /// If the given [newValue] is [Disposable],
  /// it will be dispose once [dispose].
  ///
  /// If a value was already set for the given key, this calls do nothing and
  /// returns currently associated value, the given [newValue] would be ignored
  ///
  /// If the ViewModel was already disposed then dispose() would be called on the returned object if
  /// it implements [Disposable]. The same object may receive multiple close calls, so method
  /// should be idempotent.
  T setTagIfAbsent<T>(String key, T newValue) {
    final result = _bagOfTag.putIfAbsent(key, () => newValue);
    if (_disposed) {
      if (result is Disposable) {
        result.dispose();
      }
    }
    return result;
  }

  /// Returns the tag associated with this viewmodel and the specified key.
  T? getTag<T>(String key) {
    return _bagOfTag[key] as T?;
  }

  @mustCallSuper
  void dispose() {
    _disposed = true;
    _bagOfTag.forEach((key, value) {
      if (value is Disposable) {
        value.dispose();
      }
    });
    // _bagOfTag.clear();
  }
}
