class GlucoseReading {
  final int value;
  final DateTime time;
  final int trend;

  GlucoseReading({
    required this.value, 
    required this.time,
    required this.trend, 
  });

  factory GlucoseReading.fromJson(Map<String, dynamic> json) {
    final rawDate = json['ST']?.toString() ?? "";
    DateTime parsedTime = DateTime.now();
    
    if (rawDate.contains("Date(")) {
      final numbersOnly = rawDate.replaceAll(RegExp(r'[^0-9]'), '');
      if (numbersOnly.isNotEmpty) {
        parsedTime = DateTime.fromMillisecondsSinceEpoch(int.parse(numbersOnly));
      }
    } else if (rawDate.isNotEmpty) {
      try {
        parsedTime = DateTime.parse(rawDate);
      } catch (e) {
        print("Błąd parsowania daty ISO: $rawDate");
      }
    }
    
    int trendInt = 0;
    if (json['Trend'] != null) {
      trendInt = int.tryParse(json['Trend'].toString()) ?? 0;
    }

    return GlucoseReading(
      value: json['Value'] ?? 0,
      time: parsedTime,
      trend: trendInt, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Value': value,
      'Trend': trend, 
      'ST': time.toIso8601String(),
    };
  }
}