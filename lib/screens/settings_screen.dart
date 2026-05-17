import 'package:flutter/material.dart';
import '../services/dexcom_service.dart';
import '../services/glucose_data_service.dart';
import '../widgets/glucose_thresholds_widget.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ustawienia")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const GlucoseThresholdsWidget(),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Wyloguj się", style: TextStyle(color: Colors.red)),
            onTap: () async {
              GlucoseDataService().stopUpdates();
              await DexcomService().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}