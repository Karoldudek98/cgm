import 'dart:async';
import 'dexcom_service.dart';
import 'events_service.dart';
import '../models/user_event.dart';
import '../models/glucose_reading.dart';

class GlucoseDataService {
  static final GlucoseDataService _instance = GlucoseDataService._internal();
  factory GlucoseDataService() => _instance;
  GlucoseDataService._internal();

  final _dexService = DexcomService();
  final _eventsService = EventsService();
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
    if (readings.isNotEmpty) {
      _lastReadings = readings;
      
      await _processEpisodes(readings.first);
      
      _glucoseStreamController.add(readings);
    }
  }

  Future<void> _processEpisodes(GlucoseReading latestReading) async {
    final thresholds = _dexService.currentThresholds;
    final isHypo = latestReading.value <= thresholds["low"]!;
    final isHyper = latestReading.value >= thresholds["high"]!;

    final openEpisode = await _eventsService.getOpenEpisode();

    if (isHyper) {
      if (openEpisode != null && openEpisode.type == EventType.hyper) return;
      
      if (openEpisode != null) await _eventsService.closeEpisode(openEpisode.id, latestReading.time); // Było hypo, zamknij
      
      
      await _eventsService.saveEvent(UserEvent(
        id: "sys_${DateTime.now().millisecondsSinceEpoch}",
        timestamp: latestReading.time,
        type: EventType.hyper,
        isEditable: false,
      ));
    } else if (isHypo) {
      if (openEpisode != null && openEpisode.type == EventType.hypo) return;
      
      if (openEpisode != null) await _eventsService.closeEpisode(openEpisode.id, latestReading.time);
      
      
      await _eventsService.saveEvent(UserEvent(
        id: "sys_${DateTime.now().millisecondsSinceEpoch}",
        timestamp: latestReading.time,
        type: EventType.hypo,
        isEditable: false,
      ));
    } else {
      if (openEpisode != null) {
        await _eventsService.closeEpisode(openEpisode.id, latestReading.time);
      }
    }
  }

  void emitCurrentReading() {
    _glucoseStreamController.add(_lastReadings);
  }

  void stopUpdates() {
    _refreshTimer?.cancel();
  }
}