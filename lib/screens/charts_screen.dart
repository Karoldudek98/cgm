import 'package:flutter/material.dart';

class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analiza Glikemii")),
      body: const Center(child: Text("Tu pojawi się wykres 24h")),
    );
  }
}