import 'package:flutter/material.dart';
import '../services/dexcom_service.dart';

class GlucoseDisplay extends StatelessWidget {
  final GlucoseReading reading;

  const GlucoseDisplay({super.key, required this.reading});

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case "DoubleUp": return Icons.keyboard_double_arrow_up;
      case "SingleUp": return Icons.arrow_upward;
      case "FortyFiveUp": return Icons.north_east;
      case "Flat": return Icons.arrow_forward;
      case "FortyFiveDown": return Icons.south_east;
      case "SingleDown": return Icons.arrow_downward;
      case "DoubleDown": return Icons.keyboard_double_arrow_down;
      default: return Icons.help_outline;
    }
  }

  Color _getGlucoseColor(int value) {
    if (value < 70) return Colors.red;
    if (value > 180) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = DateTime.now().difference(reading.time).inMinutes;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "${reading.value}",
          style: TextStyle(
            fontSize: 100,
            fontWeight: FontWeight.bold,
            color: _getGlucoseColor(reading.value),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getTrendIcon(reading.direction), size: 48, color: Colors.grey[700]),
            const SizedBox(width: 15),
            Text(
              "$timeAgo min temu",
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}