import 'package:flutter/material.dart';
import '../services/glucose_data_service.dart';
import '../widgets/glucose_display.dart';
import '../models/glucose_reading.dart';

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
    _dataService.startUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor CGM"),
        centerTitle: true,
      ),
      body: StreamBuilder<List<GlucoseReading>>(
        stream: _dataService.glucoseStream,
        initialData: _dataService.lastReadings,
        builder: (context, snapshot) {
          final readings = snapshot.data;

          if (readings == null || readings.isEmpty) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(
              child: Text("Brak danych. Sprawdź połączenie z Dexcom."),
            );
          }

          final latestReading = readings.first;

          return RefreshIndicator(
            onRefresh: () async {
              _dataService.startUpdates();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: GlucoseDisplay(reading: latestReading),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}