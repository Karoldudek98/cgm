import 'dart:async';
import 'dexcom_service.dart';

class GlucoseDataService {
  static final GlucoseDataService _instance = GlucoseDataService._internal();
  factory GlucoseDataService() => _instance;
  GlucoseDataService._internal();

  final _dexService = DexcomService();
  Timer? _refreshTimer;
  
  // Pamięć podręczna RAM dla pobranej historii dobowej
  List<GlucoseReading> _lastReadings = [];

  // NAPRAWA BŁĘDU: Zmiana strumienia na przesyłanie List<GlucoseReading>
  final _glucoseStreamController = StreamController<List<GlucoseReading>>.broadcast();
  Stream<List<GlucoseReading>> get glucoseStream => _glucoseStreamController.stream;

  // NAPRAWA BŁĘDU: Dodano getter lastReadings wymagany przez widżety przy starcie
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
  }

  void emitCurrentReading() {
    _glucoseStreamController.add(_lastReadings);
  }

  void stopUpdates() {
    _refreshTimer?.cancel();
  }
}