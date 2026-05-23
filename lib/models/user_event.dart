enum EventType { bg, insulin, carbs, note }

class UserEvent {
  final String id;
  final DateTime timestamp;
  final EventType type;
  final double? value;
  final String? note;

  UserEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    this.value,
    this.note,
  });

  factory UserEvent.fromJson(Map<String, dynamic> json) {
    return UserEvent(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: EventType.values.firstWhere((e) => e.name == json['type']),
      value: json['value'] != null ? (json['value'] as num).toDouble() : null,
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'value': value,
      'note': note,
    };
  }
}