import 'dart:async';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class GlucoseDisplay extends StatefulWidget {
  final int glucoseValue;
  final int trend;
  final DateTime timestamp;

  const GlucoseDisplay({
    super.key,
    required this.glucoseValue,
    required this.trend,
    required this.timestamp,
  });

  @override
  State<GlucoseDisplay> createState() => _GlucoseDisplayState();
}

class _GlucoseDisplayState extends State<GlucoseDisplay> {
  Timer? _timer;
  int _minutesAgo = 0;

  @override
  void initState() {
    super.initState();
    _updateMinutesAgo();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateMinutesAgo();
    });
  }

  @override
  void didUpdateWidget(covariant GlucoseDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timestamp != widget.timestamp) {
      _updateMinutesAgo();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateMinutesAgo() {
    if (mounted) {
      setState(() {
        _minutesAgo = DateTime.now().difference(widget.timestamp).inMinutes;
      });
    }
  }

  IconData? _getTrendIcon(int trend) {
    switch (trend) {
      case 1: return Icons.keyboard_double_arrow_up;
      case 2: return Icons.arrow_upward;
      case 3: return Icons.north_east;
      case 4: return Icons.arrow_forward;
      case 5: return Icons.south_east;
      case 6: return Icons.arrow_downward;
      case 7: return Icons.keyboard_double_arrow_down;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService().isMmolLNotifier,
      builder: (context, isMmol, child) {
        final thresholds = SettingsService().currentThresholds;
        
        Color color = Colors.green;
        if (widget.glucoseValue <= thresholds["very_low"]!) {
          color = Colors.red;
        } else if (widget.glucoseValue <= thresholds["low"]!) {
          color = Colors.orange;
        } else if (widget.glucoseValue >= thresholds["very_high"]!) {
          color = Colors.red;
        } else if (widget.glucoseValue >= thresholds["high"]!) {
          color = Colors.orange;
        }

        final displayValue = isMmol ? (widget.glucoseValue / 18.0).toStringAsFixed(1) : widget.glucoseValue.toString();
        final unit = isMmol ? "mmol/L" : "mg/dL";
        final trendIcon = _getTrendIcon(widget.trend);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (trendIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(trendIcon, size: 40, color: color),
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unit,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _minutesAgo == 0 ? "Przed chwilą" : "$_minutesAgo min temu",
              style: TextStyle(
                fontSize: 14,
                color: _minutesAgo > 10 ? Colors.redAccent : Colors.grey,
                fontWeight: _minutesAgo > 10 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }
    );
  }
}