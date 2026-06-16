import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/glucose_data_service.dart';
import '../services/settings_service.dart';
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
  Timeframe _selectedTimeframe = Timeframe.threeHours;

  @override
  void initState() {
    super.initState();
    _eventsService.getEvents();
  }

  DateTime _getMinTime(DateTime maxTime) {
    switch (_selectedTimeframe) {
      case Timeframe.threeHours: return maxTime.subtract(const Duration(hours: 3));
      case Timeframe.sixHours: return maxTime.subtract(const Duration(hours: 6));
      case Timeframe.twelveHours: return maxTime.subtract(const Duration(hours: 12));
      case Timeframe.twentyFourHours: return maxTime.subtract(const Duration(hours: 24));
      case Timeframe.oneMonth: return maxTime.subtract(const Duration(days: 30));
    }
  }

  double _getXInterval() {
    switch (_selectedTimeframe) {
      case Timeframe.threeHours: return 3600000; 
      case Timeframe.sixHours: return 7200000; 
      case Timeframe.twelveHours: return 14400000; 
      case Timeframe.twentyFourHours: return 21600000; 
      case Timeframe.oneMonth: return 21600000; 
    }
  }

  void _showEventsModal(BuildContext context, List<UserEvent> eventsAtSpot, bool isMmol) {
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
              const Text("Szczegóły", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      case EventType.bg: 
                        iconData = Icons.water_drop; 
                        iconColor = Colors.teal; 
                        final v = isMmol ? (e.value! / 18.0).toStringAsFixed(1) : e.value!.toInt().toString();
                        final u = isMmol ? "mmol/L" : "mg/dL";
                        title = "Glikemia: $v $u"; 
                        break;
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
                            : const Text("Brak notatki", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("ZAMKNIJ")))
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService().isMmolLNotifier,
      builder: (context, isMmol, child) {
        final double factor = isMmol ? 18.0 : 1.0;
        final String unit = isMmol ? "mmol/L" : "mg/dL";

        return Scaffold(
          appBar: AppBar(title: const Text("Wykres glikemii"), centerTitle: true),
          body: StreamBuilder<List<GlucoseReading>>(
            stream: _dataService.glucoseStream,
            initialData: _dataService.lastReadings,
            builder: (context, snapshotBg) {
              final allReadings = snapshotBg.data;

              if (allReadings == null || allReadings.isEmpty) {
                if (snapshotBg.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                return const Center(child: Text("Brak dostępnych danych."));
              }

              final thresholds = SettingsService().currentThresholds;
              final double lowLimit = thresholds["low"]!.toDouble() / factor;
              final double highLimit = thresholds["high"]!.toDouble() / factor;

              final now = DateTime.now();
              final referenceTime = allReadings.isNotEmpty ? allReadings.first.time : now;
              
              final maxTime = referenceTime;
              final minTime = _getMinTime(maxTime);

              final minX = minTime.millisecondsSinceEpoch.toDouble();
              final maxX = maxTime.millisecondsSinceEpoch.toDouble();
              final xInterval = _getXInterval();

              final filteredReadings = allReadings.where((r) => r.time.isAfter(minTime) || r.time.isAtSameMomentAs(minTime)).toList();
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

                  Map<double, List<UserEvent>> eventsByXValue = {};
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
                      final xVal = chronologicalReadings[closestIdx].time.millisecondsSinceEpoch.toDouble();
                      eventsByXValue.putIfAbsent(xVal, () => []).add(event);
                    }
                  }

                  List<FlSpot> spots = [];
                  for (int i = 0; i < chronologicalReadings.length; i++) {
                    spots.add(FlSpot(chronologicalReadings[i].time.millisecondsSinceEpoch.toDouble(), chronologicalReadings[i].value / factor));
                  }

                  final values = chronologicalReadings.map((r) => r.value).toList();
                  final int maxVal = values.reduce((a, b) => a > b ? a : b);
                  final int minVal = values.reduce((a, b) => a < b ? a : b);
                  final int avgVal = (values.reduce((a, b) => a + b) / values.length).round();

                  Widget chartWidget = LineChart(
                    LineChartData(
                      clipData: const FlClipData.all(),
                      minX: minX,
                      maxX: maxX,
                      minY: 40 / factor,
                      maxY: 300 / factor,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: isMmol ? 2.0 : 40.0,
                        verticalInterval: xInterval,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.12), strokeWidth: 1),
                        getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                      ),
                      lineTouchData: LineTouchData(
                        handleBuiltInTouches: true,
                        getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                              const FlLine(color: Colors.blueAccent, strokeWidth: 3),
                              FlDotData(
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(radius: 6, color: Colors.blueAccent, strokeWidth: 2, strokeColor: Colors.white);
                                },
                              ),
                            );
                          }).toList();
                        },
                        touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                          if (event is FlTapUpEvent && touchResponse?.lineBarSpots != null) {
                            final relevantSpots = touchResponse!.lineBarSpots!.where((spot) => spot.barIndex == 1);
                            if (relevantSpots.isNotEmpty) {
                              final xVal = relevantSpots.first.x;
                              if (eventsByXValue.containsKey(xVal)) {
                                _showEventsModal(context, eventsByXValue[xVal]!, isMmol);
                              }
                            }
                          }
                        },
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (LineBarSpot touchedSpot) => Colors.blueGrey.withOpacity(0.95),
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              if (touchedSpot.barIndex == 0) return null;

                              final time = DateTime.fromMillisecondsSinceEpoch(touchedSpot.x.toInt());
                              final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                              
                              final valStr = isMmol ? touchedSpot.y.toStringAsFixed(1) : (touchedSpot.y).round().toString();
                              String tooltipText = "$valStr $unit\n$timeStr";

                              if (eventsByXValue.containsKey(touchedSpot.x)) {
                                final eventsAtSpot = eventsByXValue[touchedSpot.x]!;
                                tooltipText += "\n---";
                                for (var e in eventsAtSpot) {
                                  if (e.type == EventType.insulin) tooltipText += "\n💉 ${e.value} j.";
                                  else if (e.type == EventType.carbs) tooltipText += "\n🍎 ${e.value?.toInt()} g";
                                  else if (e.type == EventType.bg) {
                                    final v = isMmol ? (e.value! / 18.0).toStringAsFixed(1) : e.value!.toInt().toString();
                                    tooltipText += "\n🩸 $v $unit";
                                  }
                                  else if (e.type == EventType.note) {
                                    String shortNote = e.note ?? "";
                                    if (shortNote.length > 15) shortNote = "${shortNote.substring(0, 15)}...";
                                    tooltipText += "\n📝 $shortNote";
                                  }
                                }
                              }
                              return LineTooltipItem(tooltipText, const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13));
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, 
                            reservedSize: 40,
                            interval: isMmol ? 2.0 : 40.0,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) return const SizedBox();
                              return Text(isMmol ? value.toStringAsFixed(1) : value.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
                            }
                          )
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: xInterval,
                            getTitlesWidget: (value, meta) {
                              final time = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                              if (time.minute != 0) return const SizedBox.shrink();
                              
                              String titleText = "";
                              if (_selectedTimeframe == Timeframe.oneMonth) {
                                final dStr = "${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}";
                                final hStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                titleText = "$dStr\n$hStr";
                              } else {
                                titleText = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                              }
                              
                              return SideTitleWidget(meta: meta, space: 4, child: Text(titleText, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w500)));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.3)), left: BorderSide(color: Colors.grey.withOpacity(0.3)))),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [FlSpot(minX, highLimit), FlSpot(maxX, highLimit)],
                          isCurved: false,
                          color: Colors.transparent,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.green.withOpacity(0.07),
                            cutOffY: lowLimit,
                            applyCutOffY: true,
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: spots,
                          isCurved: _selectedTimeframe != Timeframe.oneMonth,
                          barWidth: 3,
                          color: Colors.blueAccent,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              if (eventsByXValue.containsKey(spot.x)) {
                                return FlDotCirclePainter(radius: 5.5, color: Colors.deepPurpleAccent, strokeWidth: 2, strokeColor: Colors.white);
                              }
                              return FlDotCirclePainter(radius: 2.5, color: Colors.blueAccent, strokeWidth: 0);
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
                        width: 12000, 
                        child: Padding(padding: const EdgeInsets.only(right: 16.0), child: chartWidget)
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        _buildTimeframeSelector(),
                        const SizedBox(height: 16),
                        Expanded(child: Padding(padding: const EdgeInsets.only(right: 10.0, top: 10.0), child: chartWidget)),
                        const SizedBox(height: 16),
                        _buildStatsPanel(minVal, avgVal, maxVal, isMmol),
                      ],
                    ),
                  );
                }
              );
            },
          ),
        );
      }
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
            case Timeframe.oneMonth: label = "1M"; break;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(label),
              selected: _selectedTimeframe == timeframe,
              selectedColor: Colors.blueAccent.withOpacity(0.2),
              labelStyle: TextStyle(color: _selectedTimeframe == timeframe ? Colors.blueAccent : Colors.black87, fontWeight: _selectedTimeframe == timeframe ? FontWeight.bold : FontWeight.normal),
              onSelected: (selected) { if (selected) setState(() => _selectedTimeframe = timeframe); },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsPanel(int min, int avg, int max, bool isMmol) {
    final String unit = isMmol ? "mmol/L" : "mg/dL";
    final String minStr = isMmol ? (min / 18.0).toStringAsFixed(1) : min.toString();
    final String avgStr = isMmol ? (avg / 18.0).toStringAsFixed(1) : avg.toString();
    final String maxStr = isMmol ? (max / 18.0).toStringAsFixed(1) : max.toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatTile("Najniższy", "$minStr $unit", Colors.red),
          _buildStatTile("Średni", "$avgStr $unit", Colors.green),
          _buildStatTile("Najwyższy", "$maxStr $unit", Colors.orange),
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