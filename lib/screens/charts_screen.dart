import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/glucose_data_service.dart';
import '../services/dexcom_service.dart';

enum Timeframe { threeHours, sixHours, twelveHours, twentyFourHours, oneMonth }

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  final _dataService = GlucoseDataService();
  Timeframe _selectedTimeframe = Timeframe.twentyFourHours; // Domyślnie 24h

  // Metoda filtrująca dane z bazy na podstawie wybranego okresu
  List<GlucoseReading> _filterReadings(List<GlucoseReading> allReadings) {
    final now = DateTime.now();
    DateTime cutoff;

    switch (_selectedTimeframe) {
      case Timeframe.threeHours:
        cutoff = now.subtract(const Duration(hours: 3));
        break;
      case Timeframe.sixHours:
        cutoff = now.subtract(const Duration(hours: 6));
        break;
      case Timeframe.twelveHours:
        cutoff = now.subtract(const Duration(hours: 12));
        break;
      case Timeframe.twentyFourHours:
        cutoff = now.subtract(const Duration(hours: 24));
        break;
      case Timeframe.oneMonth:
        cutoff = now.subtract(const Duration(days: 30));
        break;
    }

    return allReadings.where((r) => r.time.isAfter(cutoff)).toList();
  }

  // Interwał wyświetlania podpisów na osi X, dostosowany do liczby punktów
  double _getBottomTitleInterval(int totalPoints) {
    if (totalPoints == 0) return 1.0;
    switch (_selectedTimeframe) {
      case Timeframe.threeHours:
        return 6; // Podpis co 30 minut (6 punktów * 5 min)
      case Timeframe.sixHours:
        return 12; // Podpis co 1 godzinę (12 punktów * 5 min)
      case Timeframe.twelveHours:
        return 24; // Podpis co 2 godziny (24 punkty * 5 min)
      case Timeframe.twentyFourHours:
        return 48; // Podpis co 4 godziny (48 punktów * 5 min)
      case Timeframe.oneMonth:
        return 72; // POPRAWKA: Podpis co 6 godzin (6h * 12 odczytów/h = 72)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analiza Glikemii"),
        centerTitle: true,
      ),
      body: StreamBuilder<List<GlucoseReading>>(
        stream: _dataService.glucoseStream,
        initialData: _dataService.lastReadings,
        builder: (context, snapshot) {
          final allReadings = snapshot.data;

          if (allReadings == null || allReadings.isEmpty) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text("Brak dostępnych danych do wykresu."));
          }

          // POPRAWKA: Pobranie progów INSIDE StreamBuilder builder
          // Dzięki temu po kliknięciu zapisu progów wykres natychmiast przerysuje nowe linie zakresów!
          final thresholds = DexcomService().currentThresholds;
          final double lowLimit = thresholds["low"]!.toDouble();
          final double highLimit = thresholds["high"]!.toDouble();

          // Filtrujemy i odwracamy chronologicznie (od najstarszego z lewej do najnowszego z prawej)
          final filteredReadings = _filterReadings(allReadings);
          final chronologicalReadings = filteredReadings.reversed.toList();

          if (chronologicalReadings.isEmpty) {
            return Column(
              children: [
                _buildTimeframeSelector(),
                const Expanded(
                  child: Center(child: Text("Brak odczytów dla wybranego okresu.")),
                ),
              ],
            );
          }

          // Mapowanie punktów glikemii (X jako indeks tablicy zapewnia idealne, równe odstępy)
          List<FlSpot> spots = [];
          for (int i = 0; i < chronologicalReadings.length; i++) {
            spots.add(FlSpot(i.toDouble(), chronologicalReadings[i].value.toDouble()));
          }

          // Obliczanie statystyk dla wybranego przedziału czasowego
          final values = chronologicalReadings.map((r) => r.value).toList();
          final int maxVal = values.reduce((a, b) => a > b ? a : b);
          final int minVal = values.reduce((a, b) => a < b ? a : b);
          final int avgVal = (values.reduce((a, b) => a + b) / values.length).round();

          // Budowanie właściwego komponentu wykresu
          Widget chartWidget = LineChart(
            LineChartData(
              minY: 40,
              maxY: 300,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 40,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.12),
                  strokeWidth: 1,
                ),
              ),
              // POPRAWKA: Konfiguracja małego okienka podpowiedzi (Tooltip) z wartością i czasem odczytu pod spodem
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (LineBarSpot touchedSpot) => Colors.blueGrey.withOpacity(0.95),
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      int idx = touchedSpot.x.toInt();
                      if (idx >= 0 && idx < chronologicalReadings.length) {
                        final reading = chronologicalReadings[idx];
                        final timeStr = "${reading.time.hour.toString().padLeft(2, '0')}:${reading.time.minute.toString().padLeft(2, '0')}";
                        final dateStr = "${reading.time.day.toString().padLeft(2, '0')}.${reading.time.month.toString().padLeft(2, '0')}";
                        
                        return LineTooltipItem(
                          "${reading.value} mg/dL\n$dateStr $timeStr",
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36, // POPRAWKA: Zwiększono rozmiar, aby zmieścić dwuliniowy podpis (Data i Godzina)
                    interval: _getBottomTitleInterval(chronologicalReadings.length),
                    getTitlesWidget: (value, meta) {
                      int idx = value.toInt();
                      if (idx < 0 || idx >= chronologicalReadings.length) {
                        return const SizedBox.shrink();
                      }
                      final reading = chronologicalReadings[idx];
                      String titleText = "";

                      // POPRAWKA: Wykres miesięczny wyświetla teraz sformatowaną datę oraz godzinę w nowej linii
                      if (_selectedTimeframe == Timeframe.oneMonth) {
                        final dStr = "${reading.time.day.toString().padLeft(2, '0')}.${reading.time.month.toString().padLeft(2, '0')}";
                        final hStr = "${reading.time.hour.toString().padLeft(2, '0')}:${reading.time.minute.toString().padLeft(2, '0')}";
                        titleText = "$dStr\n$hStr";
                      } else {
                        titleText = "${reading.time.hour.toString().padLeft(2, '0')}:${reading.time.minute.toString().padLeft(2, '0')}";
                      }

                      return SideTitleWidget(
                        meta: meta,
                        space: 4,
                        child: Text(
                          titleText,
                          textAlign: TextAlign.center, // Środkowanie tekstu wielolinijkowego
                          style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  left: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: lowLimit,
                    color: Colors.red.withOpacity(0.5),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                  HorizontalLine(
                    y: highLimit,
                    color: Colors.orange.withOpacity(0.5),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: _selectedTimeframe != Timeframe.oneMonth,
                  barWidth: 2.5,
                  color: Colors.blueAccent,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blueAccent.withOpacity(0.06),
                  ),
                ),
              ],
            ),
          );

          // Jeśli wybrano widok miesięczny, pakujemy wykres w poziomy widok przewijany
          if (_selectedTimeframe == Timeframe.oneMonth) {
            chartWidget = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // Automatyczne przewinięcie do najnowszych wpisów po prawej stronie
              child: SizedBox(
                // 14 pikseli szerokości przypada na każdy odczyt, gwarantując stałą i czytelną podziałkę
                width: chronologicalReadings.length * 14.0,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: chartWidget,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildTimeframeSelector(),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10.0, top: 10.0),
                    child: chartWidget,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatsPanel(minVal, avgVal, maxVal),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widżet wyboru zakresów czasowych (ChoiceChip)
  Widget _buildTimeframeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: Timeframe.values.map((timeframe) {
          String label = "";
          switch (timeframe) {
            case Timeframe.threeHours: label = "3h"; break;
            case Timeframe.sixHours: label = "6h"; break;
            case Timeframe.twelveHours: label = "12h"; break;
            case Timeframe.twentyFourHours: label = "24h"; break;
            case Timeframe.oneMonth: label = "1M (Przewijany)"; break;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(label),
              selected: _selectedTimeframe == timeframe,
              selectedColor: Colors.blueAccent.withOpacity(0.2),
              labelStyle: TextStyle(
                color: _selectedTimeframe == timeframe ? Colors.blueAccent : Colors.black87,
                fontWeight: _selectedTimeframe == timeframe ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedTimeframe = timeframe);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsPanel(int min, int avg, int max) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatTile("Najniższy", "$min mg/dL", Colors.red),
          _buildStatTile("Średni", "$avg mg/dL", Colors.green),
          _buildStatTile("Najwyższy", "$max mg/dL", Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}