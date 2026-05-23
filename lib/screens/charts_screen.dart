import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/glucose_data_service.dart';
import '../services/dexcom_service.dart';
import '../services/events_service.dart';
import '../models/user_event.dart';
import '../models/glucose_reading.dart';

enum Timeframe { threeHours, sixHours, twelveHours, twentyFourHours, oneMonth }

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  final _dataService = GlucoseDataService();
  final _eventsService = EventsService();
  Timeframe _selectedTimeframe = Timeframe.twentyFourHours;

  @override
  void initState() {
    super.initState();
    _eventsService.getEvents();
  }

  List<GlucoseReading> _filterReadings(List<GlucoseReading> allReadings) {
    final now = DateTime.now();
    DateTime cutoff;

    switch (_selectedTimeframe) {
      case Timeframe.threeHours: cutoff = now.subtract(const Duration(hours: 3)); break;
      case Timeframe.sixHours: cutoff = now.subtract(const Duration(hours: 6)); break;
      case Timeframe.twelveHours: cutoff = now.subtract(const Duration(hours: 12)); break;
      case Timeframe.twentyFourHours: cutoff = now.subtract(const Duration(hours: 24)); break;
      case Timeframe.oneMonth: cutoff = now.subtract(const Duration(days: 30)); break;
    }
    return allReadings.where((r) => r.time.isAfter(cutoff)).toList();
  }

  double _getBottomTitleInterval(int totalPoints) {
    if (totalPoints == 0) return 1.0;
    switch (_selectedTimeframe) {
      case Timeframe.threeHours: return 6;
      case Timeframe.sixHours: return 12;
      case Timeframe.twelveHours: return 24;
      case Timeframe.twentyFourHours: return 48;
      case Timeframe.oneMonth: return 72;
    }
  }

  void _showEventsModal(BuildContext context, List<UserEvent> eventsAtSpot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              const Text("Szczegóły zdarzeń", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: eventsAtSpot.length,
                  itemBuilder: (context, index) {
                    final e = eventsAtSpot[index];
                    IconData iconData;
                    Color iconColor;
                    String title;

                    switch (e.type) {
                      case EventType.bg: iconData = Icons.water_drop; iconColor = Colors.teal; title = "Glikemia: ${e.value?.toInt()} mg/dL"; break;
                      case EventType.insulin: iconData = Icons.vaccines; iconColor = Colors.blueAccent; title = "Insulina: ${e.value} j."; break;
                      case EventType.carbs: iconData = Icons.restaurant; iconColor = Colors.orangeAccent; title = "Posiłek: ${e.value?.toInt()} g"; break;
                      case EventType.note: iconData = Icons.notes; iconColor = Colors.grey; title = "Notatka"; break;
                      default: iconData = Icons.help; iconColor = Colors.grey; title = "Inne";
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.grey.withOpacity(0.05),
                      elevation: 0,
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: iconColor, child: Icon(iconData, color: Colors.white)),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: (e.note != null && e.note!.isNotEmpty) 
                            ? Text(e.note!)
                            : const Text("Brak dodatkowych informacji.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("ZAMKNIJ"),
                ),
              )
            ],
          ),
        );
      },
    );
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
        builder: (context, snapshotBg) {
          final allReadings = snapshotBg.data;

          if (allReadings == null || allReadings.isEmpty) {
            if (snapshotBg.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text("Brak dostępnych danych do wykresu."));
          }

          final thresholds = DexcomService().currentThresholds;
          final double lowLimit = thresholds["low"]!.toDouble();
          final double highLimit = thresholds["high"]!.toDouble();

          final filteredReadings = _filterReadings(allReadings);
          final chronologicalReadings = filteredReadings.reversed.toList();

          if (chronologicalReadings.isEmpty) {
            return Column(
              children: [
                _buildTimeframeSelector(),
                const Expanded(child: Center(child: Text("Brak odczytów dla wybranego okresu."))),
              ],
            );
          }

          return StreamBuilder<List<UserEvent>>(
            stream: _eventsService.eventsStream,
            initialData: _eventsService.lastEvents,
            builder: (context, snapshotEv) {
              final allEvents = snapshotEv.data ?? [];
              
              final manualEvents = allEvents.where((e) => e.type != EventType.hypo && e.type != EventType.hyper).toList();

              Map<int, List<UserEvent>> eventsByXIndex = {};
              for (var event in manualEvents) {
                int closestIdx = -1;
                int minDiff = 15 * 60 * 1000;

                for (int i = 0; i < chronologicalReadings.length; i++) {
                  final diff = chronologicalReadings[i].time.difference(event.timestamp).inMilliseconds.abs();
                  if (diff < minDiff) {
                    minDiff = diff;
                    closestIdx = i;
                  }
                }

                if (closestIdx != -1) {
                  eventsByXIndex.putIfAbsent(closestIdx, () => []).add(event);
                }
              }

              List<FlSpot> spots = [];
              for (int i = 0; i < chronologicalReadings.length; i++) {
                spots.add(FlSpot(i.toDouble(), chronologicalReadings[i].value.toDouble()));
              }

              final values = chronologicalReadings.map((r) => r.value).toList();
              final int maxVal = values.reduce((a, b) => a > b ? a : b);
              final int minVal = values.reduce((a, b) => a < b ? a : b);
              final int avgVal = (values.reduce((a, b) => a + b) / values.length).round();

              Widget chartWidget = LineChart(
                LineChartData(
                  minY: 40,
                  maxY: 300,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 40,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.12), strokeWidth: 1),
                  ),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      if (event is FlTapUpEvent && touchResponse?.lineBarSpots != null) {
                        final spotIndex = touchResponse!.lineBarSpots!.first.x.toInt();
                        if (eventsByXIndex.containsKey(spotIndex)) {
                          // Wywołanie modala z pełnymi szczegółami
                          _showEventsModal(context, eventsByXIndex[spotIndex]!);
                        }
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (LineBarSpot touchedSpot) => Colors.blueGrey.withOpacity(0.95),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          int idx = touchedSpot.x.toInt();
                          if (idx >= 0 && idx < chronologicalReadings.length) {
                            final reading = chronologicalReadings[idx];
                            final timeStr = "${reading.time.hour.toString().padLeft(2, '0')}:${reading.time.minute.toString().padLeft(2, '0')}";
                            
                            String tooltipText = "${reading.value} mg/dL\n$timeStr";

                            if (eventsByXIndex.containsKey(idx)) {
                              final eventsAtSpot = eventsByXIndex[idx]!;
                              tooltipText += "\n---";
                              for (var e in eventsAtSpot) {
                                if (e.type == EventType.insulin) tooltipText += "\n💉 ${e.value} j.";
                                else if (e.type == EventType.carbs) tooltipText += "\n🍎 ${e.value?.toInt()} g";
                                else if (e.type == EventType.bg) tooltipText += "\n🩸 ${e.value?.toInt()} mg/dL";
                                else if (e.type == EventType.note) {
                                  String shortNote = e.note ?? "";
                                  if (shortNote.length > 15) shortNote = "${shortNote.substring(0, 15)}...";
                                  tooltipText += "\n📝 $shortNote";
                                }
                              }
                            }

                            return LineTooltipItem(
                              tooltipText,
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: _getBottomTitleInterval(chronologicalReadings.length),
                        getTitlesWidget: (value, meta) {
                          int idx = value.toInt();
                          if (idx < 0 || idx >= chronologicalReadings.length) return const SizedBox.shrink();
                          final reading = chronologicalReadings[idx];
                          
                          String titleText = "";
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
                            child: Text(titleText, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w500)),
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
                      HorizontalLine(y: lowLimit, color: Colors.red.withOpacity(0.5), strokeWidth: 1.5, dashArray: [6, 4]),
                      HorizontalLine(y: highLimit, color: Colors.orange.withOpacity(0.5), strokeWidth: 1.5, dashArray: [6, 4]),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: _selectedTimeframe != Timeframe.oneMonth,
                      barWidth: 2.5,
                      color: Colors.blueAccent,
                      belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.06)),
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) {
                          return eventsByXIndex.containsKey(spot.x.toInt());
                        },
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5.5,
                            color: Colors.deepPurpleAccent,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );

              if (_selectedTimeframe == Timeframe.oneMonth) {
                chartWidget = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: SizedBox(
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
            }
          );
        },
      ),
    );
  }

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
                if (selected) setState(() => _selectedTimeframe = timeframe);
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
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
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
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}