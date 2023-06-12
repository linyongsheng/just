# just

Just: a lightweight state management library for Flutter. Base on [Provider](https://pub.dev/packages/provider) and [Get])(https://pub.dev/packages/get)。

# Usage

### Definition ViewModel

ViewModel is state holder, contain `State` and `Action`。

```dart
class HomeViewModel extends ViewModel {
  // state definition
  final count = 0.obs;
  final now = Obs(DateTime.now());
  final name = Obs<String?>(null);
  final age = Obs<int>(10); // 10.obs or Obs(10);

  // action1
  void increment() {
    final newValue = count.value + 1;
    // update state
    setValue(count, newValue);
  }

  // action2
  void syncTime() {
    // update state
    setValue(now, DateTime.now());
  }

  // action3
  void syncUserInfo() {
    var newAge = Random().nextInt(100);
    setValue(age, newAge);
    var wordPair = generateWordPairs().first;
    setValue(name, wordPair.asCamelCase);
  }

  @override
  void dispose() {
    // do something when dispose
    super.dispose();
  }
}

```

### Integration ViewModel
Provider viewModel by `ViewModelProvider`.
```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // integration viewModel (state holder)
    return ViewModelProvider(
      create: (context) => HomeViewModel(),
      child: _HomePage(),
    );
  }
}
```

### DataBinding and Action

Get ViewModel like this:
```dart
final viewModel = context.viewModel<HomeViewModel>();
```

Binding data like this:
```dart
DataBinding(() => Text('count: ${viewModel.count.value}' ))
```
Widget in DataBinding callback will rebuild when the state(count) change.

```dart
class _HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = context.viewModel<HomeViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Just'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // binding state : count
            DataBinding(
              () => Text(
                'count: ${viewModel.count.value}',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 10),
            // binding state : now
            DataBinding(
              () => Text(
                'now: ${viewModel.now.value.millisecondsSinceEpoch}',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 10),
            // binding state : name and age
            DataBinding(
              () => Column(
                children: [
                  Text(
                    'name: ${viewModel.name.value}',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'age: ${viewModel.age.value}',
                    style: const TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                FilledButton(
                  onPressed: () {
                    viewModel.increment();
                  },
                  child: const Text("increment"),
                ),
                FilledButton(
                  onPressed: () {
                    viewModel.syncTime();
                  },
                  child: const Text("syncTime"),
                ),
                FilledButton(
                  onPressed: () {
                    viewModel.syncUserInfo();
                  },
                  child: const Text("syncUserInfo"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```