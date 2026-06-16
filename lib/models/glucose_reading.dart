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
      final trendRaw = json['Trend'].toString();
      
      trendInt = int.tryParse(trendRaw) ?? 0;
      
      if (trendInt == 0) {
        switch (trendRaw.toLowerCase()) {
          case 'doubleup': trendInt = 1; break;
          case 'singleup': trendInt = 2; break;
          case 'fortyfiveup': trendInt = 3; break;
          case 'flat': trendInt = 4; break;
          case 'fortyfivedown': trendInt = 5; break;
          case 'singledown': trendInt = 6; break;
          case 'doubledown': trendInt = 7; break;
          default: trendInt = 0;
        }
      }
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