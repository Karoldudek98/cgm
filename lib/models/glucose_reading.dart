class GlucoseReading {
  final int value;
  final String direction;
  final DateTime time;

  GlucoseReading({required this.value, required this.direction, required this.time});

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
    
    String trendStr = "Flat";
    if (json['Trend'] != null) {
      if (json['Trend'] is int) {
        int trendInt = json['Trend'];
        switch (trendInt) {
          case 1: trendStr = "DoubleUp"; break;
          case 2: trendStr = "SingleUp"; break;
          case 3: trendStr = "FortyFiveUp"; break;
          case 4: trendStr = "Flat"; break;
          case 5: trendStr = "FortyFiveDown"; break;
          case 6: trendStr = "SingleDown"; break;
          case 7: trendStr = "DoubleDown"; break;
          default: trendStr = "Flat";
        }
      } else {
        trendStr = json['Trend'].toString();
      }
    }

    return GlucoseReading(
      value: json['Value'] ?? 0,
      direction: trendStr,
      time: parsedTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Value': value,
      'Trend': direction,
      'ST': time.toIso8601String(),
    };
  }
}