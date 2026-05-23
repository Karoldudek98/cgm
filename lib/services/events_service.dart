import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_event.dart';

class EventsService {
  static final EventsService _instance = EventsService._internal();
  factory EventsService() => _instance;
  EventsService._internal();

  final _storage = const FlutterSecureStorage();
  final String _storageKey = "cached_user_events";

  final _eventsStreamController = StreamController<List<UserEvent>>.broadcast();
  Stream<List<UserEvent>> get eventsStream => _eventsStreamController.stream;
  
  List<UserEvent> _lastEvents = [];
  List<UserEvent> get lastEvents => _lastEvents;

  Future<List<UserEvent>> getEvents() async {
    try {
      final data = await _storage.read(key: _storageKey);
      if (data != null) {
        List<dynamic> decoded = jsonDecode(data);
        List<UserEvent> events = decoded.map((e) => UserEvent.fromJson(e)).toList();
        
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        events = events.where((e) => e.timestamp.isAfter(thirtyDaysAgo)).toList();
        events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        _lastEvents = events;
        _eventsStreamController.add(events);
        return events;
      }
    } catch (e) {
      print("Błąd pobierania zdarzeń: $e");
    }
    
    _lastEvents = [];
    _eventsStreamController.add([]);
    return [];
  }

  Future<UserEvent?> getOpenEpisode() async {
    final events = await getEvents();
    try {
      return events.firstWhere(
        (e) => (e.type == EventType.hypo || e.type == EventType.hyper) && e.endTime == null
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> closeEpisode(String id, DateTime endTime) async {
    final events = await getEvents();
    final index = events.indexWhere((e) => e.id == id);
    if (index != -1) {
      final old = events[index];
      events[index] = UserEvent(
        id: old.id,
        timestamp: old.timestamp,
        endTime: endTime,
        type: old.type,
        value: old.value,
        note: old.note,
        isEditable: old.isEditable,
      );
      await _saveToStorage(events);
    }
  }

  Future<void> saveEvent(UserEvent newEvent) async {
    final events = await getEvents();
    events.add(newEvent);
    await _saveToStorage(events);
  }

  Future<void> updateEvent(UserEvent updatedEvent) async {
    final events = await getEvents();
    final index = events.indexWhere((e) => e.id == updatedEvent.id);
    if (index != -1) {
      events[index] = updatedEvent;
      await _saveToStorage(events);
    }
  }

  Future<void> deleteEvent(String id) async {
    final events = await getEvents();
    events.removeWhere((e) => e.id == id);
    await _saveToStorage(events);
  }

  Future<void> _saveToStorage(List<UserEvent> events) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final filtered = events.where((e) => e.timestamp.isAfter(thirtyDaysAgo)).toList();
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final jsonString = jsonEncode(filtered.map((e) => e.toJson()).toList());
    await _storage.write(key: _storageKey, value: jsonString);
    
    _lastEvents = filtered;
    _eventsStreamController.add(filtered);
  }
}