import 'package:flutter/material.dart';
import '../services/dexcom_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dexcomService = DexcomService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String _statusMessage = "Wprowadź dane logowania";
  Color _statusColor = Colors.grey;

  void _handleLogin() async {
    final user = _usernameController.text;
    final pass = _passwordController.text;

    if (user.isEmpty || pass.isEmpty) {
      _updateStatus("Wypełnij oba pola!", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    _updateStatus("Logowanie...", Colors.blue);

    final result = await _dexcomService.login(user, pass);

    setState(() => _isLoading = false);

    if (result == "SUCCESS") {
      _updateStatus("Zalogowano pomyślnie!", Colors.green);
    } else {
      _updateStatus(result, Colors.red);
    }
  }

  void _updateStatus(String msg, Color color) {
    setState(() {
      _statusMessage = msg;
      _statusColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ustawienia Dexcom")),
      body: SingleChildScrollView( // NAPRAWA BŁĘDU OVERFLOW
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.account_circle, size: 100, color: Colors.blue),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Email / Nazwa użytkownika",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Hasło",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                  ? const CircularProgressIndicator() 
                  : const Text("POŁĄCZ Z DEXCOM"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}