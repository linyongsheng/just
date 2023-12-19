import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:just/just.dart';

/// 基于开源项目 https://pub.dev/packages/event_bus 封装，调整如下：
/// 1：全局统一调用入口
/// 2：封装事件订阅器，简化监听接口及支持批量取消

final eventBusInternal = EventBusInternal();

class EventBus {
  EventBus._();

  /// 获取新的事件监听器
  static EventSubscriber subscriber() => _EventSubscriberImpl(eventBusInternal);

  /// 发送事件
  static void fire(event) {
    eventBusInternal.fire(event);
  }
}

/// 事件订阅器，用于事件监听及统一取消监听
abstract class EventSubscriber {
  /// 定义指定类型T的事件
  /// [eventHandler] 事件监听处理器
  void on<T>(void Function(T event)? eventHandler);

  /// 取消所有事件监听
  void cancel();
}

class _EventSubscriberImpl extends EventSubscriber {
  final _subscriptions = <StreamSubscription>[];
  final EventBusInternal _bus;

  _EventSubscriberImpl(this._bus);

  @override
  void on<T>(void Function(T event)? listener) {
    final subscription = _bus.on<T>().listen(listener);
    _subscriptions.add(subscription);
  }

  @override
  void cancel() {
    for (StreamSubscription subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}

/// Dispatches events to listeners using the Dart [Stream] API. The [EventBusInternal]
/// enables decoupled applications. It allows objects to interact without
/// requiring to explicitly define listeners and keeping track of them.
///
/// Not all events should be broadcasted through the [EventBusInternal] but only those of
/// general interest.
///
/// Events are normal Dart objects. By specifying a class, listeners can
/// filter events.
///
class EventBusInternal {
  StreamController _streamController;

  /// Controller for the event bus stream.
  StreamController get streamController => _streamController;

  /// Creates an [EventBusInternal].
  ///
  /// If [sync] is true, events are passed directly to the stream's listeners
  /// during a [fire] call. If false (the default), the event will be passed to
  /// the listeners at a later time, after the code creating the event has
  /// completed.
  EventBusInternal({bool sync = false}) : _streamController = StreamController.broadcast(sync: sync);

  /// Instead of using the default [StreamController] you can use this constructor
  /// to pass your own controller.
  ///
  /// An example would be to use an RxDart Subject as the controller.
  EventBusInternal.customController(StreamController controller) : _streamController = controller;

  /// Listens for events of Type [T] and its subtypes.
  ///
  /// The method is called like this: myEventBus.on<MyType>();
  ///
  /// If the method is called without a type parameter, the [Stream] contains every
  /// event of this [EventBusInternal].
  ///
  /// The returned [Stream] is a broadcast stream so multiple subscriptions are
  /// allowed.
  ///
  /// Each listener is handled independently, and if they pause, only the pausing
  /// listener is affected. A paused listener will buffer events internally until
  /// unpaused or canceled. So it's usually better to just cancel and later
  /// subscribe again (avoids memory leak).
  ///
  Stream<T> on<T>() {
    if (T == dynamic) {
      return streamController.stream as Stream<T>;
    } else {
      return streamController.stream.where((event) => event is T).cast<T>();
    }
  }

  /// Fires a new event on the event bus with the specified [event].
  ///
  void fire(event) {
    streamController.add(event);
  }

  /// Destroy this [EventBusInternal]. This is generally only in a testing context.
  ///
  void destroy() {
    _streamController.close();
  }
}

mixin AutoEventSubscriber<T extends StatefulWidget> on State<T> {
  final _subscriber = EventBus.subscriber();

  void subscribe<E>(void Function(E event)? eventHandler) {
    _subscriber.on(eventHandler);
  }

  @override
  void dispose() {
    _subscriber.cancel();
    super.dispose();
  }
}

