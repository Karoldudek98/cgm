import 'package:flutter/material.dart';
import 'screens/main_navigation.dart';
import 'screens/login_screen.dart'; // <--- Upewnij się, że ścieżka do Twojego ekranu logowania jest poprawna!
import 'services/settings_service.dart';
import 'services/dexcom_service.dart'; // <--- Dodajemy import DexcomService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init(); 
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CGM App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: DexcomService().initAndLogin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (snapshot.data == true) {
            return const MainNavigation();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}