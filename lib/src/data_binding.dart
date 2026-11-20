import 'package:flutter/material.dart';

typedef WidgetCallback = Widget Function();

typedef ShouldRebuild = bool Function();

typedef Observer<T> = void Function(T value);

/// 一种可观察的（observable）状态封装
class Obs<T> {
  late T _value;
  final _observers = <Observer<T>>{};
  Map<_Subscription<T>, Observer<T>>? _syncObservers;
  int _syncRevision = 0;
  bool _changingActivity = false;

  Obs(T initValue) : _value = initValue;

  T get value {
    final scope = _DataBindingState.scope;
    if (scope != null) {
      scope.addObservable(this);
    }
    return _value;
  }

  int get observerCount => _observers.length + (_syncObservers?.length ?? 0);

  @protected
  void setValue(T newValue, bool force) {
    final accept = force ? true : _acceptValue(newValue);
    if (!accept) {
      return;
    }
    _value = newValue;
    if (_observers.isNotEmpty) {
      Future.delayed(Duration.zero, _notifyObservers);
    }
    final syncObservers = _syncObservers;
    if (syncObservers != null) {
      _notifySync(syncObservers, newValue);
    }
  }

  void _notifyObservers() {
    if (_observers.length == 1) {
      _observers.first(_value);
      return;
    }
    for (final observer in _observers.toList()) {
      observer(_value);
    }
  }

  void _notifySync(Map<_Subscription<T>, Observer<T>> observers, T value) {
    final revision = ++_syncRevision;
    // 回调间接读取的状态不属于触发此次写入的 DataBinding。
    final scope = _DataBindingState.scope;
    _DataBindingState.scope = null;
    try {
      for (final subscription in observers.keys.toList()) {
        // 重入写入已经派发了新值，停止投递本轮旧值。
        if (revision != _syncRevision) break;
        try {
          observers[subscription]?.call(value);
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'just',
            context:
                ErrorDescription('while notifying a synchronous Obs listener'),
          ));
        }
      }
    } finally {
      _DataBindingState.scope = scope;
    }
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
    if ((_value is String || _value is bool || _value is num) &&
        (_value == newValue)) {
      return false;
    }
    return true;
  }

  /// 添加观察者
  Subscription<T> subscribe(Observer<T> observer) {
    return _subscribeDeferred(observer) ??
        _Subscription(this, deferred: observer);
  }

  /// 同步监听后续写入。首次订阅触发的 [onActive] 可能在本方法返回前写入。
  /// 每次调用都创建可独立取消的订阅。
  Subscription<T> subscribeSync(Observer<T> observer) {
    final subscription = _Subscription(this);
    final observers = _syncObservers ??= {};
    observers[subscription] = observer;
    return _activate(subscription);
  }

  /// 添加观察者，并在后续事件循环回调当前值。
  Subscription<T> subscribeSticky(Observer<T> observer) {
    final sub = subscribe(observer);
    Future.delayed(Duration.zero, () {
      observer.call(_value);
    });
    return sub;
  }

  /// 添加观察者
  _Subscription<T>? _subscribeDeferred(Observer<T> observer) {
    if (!_observers.add(observer)) return null;
    return _activate(_Subscription(this, deferred: observer));
  }

  _Subscription<T> _activate(_Subscription<T> subscription) {
    if (observerCount == 1) {
      try {
        _notifyActivityChange();
      } catch (_) {
        subscription.cancel();
        rethrow;
      }
    }
    return subscription;
  }

  void _notifyActivityChange() {
    if (_changingActivity) return;
    final active = observerCount > 0;
    _changingActivity = true;
    try {
      if (active) {
        onActive();
      } else {
        onInactive();
      }
    } finally {
      _changingActivity = false;
      // 先完成当前启停，再处理钩子执行期间发生的订阅变化。
      if (active != (observerCount > 0)) _notifyActivityChange();
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
  final WeakReference<Observer<T>>? _deferredObserver;

  _Subscription(Obs<T> observable, {Observer<T>? deferred})
      : _observable = WeakReference(observable),
        _deferredObserver = deferred == null ? null : WeakReference(deferred);

  /// 取消订阅
  @override
  void cancel() {
    final observable = _observable?.target;
    _observable = null;
    if (observable == null) return;
    final deferred = _deferredObserver;
    if (deferred == null) {
      final observers = observable._syncObservers!;
      observers.remove(this);
      if (observers.isEmpty) observable._syncObservers = null;
    } else if (!observable._observers.remove(deferred.target)) {
      return;
    }
    if (observable.observerCount == 0) observable._notifyActivityChange();
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
    final sub = obs._subscribeDeferred(observer);
    if (sub != null) _subscriptions.add(sub);
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
  final _subscriptions = <Subscription>{};
  var _batch = _GroupBatch();

  /// 定义指定类型T的事件
  Subscription<T> subscribe<T>(Obs<T> obs, Observer<T> observer) {
    final batch = _batch;
    return _add(batch, obs.subscribe(observer));
  }

  /// 同步监听 [obs] 的后续写入，通过 [cancel] 可统一取消。
  Subscription<T> subscribeSync<T>(Obs<T> obs, Observer<T> observer) {
    final batch = _batch;
    return _add(batch, obs.subscribeSync((value) {
      if (!batch.cancelled) observer(value);
    }));
  }

  /// 定义指定类型T的事件
  Subscription<T> subscribeSticky<T>(Obs<T> obs, Observer<T> observer) {
    final batch = _batch;
    return _add(batch, obs.subscribeSticky(observer));
  }

  Subscription<T> _add<T>(_GroupBatch batch, Subscription<T> sub) {
    // onActive 可能在订阅方法返回句柄之前取消本组。
    if (batch.cancelled) {
      sub.cancel();
    } else {
      _subscriptions.add(sub);
    }
    return sub;
  }

  /// 取消所有事件监听
  void cancel() {
    _batch.cancelled = true;
    _batch = _GroupBatch();
    for (final sub in _subscriptions.toList()) {
      if (_subscriptions.remove(sub)) sub.cancel();
    }
  }
}

class _GroupBatch {
  bool cancelled = false;
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
