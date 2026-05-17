import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/glucose_data_service.dart';
import '../services/dexcom_service.dart';

class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = GlucoseDataService();
    
    final thresholds = DexcomService().currentThresholds;
    final double lowLimit = thresholds["low"]!.toDouble();
    final double highLimit = thresholds["high"]!.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wykres Dobowy (24h)"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<List<GlucoseReading>>(
          stream: dataService.glucoseStream,
          initialData: dataService.lastReadings,
          builder: (context, snapshot) {
            final readings = snapshot.data;
            
            if (readings == null || readings.isEmpty) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return const Center(child: Text("Brak dostępnych danych do wykresu."));
            }

            final chronologicalReadings = List<GlucoseReading>.from(readings).reversed.toList();
            final oldestTime = chronologicalReadings.first.time;

            List<FlSpot> spots = chronologicalReadings.map((reading) {
              double x = reading.time.difference(oldestTime).inMinutes.toDouble();
              double y = reading.value.toDouble();
              return FlSpot(x, y);
            }).toList();

            final values = readings.map((r) => r.value).toList();
            final int maxVal = values.reduce((a, b) => a > b ? a : b);
            final int minVal = values.reduce((a, b) => a < b ? a : b);
            final int avgVal = (values.reduce((a, b) => a + b) / values.length).round();

            return Column(
              children: [
                Expanded(
                  child: LineChart(
                    LineChartData(
                      minY: 40,
                      maxY: 300,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 40,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.15),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.withOpacity(0.4)),
                          left: BorderSide(color: Colors.grey.withOpacity(0.4)),
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: lowLimit,
                            color: Colors.red.withOpacity(0.6),
                            strokeWidth: 1.5,
                            dashArray: [6, 6],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                              labelResolver: (_) => "Niski ($lowLimit)",
                            ),
                          ),
                          HorizontalLine(
                            y: highLimit,
                            color: Colors.orange.withOpacity(0.6),
                            strokeWidth: 1.5,
                            dashArray: [6, 6],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                              labelResolver: (_) => "Wysoki ($highLimit)",
                            ),
                          ),
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 3,
                          color: Colors.blueAccent,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blueAccent.withOpacity(0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatTile("Najwyższy", "$maxVal mg/dL", Colors.orange),
                    _buildStatTile("Średni", "$avgVal mg/dL", Colors.green),
                    _buildStatTile("Najniższy", "$minVal mg/dL", Colors.red),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}