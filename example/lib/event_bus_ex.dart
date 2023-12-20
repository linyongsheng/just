
import 'package:just/just.dart';

import 'event_bus.dart';

const String _eventBusKey = "just.viewModel.key.eventbus";

/// this is example show how to extent ViewModel by tag
extension EventbusEx on DisposableHolder {
  EventSubscriber get eventbus {
    _DisposableEventSubscriber? subscriber = getTag(_eventBusKey);
    if (subscriber != null) {
      return subscriber.subscriber;
    }
    return setTagIfAbsent(_eventBusKey, _DisposableEventSubscriber(EventBus.subscriber())).subscriber;
  }
}

class _DisposableEventSubscriber implements Disposable {
  final EventSubscriber subscriber;

  _DisposableEventSubscriber(this.subscriber);

  @override
  void dispose() {
    subscriber.cancel();
  }
}