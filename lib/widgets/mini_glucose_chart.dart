import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/glucose_reading.dart';
import '../services/settings_service.dart';

class MiniGlucoseChart extends StatelessWidget {
  final List<GlucoseReading> readings;

  const MiniGlucoseChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text("Brak danych do wykresu")),
      );
    }

    final threeHoursAgo = DateTime.now().subtract(const Duration(hours: 3));
    final recentReadings = readings.where((r) => r.time.isAfter(threeHoursAgo)).toList();
    recentReadings.sort((a, b) => a.time.compareTo(b.time));

    if (recentReadings.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text("Brak niedawnych odczytów")),
      );
    }

    List<FlSpot> realSpots = recentReadings.map((r) {
      return FlSpot(r.time.millisecondsSinceEpoch.toDouble(), r.value.toDouble());
    }).toList();

    List<FlSpot> predictedSpots = [];
    if (recentReadings.length >= 3) {
      final last = recentReadings.last;
      final past = recentReadings[recentReadings.length - 3];
      
      final timeDiffMinutes = last.time.difference(past.time).inMinutes;
      final valueDiff = last.value - past.value;

      if (timeDiffMinutes > 0) {
        final rateOfChangePerMinute = valueDiff / timeDiffMinutes;
        predictedSpots.add(FlSpot(last.time.millisecondsSinceEpoch.toDouble(), last.value.toDouble()));

        for (int i = 1; i <= 4; i++) {
          final futureTime = last.time.add(Duration(minutes: 15 * i));
          double futureValue = last.value + (rateOfChangePerMinute * 15 * i);
          futureValue = futureValue.clamp(40.0, 300.0); 

          predictedSpots.add(FlSpot(futureTime.millisecondsSinceEpoch.toDouble(), futureValue));
        }
      }
    }

    final minX = threeHoursAgo.millisecondsSinceEpoch.toDouble();
    final maxX = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch.toDouble();

    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService().isMmolLNotifier,
      builder: (context, isMmol, child) {
        final thresholds = SettingsService().currentThresholds;
        final low = thresholds["low"]!.toDouble();
        final high = thresholds["high"]!.toDouble();
        final unit = isMmol ? "mmol/L" : "mg/dL";

        return Container(
          height: 260,
          padding: const EdgeInsets.only(left: 10, right: 24, top: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 45, bottom: 8),
                child: Text(
                  "Glikemia ($unit)",
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: minX,
                    maxX: maxX,
                    minY: 40,
                    maxY: 300,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 50,
                      verticalInterval: 3600000,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
                      getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 50,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max || value == meta.min) return const SizedBox();
                            
                            final displayVal = isMmol 
                                ? (value / 18.0).toStringAsFixed(1) 
                                : value.toStringAsFixed(0);

                            return SideTitleWidget(
                              meta: meta, 
                              child: Text(
                                displayVal,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 3600000,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final time = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                            final hourStr = time.hour.toString().padLeft(2, '0');
                            final minuteStr = time.minute.toString().padLeft(2, '0');

                            return SideTitleWidget(
                              meta: meta,
                              space: 4,
                              child: Text(
                                "$hourStr:$minuteStr",
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
                        bottom: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [FlSpot(minX, high), FlSpot(maxX, high)],
                        isCurved: false,
                        color: Colors.transparent,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.green.withOpacity(0.07),
                          cutOffY: low,
                          applyCutOffY: true,
                        ),
                      ),
                      LineChartBarData(
                        spots: realSpots,
                        isCurved: true,
                        color: Colors.blueAccent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(radius: 2.5, color: Colors.blueAccent, strokeWidth: 0),
                        ),
                      ),
                      if (predictedSpots.isNotEmpty)
                        LineChartBarData(
                          spots: predictedSpots,
                          isCurved: true,
                          color: Colors.grey,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}