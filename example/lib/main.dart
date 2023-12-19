import 'dart:math';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:just/just.dart';
import 'package:just_example/event_bus.dart';
import 'package:just_example/event_bus_ex.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

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
            // binding state : now
            DataBinding(
              () => Text(
                'now: ${viewModel.now.value.millisecondsSinceEpoch}',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 10),
            const Counter(),
            const SizedBox(height: 10),
            const UserInfoWidget(),
            const SizedBox(height: 10),
            Column(
              children: [
                FilledButton(
                  onPressed: () {
                    viewModel.syncTime();
                  },
                  child: const Text("syncTime"),
                ),
                FilledButton(
                  onPressed: () {
                    viewModel.increment();
                  },
                  child: const Text("increment"),
                ),
                FilledButton(
                  onPressed: () {
                    viewModel.syncUserInfo();
                  },
                  child: const Text("syncUserInfo"),
                ),
                FilledButton(
                  onPressed: () {
                    EventBus.fire(ThisIsEvent());
                  },
                  child: const Text("fire event"),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return const HomePage();
                        },
                      ),
                    );
                  },
                  child: const Text("new page"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends DataBindingState<Counter> {
  @override
  Widget buildWithData(BuildContext context) {
    // binding state : count
    final viewModel = context.viewModel<HomeViewModel>();
    return Text(
      'count: ${viewModel.count.value}',
      style: const TextStyle(fontSize: 20),
    );
  }

  @override
  bool shouldRebuild(BuildContext context) {
    final viewModel = context.viewModel<HomeViewModel>();
    return viewModel.count.value < 10;
  }
}

class UserInfoWidget extends DataBindingWidget {
  const UserInfoWidget({super.key});

  @override
  Widget buildWithData(BuildContext context) {
    // binding state : name and age
    final viewModel = context.viewModel<HomeViewModel>();
    return Column(
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
    );
  }
}

class HomeViewModel extends ViewModel {
  // state definition
  final count = 0.obs;
  final now = Obs(DateTime.now());
  final name = Obs<String?>(null);
  final age = Obs<int>(10); // 10.obs or Obs(10);

  HomeViewModel() {
    /// this [eventbus] come from EventbusEx
    eventbus.on<ThisIsEvent>((event) {
      print("receive a event ${DateTime.now()}");
    });
  }

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

class ThisIsEvent {}
