import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'data_binding.dart';

abstract class Disposable {
  void dispose();
}

class ViewModel with ObservableHolder implements Disposable {
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

class ViewModelProvider<T extends ViewModel> extends Provider<T> {
  ViewModelProvider({
    Key? key,
    required Create<T> create,
    Widget? child,
  }) : super(key: key, create: create, dispose: (_, value) => value.dispose(), child: child);

  ViewModelProvider.value({
    Key? key,
    required T value,
    Widget? child,
  }) : super.value(key: key, value: value, child: child);
}

extension ViewModelContext on BuildContext {
  T viewModel<T extends ViewModel>() {
    return Provider.of<T>(this, listen: false);
  }
}

class ViewModels {
  static T of<T extends ViewModel>(BuildContext context) {
    return Provider.of<T>(context, listen: false);
  }
}
