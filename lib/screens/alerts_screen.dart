import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Powiadomienia i Alerty")),
      body: const Center(child: Text("Ustawienia progów hypo/hiper")),
    );
  }
}