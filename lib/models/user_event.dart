enum EventType { bg, insulin, carbs, note, hypo, hyper }

class UserEvent {
  final String id;
  final DateTime timestamp;
  final DateTime? endTime;
  final EventType type;
  final double? value;
  final String? note;
  final bool isEditable;

  UserEvent({
    required this.id,
    required this.timestamp,
    this.endTime,
    required this.type,
    this.value,
    this.note,
    this.isEditable = true,
  });

  factory UserEvent.fromJson(Map<String, dynamic> json) {
    return UserEvent(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      type: EventType.values.firstWhere((e) => e.name == json['type']),
      value: json['value'] != null ? (json['value'] as num).toDouble() : null,
      note: json['note'],
      isEditable: json['isEditable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'type': type.name,
      'value': value,
      'note': note,
      'isEditable': isEditable,
    };
  }
}