import 'package:flutter/material.dart';

typedef WidgetCallback = Widget Function();

typedef ShouldRebuild = bool Function();

typedef Observer<T> = void Function(T value);

/// 一种可观察的（observable）状态封装
class Obs<T> {
  late T _value;
  final _observers = <Observer<T>>{};

  Obs(T initValue) : _value = initValue;

  T get value {
    final scope = _DataBindingState.scope;
    if (scope != null) {
      scope.addObservable(this);
    }
    return _value;
  }

  int get observerCount => _observers.length;

  @protected
  void setValue(T newValue, bool force) {
    final accept = force ? true : _acceptValue(newValue);
    if (!accept) {
      return;
    }
    _value = newValue;
    final length = _observers.length;
    if (length == 0) {
      return;
    }
    Future.delayed(Duration.zero, () {
      if (_observers.length == 1) {
        _observers.first.call(_value);
        return;
      }
      // 浅拷贝副本，避免遍历过程中_observers增减
      final observers = _observers.toList();
      for (var observer in observers) {
        observer.call(_value);
      }
    });
  }

  /// 是否接受新值，目前规则如下：
  /// 1：新旧值都为null,不更新
  /// 2：否则，其中一个为null,会更新
  /// 3：否则，为基本数据类型（String/bool/num），且相等，不更新
  /// 4：其他情况一律更新
  bool _acceptValue(T newValue) {
    if (_value == null && newValue == null) {
      return false;
    }
    if (_value == null || newValue == null) {
      return true;
    }
    if ((_value is String || _value is bool || _value is num) && (_value == newValue)) {
      return false;
    }
    return true;
  }

  /// 添加观察者
  Subscription<T> subscribe(Observer<T> observer) {
    final res = _observers.add(observer);
    if (res && observerCount == 1) {
      onActive();
    }
    return _Subscription<T>(this, observer);
  }

  /// 添加观察者，并且会立马回调当前值
  Subscription<T> subscribeSticky(Observer<T> observer) {
    final sub = subscribe(observer);
    Future.delayed(Duration.zero, () {
      observer.call(_value);
    });
    return sub;
  }

  /// 添加观察者
  bool _subscribe(Observer<T> observer) {
    final res = _observers.add(observer);
    if (res && observerCount == 1) {
      onActive();
    }
    return res;
  }

  /// 移除观察者
  void _unsubscribe(Observer<T> observer) {
    final res = _observers.remove(observer);
    if (res && observerCount == 0) {
      onInactive();
    }
  }

  /// 观察者个数从0到1
  @protected
  void onActive() {}

  /// 观察者个数从1到0
  @protected
  void onInactive() {}
}

/// 状态持有者
/// 状态本身不对外支持修改，只能通过持有者设置
mixin ObservableHolder {
  @protected
  void setValue<T>(Obs<T> obs, T value, {bool force = false}) {
    obs.setValue(value, force);
  }
}

/// 订阅返回
abstract class Subscription<T> {
  /// 取消订阅
  void cancel();
}

class _Subscription<T> extends Subscription<T> {
  WeakReference<Obs<T>>? _observable;
  WeakReference<Observer<T>>? _observer;

  _Subscription(Obs<T> observable, Observer<T> observer)
      : _observable = WeakReference(observable),
        _observer = WeakReference(observer);

  /// 取消订阅
  void cancel() {
    final observable = _observable?.target;
    final observer = _observer?.target;
    if (observable != null && observer != null) {
      observable._unsubscribe(observer);
    }
    _observable = null;
    _observer = null;
  }
}

/// 数据绑定 Widget
/// callback中的调用到的 xx.value 将被自动订阅
/// 对应的状态 xx 发生变化时，将触发 callback 再次调用
class DataBinding extends StatefulWidget {
  final WidgetCallback callback;
  final ShouldRebuild? shouldRebuild;

  const DataBinding(this.callback, {super.key, this.shouldRebuild});

  @override
  State<DataBinding> createState() => _DataBindingState();
}

class _DataBindingState extends State<DataBinding> {
  final _observable = _MultiObservable();
  static _MultiObservable? scope;

  @override
  void initState() {
    super.initState();
    _observable.subscribe((value) {
      if (mounted) {
        final shouldRebuild = widget.shouldRebuild?.call() ?? true;
        if (shouldRebuild) {
          setState(() {});
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final preScope = scope;
    scope = _observable;
    // TODO 如果重复订阅相同状态，没有必要先取消 待优化
    _observable.cancel(false);
    try {
      return widget.callback();
    } finally {
      scope = preScope;
    }
  }

  @override
  void dispose() {
    _observable.cancel(true);
    super.dispose();
  }
}

/// 实现同一个Observer订阅多个Observable
/// 任一个Observable的数据发生变化，都会触发Observer回调
/// 且支持统一取消订阅
class _MultiObservable {
  final _subscriptions = <Subscription>[];
  Observer? _observer;

  void subscribe(Observer observer) {
    _observer = observer;
  }

  void addObservable(Obs obs) {
    final observer = _observer;
    if (observer == null) {
      return;
    }
    final res = obs._subscribe(observer);
    if (res) {
      _subscriptions.add(_Subscription(obs, observer));
    }
  }

  void cancel(bool dispose) {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    if (dispose) {
      _observer = null;
    }
  }
}

/// ObsGroup通过其[subscribe]方法，收集[Subscription],可实现批量取消
class ObsGroup {
  final _subscriptions = <Subscription>[];

  /// 定义指定类型T的事件
  Subscription<T> subscribe<T>(Obs<T> obs, Observer<T> observer) {
    final sub = obs.subscribe(observer);
    _subscriptions.add(sub);
    return sub;
  }

  /// 定义指定类型T的事件
  Subscription<T> subscribeSticky<T>(Obs<T> obs, Observer<T> observer) {
    final sub = obs.subscribeSticky(observer);
    _subscriptions.add(sub);
    return sub;
  }

  /// 取消所有事件监听
  void cancel() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}

/// 扩展任何数据类型 后缀快捷写法 .obs。转换为Obs<T>类型
extension ObsExtensions<T> on T {
  Obs<T> get obs => Obs<T>(this);
}

abstract class DataBindingWidget extends StatelessWidget {
  const DataBindingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return DataBinding(
      () => buildWithData(context),
      shouldRebuild: () {
        return shouldRebuild(context);
      },
    );
  }

  @protected
  Widget buildWithData(BuildContext context);

  @protected
  bool shouldRebuild(BuildContext context) {
    return true;
  }
}

abstract class DataBindingState<T extends StatefulWidget> extends State<T> {
  @override
  Widget build(BuildContext context) {
    return DataBinding(
      () => buildWithData(context),
      shouldRebuild: () {
        return shouldRebuild(context);
      },
    );
  }

  @protected
  Widget buildWithData(BuildContext context);

  @protected
  bool shouldRebuild(BuildContext context) {
    return true;
  }
}
