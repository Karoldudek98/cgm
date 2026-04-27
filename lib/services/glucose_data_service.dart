import 'dart:async';
import 'dexcom_service.dart';

class GlucoseDataService {
  static final GlucoseDataService _instance = GlucoseDataService._internal();
  factory GlucoseDataService() => _instance;
  GlucoseDataService._internal();

  final _dexService = DexcomService();
  Timer? _refreshTimer;

  // Stream rozsyłający dane do całej aplikacji
  final _glucoseStreamController = StreamController<GlucoseReading?>.broadcast();
  Stream<GlucoseReading?> get glucoseStream => _glucoseStreamController.stream;

  void startUpdates() {
    _refreshTimer?.cancel();
    _fetchNow(); // Pobierz natychmiast
    // Ustaw timer na co 1 minutę
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchNow());
  }

  Future<void> _fetchNow() async {
    final reading = await _dexService.getLatestReading();
    _glucoseStreamController.add(reading);
  }

  void stopUpdates() {
    _refreshTimer?.cancel();
  }
}