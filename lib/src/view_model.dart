import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'data_binding.dart';
import 'dispose.dart';

class ViewModel with ObservableHolder, DisposableHolder {
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
