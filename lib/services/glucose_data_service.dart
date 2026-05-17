import 'dart:async';
import 'dexcom_service.dart';

class GlucoseDataService {
  static final GlucoseDataService _instance = GlucoseDataService._internal();
  factory GlucoseDataService() => _instance;
  GlucoseDataService._internal();

  final _dexService = DexcomService();
  Timer? _refreshTimer;
  
  List<GlucoseReading> _lastReadings = [];

  final _glucoseStreamController = StreamController<List<GlucoseReading>>.broadcast();
  Stream<List<GlucoseReading>> get glucoseStream => _glucoseStreamController.stream;

  List<GlucoseReading> get lastReadings => _lastReadings;

  void startUpdates() {
    _refreshTimer?.cancel();
    _fetchNow();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _fetchNow());
  }

  Future<void> _fetchNow() async {
    final readings = await _dexService.getGlucoseHistory();
    _lastReadings = readings;
    _glucoseStreamController.add(readings);

    if (readings.isNotEmpty) {
    print("--- DIAGNOSTYKA CZASU ---");
    print("Czas telefonu (Local): ${DateTime.now()}");
    print("Najnowszy odczyt z API: ${readings.first.time}");
    print("Różnica w minutach: ${DateTime.now().difference(readings.first.time).inMinutes} min");
  }
  }

  void emitCurrentReading() {
    _glucoseStreamController.add(_lastReadings);
  }

  void stopUpdates() {
    _refreshTimer?.cancel();
  }
}