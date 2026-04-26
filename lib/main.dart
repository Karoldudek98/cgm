import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/charts_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const CGMApp());
}

class CGMApp extends StatelessWidget {
  const CGMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CGM Dexcom',
      debugShowCheckedModeBanner: false, // Usuwa czerwony pasek "Debug"
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // Lista naszych ekranów
  final List<Widget> _screens = [
    const HomeScreen(),
    const ChartsScreen(),
    const AlertsScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CGM Monitor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _screens[_selectedIndex], // Wyświetla wybrany ekran
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Start'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Wykresy'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerty'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ustawienia'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}