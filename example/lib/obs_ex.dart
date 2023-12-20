import 'package:just/just.dart';

const String _obsKey = "just.key.obs";

/// this is example show how to extent ViewModel by tag
extension ObsEx on DisposableHolder {
  ObsGroup get obsGroup {
    _DisposableObsSubscriber? subscriber = getTag(_obsKey);
    if (subscriber != null) {
      return subscriber.subscriber;
    }
    return setTagIfAbsent(_obsKey, _DisposableObsSubscriber(ObsGroup())).subscriber;
  }
}

class _DisposableObsSubscriber implements Disposable {
  final ObsGroup subscriber;

  _DisposableObsSubscriber(this.subscriber);

  @override
  void dispose() {
    subscriber.cancel();
  }
}
