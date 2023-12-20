
import 'package:just/just.dart';

import 'event_bus.dart';

const String _eventBusKey = "just.viewModel.key.eventbus";

/// this is example show how to extent ViewModel by tag
extension EventbusEx on AbstractDisposableHolder {
  EventSubscriber get eventbus {
    _DisposableEventSubscriber? subscriber = getTag(_eventBusKey);
    if (subscriber != null) {
      return subscriber;
    }
    return setTagIfAbsent(_eventBusKey, _DisposableEventSubscriber(EventBus.subscriber()));
  }
}

class _DisposableEventSubscriber implements Disposable, EventSubscriber {
  final EventSubscriber subscriber;

  _DisposableEventSubscriber(this.subscriber);

  @override
  void dispose() {
    subscriber.cancel();
  }

  @override
  void cancel() {
    subscriber.cancel();
  }

  @override
  void on<T>(void Function(T event)? eventHandler) {
    subscriber.on(eventHandler);
  }
}