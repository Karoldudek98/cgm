import 'package:flutter/material.dart';
import '../services/glucose_data_service.dart';
import '../services/dexcom_service.dart';
import '../widgets/glucose_display.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dataService = GlucoseDataService();

  @override
  void initState() {
    super.initState();
    _dataService.startUpdates(); // Rozpocznij pobieranie przy starcie
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor CGM"),
        centerTitle: true,
      ),
      body: StreamBuilder<GlucoseReading?>(
        stream: _dataService.glucoseStream,
        builder: (context, snapshot) {
          // Stan ładowania tylko przy pierwszym pobraniu
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reading = snapshot.data;

          if (reading == null) {
            return const Center(
              child: Text("Brak danych. Sprawdź połączenie z Dexcom."),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _dataService.startUpdates(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: GlucoseDisplay(reading: reading),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}