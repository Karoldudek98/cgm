import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/dexcom_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _veryLowCtrl = TextEditingController();
  final _lowCtrl = TextEditingController();
  final _highCtrl = TextEditingController();
  final _veryHighCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // Zmienione na SettingsService
    final thresholds = SettingsService().currentThresholds;
    _veryLowCtrl.text = thresholds["very_low"].toString();
    _lowCtrl.text = thresholds["low"].toString();
    _highCtrl.text = thresholds["high"].toString();
    _veryHighCtrl.text = thresholds["very_high"].toString();
  }

  void _saveSettings() async {
    await SettingsService().saveThresholds(
      int.tryParse(_veryLowCtrl.text) ?? 60,
      int.tryParse(_lowCtrl.text) ?? 70,
      int.tryParse(_highCtrl.text) ?? 180,
      int.tryParse(_veryHighCtrl.text) ?? 240,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ustawienia zapisane!"), backgroundColor: Colors.green),
      );
    }
  }

  void _logout() async {
    await DexcomService().logout();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()), 
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ustawienia"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Preferencje jednostek", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService().isMmolLNotifier,
            builder: (context, isMmolL, child) {
              return Card(
                elevation: 0,
                color: Colors.grey.withOpacity(0.08),
                child: SwitchListTile(
                  title: const Text("Jednostka glikemii"),
                  subtitle: Text(isMmolL ? "Wybrano: mmol/L" : "Wybrano: mg/dL", style: const TextStyle(color: Colors.blueAccent)),
                  activeColor: Colors.blueAccent,
                  value: isMmolL,
                  onChanged: (val) => SettingsService().setUnit(val),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          const Text("Progi alarmowe (Zawsze podawaj w mg/dL)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildThresholdField("Bardzo niski", _veryLowCtrl),
          _buildThresholdField("Niski", _lowCtrl),
          _buildThresholdField("Wysoki", _highCtrl),
          _buildThresholdField("Bardzo wysoki", _veryHighCtrl),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
            child: const Text("ZAPISZ PROGI"),
          ),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text("Wyloguj z Dexcom", style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          )
        ],
      ),
    );
  }

  Widget _buildThresholdField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}