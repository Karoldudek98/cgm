import 'dart:async';
import 'dexcom_service.dart';
import 'events_service.dart';
import 'settings_service.dart';
import '../models/user_event.dart';
import '../models/glucose_reading.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'notification_service.dart';

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
      await processEpisodes(readings.first);
      _glucoseStreamController.add(readings);
    }
  }

Future<void> processEpisodes(GlucoseReading latestReading) async {
    final thresholds = SettingsService().currentThresholds;
    final isHypo = latestReading.value <= thresholds["low"]!;
    final isHyper = latestReading.value >= thresholds["high"]!;

    final openEpisode = await _eventsService.getOpenEpisode();
    final storage = const FlutterSecureStorage();
    
    final suppressedEventId = await storage.read(key: "suppressed_episode_id");

    if (isHyper) {
      if (openEpisode != null && openEpisode.type == EventType.hyper) {
        if (openEpisode.id != suppressedEventId) {
          await NotificationService().showGlucoseNotification(
            "Hiperglikemia: ${latestReading.value}", 
            "Wysoki poziom cukru.",
            openEpisode.id
          );
        }
        return;
      }
      
      if (openEpisode != null) await _eventsService.closeEpisode(openEpisode.id, latestReading.time);
      
      final newEventId = "sys_${DateTime.now().millisecondsSinceEpoch}";
      await _eventsService.saveEvent(UserEvent(
        id: newEventId,
        timestamp: latestReading.time,
        type: EventType.hyper,
        isEditable: false,
      ));
      
      await NotificationService().showGlucoseNotification(
        "Hiperglikemia: ${latestReading.value}", 
        "Cukier przekroczył poziom ${thresholds["high"]}.",
        newEventId
      );

    } else if (isHypo) {
      if (openEpisode != null && openEpisode.type == EventType.hypo) {
        if (openEpisode.id != suppressedEventId) {
          await NotificationService().showGlucoseNotification(
            "Hipoglikemia: ${latestReading.value}", 
            "Niski poziom cukru.",
            openEpisode.id
          );
        }
        return;
      }
      
      if (openEpisode != null) await _eventsService.closeEpisode(openEpisode.id, latestReading.time);
      
      final newEventId = "sys_${DateTime.now().millisecondsSinceEpoch}";
      await _eventsService.saveEvent(UserEvent(
        id: newEventId,
        timestamp: latestReading.time,
        type: EventType.hypo,
        isEditable: false,
      ));

      await NotificationService().showGlucoseNotification(
        "Hipoglikemia: ${latestReading.value}", 
        "Cukier spadł poniżej poziomu ${thresholds["low"]}.",
        newEventId
      );

    } else {
      if (openEpisode != null) {
        await _eventsService.closeEpisode(openEpisode.id, latestReading.time);
      }
      
      await NotificationService().clearNotification();
      
      await storage.delete(key: "suppressed_episode_id");
    }
  }

  void emitCurrentReading() {
    _glucoseStreamController.add(_lastReadings);
  }

  void stopUpdates() {
    _refreshTimer?.cancel();
  }
}