import 'package:flutter/material.dart';
import '../models/glucose_reading.dart';
import '../services/settings_service.dart';

class GlucoseDisplay extends StatelessWidget {
  final GlucoseReading reading;

  const GlucoseDisplay({super.key, required this.reading});

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case "DoubleUp": return Icons.keyboard_double_arrow_up;
      case "SingleUp": return Icons.arrow_upward;
      case "FortyFiveUp": return Icons.call_made;
      case "Flat": return Icons.arrow_forward;
      case "FortyFiveDown": return Icons.call_received;
      case "SingleDown": return Icons.arrow_downward;
      case "DoubleDown": return Icons.keyboard_double_arrow_down;
      default: return Icons.horizontal_rule;
    }
  }

  Color _getGlucoseColor(double value) {
    final thresholds = SettingsService().currentThresholds;
    if (value <= thresholds["very_low"]!) return Colors.red;
    if (value <= thresholds["low"]!) return Colors.redAccent;
    if (value >= thresholds["very_high"]!) return Colors.orange;
    if (value >= thresholds["high"]!) return Colors.orangeAccent;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService().isMmolLNotifier,
      builder: (context, isMmol, child) {
        
        final double rawValue = reading.value.toDouble();
        
        final String valText = isMmol 
            ? (rawValue / 18.0).toStringAsFixed(1) 
            : rawValue.toInt().toString();
            
        final String unitText = isMmol ? "mmol/L" : "mg/dL";
        final Color displayColor = _getGlucoseColor(rawValue);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  valText, 
                  style: TextStyle(
                    fontSize: 80, 
                    fontWeight: FontWeight.bold, 
                    color: displayColor
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  _getTrendIcon(reading.direction),
                  size: 60,
                  color: displayColor,
                ),
              ],
            ),
            Text(
              unitText, 
              style: const TextStyle(
                fontSize: 24, 
                color: Colors.grey, 
                fontWeight: FontWeight.w500
              ),
            ),
          ],
        );
      },
    );
  }
}