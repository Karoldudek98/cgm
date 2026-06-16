import 'package:flutter/material.dart';
import '../models/glucose_reading.dart';
import '../services/settings_service.dart';

class GlucoseSummaryWidget extends StatelessWidget {
  final List<GlucoseReading> readings;

  const GlucoseSummaryWidget({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(16.0),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text("Brak danych do podsumowania")),
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService().isMmolLNotifier,
      builder: (context, isMmol, child) {
        final thresholds = SettingsService().currentThresholds;
        final vLowThresh = thresholds["very_low"]!;
        final lowThresh = thresholds["low"]!;
        final highThresh = thresholds["high"]!;
        final vHighThresh = thresholds["very_high"]!;

        int sum = 0;
        for (var r in readings) {
          sum += r.value;
        }
        final double avgMgdl = sum / readings.length;
        
        final String avgDisplay = isMmol 
            ? (avgMgdl / 18.0).toStringAsFixed(1) 
            : avgMgdl.toStringAsFixed(0);
        final String unit = isMmol ? "mmol/L" : "mg/dL";
        final double gmi = 3.31 + (0.02392 * avgMgdl);

        int vLowCount = 0;
        int lowCount = 0;
        int inRangeCount = 0;
        int highCount = 0;
        int vHighCount = 0;

        for (var r in readings) {
          if (r.value <= vLowThresh) {
            vLowCount++;
          } else if (r.value <= lowThresh) {
            lowCount++;
          } else if (r.value >= vHighThresh) {
            vHighCount++;
          } else if (r.value >= highThresh) {
            highCount++;
          } else {
            inRangeCount++;
          }
        }

        final int total = readings.length;
        final int pctVHigh = (vHighCount / total * 100).round();
        final int pctHigh = (highCount / total * 100).round();
        final int pctInRange = (inRangeCount / total * 100).round();
        final int pctLow = (lowCount / total * 100).round();
        final int pctVLow = (vLowCount / total * 100).round();

        final String targetRangeDisplay = isMmol
            ? "${(lowThresh / 18.0).toStringAsFixed(1)} - ${(highThresh / 18.0).toStringAsFixed(1)} $unit"
            : "$lowThresh - $highThresh $unit";

        return Card(
          elevation: 0,
          color: Colors.grey.withOpacity(0.05),
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Podsumowanie glikemii",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(avgDisplay, "Średnia", unit),
                    Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.3)),
                    _buildStatColumn(gmi.toStringAsFixed(1), "GMI", "%"),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(),
                ),

                const Text(
                  "Czas w zakresie",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 24,
                    child: Row(
                      children: [
                        if (pctVLow > 0) Expanded(flex: pctVLow, child: Container(color: Colors.red[800])),
                        if (pctLow > 0) Expanded(flex: pctLow, child: Container(color: Colors.red)),
                        if (pctInRange > 0) Expanded(flex: pctInRange, child: Container(color: Colors.green)),
                        if (pctHigh > 0) Expanded(flex: pctHigh, child: Container(color: Colors.amber)),
                        if (pctVHigh > 0) Expanded(flex: pctVHigh, child: Container(color: Colors.orange[800])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLegendRow(Colors.orange[800]!, "Bardzo wysoki", pctVHigh),
                _buildLegendRow(Colors.amber, "Wysoki", pctHigh),
                _buildLegendRow(Colors.green, "W zakresie", pctInRange, isBold: true),
                _buildLegendRow(Colors.red, "Niski", pctLow),
                _buildLegendRow(Colors.red[800]!, "Bardzo niski", pctVLow),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Zakres docelowy", style: TextStyle(color: Colors.grey)),
                      Text(targetRangeDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatColumn(String value, String title, String subtitle) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLegendRow(Color color, String label, int percentage, {bool isBold = false}) {
    if (percentage == 0 && !isBold) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
              ),
            ),
          ),
          Text(
            "$percentage%",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}