import 'package:flutter/material.dart';
import 'package:just/just.dart';

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
            DataBinding(
              () => Text(
                'count: ${viewModel.counter.value}',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                viewModel.increment();
              },
              child: const Text("increment"),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeViewModel extends ViewModel {
  final counter = 0.obs;

  void increment() {
    final newValue = counter.value + 1;
    setValue(counter, newValue);
  }
}
