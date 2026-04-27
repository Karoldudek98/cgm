import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor CGM"),
        centerTitle: true,
      ),
      body: const Center(
        child: Text("Tu będzie Twój aktualny cukier", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}