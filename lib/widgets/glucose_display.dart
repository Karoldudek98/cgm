import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class GlucoseDisplay extends StatelessWidget {
  final int glucoseValue; // Przyjmujemy czystą wartość w mg/dL

  const GlucoseDisplay({
    super.key, 
    required this.glucoseValue, 
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService().isMmolLNotifier,
      builder: (context, isMmol, child) {
        final thresholds = SettingsService().currentThresholds;
        
        // Logika 4 kolorów
        Color color = Colors.green;
        if (glucoseValue <= thresholds["very_low"]!) {
          color = Colors.red;
        } else if (glucoseValue <= thresholds["low"]!) {
          color = Colors.orange;
        } else if (glucoseValue >= thresholds["very_high"]!) {
          color = Colors.red;
        } else if (glucoseValue >= thresholds["high"]!) {
          color = Colors.orange;
        }

        final displayValue = isMmol ? (glucoseValue / 18.0).toStringAsFixed(1) : glucoseValue.toString();
        final unit = isMmol ? "mmol/L" : "mg/dL";

        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                unit,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        );
      }
    );
  }
}