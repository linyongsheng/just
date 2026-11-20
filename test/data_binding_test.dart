import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just/just.dart';

class _Source<T> extends Obs<T> {
  _Source(T initial) : super(initial);

  int starts = 0;
  int stops = 0;
  VoidCallback? start;
  VoidCallback? stop;

  void write(T value, {bool force = false}) => setValue(value, force);

  @override
  void onActive() {
    starts++;
    start?.call();
  }

  @override
  void onInactive() {
    stops++;
    stop?.call();
  }
}

class _ForwardingSource extends Obs<int> {
  final Obs<int> upstream;

  _ForwardingSource(this.upstream) : super(0);

  @override
  Subscription<int> subscribeSync(Observer<int> observer) =>
      upstream.subscribeSync(observer);
}

void main() {
  test('group subscriptions follow a source that forwards subscribeSync', () {
    final upstream = _Source(0);
    final source = _ForwardingSource(upstream);
    final values = <int>[];
    final group = ObsGroup();
    group.subscribeSync(source, values.add);
    upstream.write(1);
    expect(values, [1]);
    group.cancel();
    expect(upstream.stops, 1);
  });

  test('cancelling during onActive also releases a pending deferred listener',
      () {
    final group = ObsGroup();
    final source = _Source(0)..start = group.cancel;
    group.subscribe(source, (_) {});
    expect(source.observerCount, 0);
    expect(source.stops, 1);
  });

  test('inline writes and deferred writes can share one observer', () async {
    final source = _Source(0);
    final values = <int>[];
    final observer = values.add;
    final inline = source.subscribeSync(observer);
    final deferred = source.subscribe(observer);
    expect(values, isEmpty);
    source.write(1);
    source.write(2);
    expect(values, [1, 2]);
    await Future<void>.microtask(() {});
    expect(values, [1, 2]);
    await Future<void>.delayed(Duration.zero);
    expect(values, [1, 2, 2, 2]);

    inline.cancel();
    source.write(3);
    expect(values, [1, 2, 2, 2]);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, 3);
    deferred.cancel();
  });

  test('sticky delivers the latest value on a later event-loop turn', () async {
    final source = _Source(0);
    final values = <int>[];
    source.subscribeSticky(values.add);
    source.write(1);
    expect(values, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(values, [1, 1]);
  });

  for (final syncFirst in [true, false]) {
    test('subscriptions share activation and cleanup (sync first: $syncFirst)',
        () {
      final source = _Source(0);
      final group = ObsGroup();
      final first = syncFirst
          ? group.subscribeSync(source, (_) {})
          : group.subscribe(source, (_) {});
      if (syncFirst) {
        group.subscribe(source, (_) {});
      } else {
        group.subscribeSync(source, (_) {});
      }
      expect(source.starts, 1);
      expect(source.observerCount, 2);
      first.cancel();
      first.cancel();
      expect(source.observerCount, 1);
      expect(source.stops, 0);
      group.cancel();
      group.cancel();
      expect(source.observerCount, 0);
      expect(source.stops, 1);
      group.subscribeSync(source, (_) {});
      expect(source.starts, 2);
      group.cancel();
      expect(source.stops, 2);
    });
  }

  test('sync registrations of the same callback have independent lifetimes',
      () {
    final source = _Source(0);
    final values = <int>[];
    final observer = values.add;
    final group = ObsGroup();
    final first = source.subscribeSync(observer);
    group.subscribeSync(source, observer);
    source.write(1);
    first.cancel();
    first.cancel();
    source.write(2);
    group.cancel();
    source.write(3);
    expect(values, [1, 1, 2]);
    expect(source.stops, 1);
  });

  test('the same accepted writes reach sync and deferred subscribers',
      () async {
    final source = _Source<Object?>(null);
    final inline = <Object?>[];
    final deferred = <Object?>[];
    source.subscribeSync(inline.add);
    source.subscribe(deferred.add);
    final object = <int>[];
    final expected = <Object?>[null, 1, true, 'x', object, object, null];
    source.write(null);
    source.write(null, force: true);
    for (final value in [1, true, 'x', object]) {
      source.write(value);
      source.write(value);
    }
    source.write(null);
    expect(inline, expected);
    await Future<void>.delayed(Duration.zero);
    expect(deferred, List<Object?>.filled(expected.length, null));
  });

  test('nested writes supersede old values for remaining sync listeners', () {
    final source = _Source(0);
    final calls = <String>[];
    source.subscribeSync((value) {
      calls.add('a$value');
      if (value == 1) source.write(2);
    });
    source.subscribeSync((value) => calls.add('b$value'));
    source.write(1);
    expect(calls, ['a1', 'a2', 'b2']);
  });

  test('cancelling and re-adding listeners during dispatch', () {
    final source = _Source(0);
    final calls = <String>[];
    void observer(int value) => calls.add('b$value');
    late Subscription<int> second;
    source.subscribeSync((value) {
      if (value == 1) {
        second.cancel();
        source.subscribeSync(observer);
        source.subscribeSync((v) => calls.add('c$v'));
      }
    });
    second = source.subscribeSync(observer);
    source.write(1);
    expect(calls, isEmpty);
    second.cancel();
    source.write(2);
    expect(calls, ['b2', 'c2']);
  });

  test('a group can stop a service during its first synchronous write', () {
    final source = _Source(0);
    final group = ObsGroup();
    late Timer timer;
    source.start = () {
      source.write(1);
      timer =
          Timer.periodic(const Duration(seconds: 1), (_) => source.write(3));
      addTearDown(timer.cancel);
      source.write(2);
    };
    source.stop = () => timer.cancel();
    final values = <int>[];
    group.subscribeSync(source, (value) {
      values.add(value);
      group.cancel();
    });
    expect(values, [1]);
    expect(source.observerCount, 0);
    expect(source.stops, 1);
    expect(timer.isActive, isFalse);
  });

  test('a preview can activate just the field it observes', () {
    _Source<int> bridge(_Source<int> upstream) {
      final field = _Source(0);
      final subscriptions = ObsGroup();
      field.start = () {
        subscriptions.subscribeSync(upstream, field.write);
        field.write(upstream.value);
      };
      field.stop = subscriptions.cancel;
      return field;
    }

    final time = _Source(12);
    final weather = _Source(28);
    final previewTime = bridge(time);
    final previewWeather = bridge(weather);
    final values = <int>[];
    final preview = previewTime.subscribeSync(values.add);
    time.write(13);
    expect(values, [12, 13]);
    expect(time.starts, 1);
    expect(previewWeather.observerCount, 0);
    expect(weather.starts, 0);
    preview.cancel();
    expect(time.stops, 1);
  });

  test('failed activation releases the subscription and can be retried', () {
    final source = _Source(0);
    final group = ObsGroup();
    source.start = () {
      source.write(1);
      throw StateError('start');
    };
    expect(() => group.subscribeSync(source, (_) => group.cancel()),
        throwsStateError);
    expect(source.observerCount, 0);
    expect(source.stops, 1);
    source.start = null;
    group.subscribeSync(source, (_) {});
    expect(source.starts, 2);
    group.cancel();
    expect(source.stops, 2);
  });

  test('a group can restart the same service from onInactive', () {
    final source = _Source(0);
    final group = ObsGroup();
    final events = <String>[];
    source.start = () => events.add('start');
    group.subscribeSync(source, (_) {});
    source.stop = () {
      source.stop = null;
      group.subscribeSync(source, (_) {});
      events.add('stop');
    };
    group.cancel();
    expect(events, ['start', 'stop', 'start']);
    expect(source.observerCount, 1);
    group.cancel();
    expect(source.observerCount, 0);
  });

  test('a synchronous observer error is reported and dispatch continues',
      () async {
    final source = _Source(0);
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final error = StateError('observer');
    final calls = <String>[];
    source.subscribeSync((_) => throw error);
    source.subscribeSync((value) => calls.add('sync$value'));
    source.subscribe((value) => calls.add('deferred$value'));
    source.write(1);
    expect(reported.single.exception, same(error));
    expect(reported.single.stack, isNotNull);
    expect(calls, ['sync1']);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['sync1', 'deferred1']);
  });

  testWidgets('DataBinding still rebuilds on the deferred turn',
      (tester) async {
    final source = _Source(0);
    final values = <int>[];
    final inline = source.subscribeSync(values.add);
    await tester.pumpWidget(DataBinding(
        () => Text('${source.value}', textDirection: TextDirection.ltr)));
    source.write(1);
    expect(values, [1]);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('0'), findsOneWidget);
    await tester.pump(Duration.zero);
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    inline.cancel();
    expect(source.starts, 1);
    expect(source.stops, 1);
  });

  testWidgets('DataBinding only collects reads from the widget',
      (tester) async {
    final input = _Source(0);
    final other = _Source(42);
    final displayed = _Source(7);
    final values = <int>[];
    input.subscribeSync((_) => values.add(other.value));
    await tester.pumpWidget(DataBinding(() {
      input.write(1);
      return Text('${displayed.value}', textDirection: TextDirection.ltr);
    }));
    expect(values, [42]);
    expect(other.starts, 0);
    expect(displayed.observerCount, 1);
  });
}
