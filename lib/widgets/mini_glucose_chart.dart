import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/glucose_reading.dart';
import '../services/settings_service.dart';
import '../services/events_service.dart';
import '../models/user_event.dart';

class MiniGlucoseChart extends StatefulWidget {
  final List<GlucoseReading> readings;

  const MiniGlucoseChart({super.key, required this.readings});

  @override
  State<MiniGlucoseChart> createState() => _MiniGlucoseChartState();
}

class _MiniGlucoseChartState extends State<MiniGlucoseChart> {
  final _eventsService = EventsService();

  @override
  void initState() {
    super.initState();
    _eventsService.getEvents();
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
                            : const Text("Brak dodatkowych informacji.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
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
    if (widget.readings.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(child: Text("Brak danych do wykresu")),
      );
    }

    final now = DateTime.now();
    final referenceTime = widget.readings.isNotEmpty ? widget.readings.first.time : now; 
    
    final roundedMax = DateTime(referenceTime.year, referenceTime.month, referenceTime.day, referenceTime.hour + 1);
    final maxX = roundedMax.millisecondsSinceEpoch.toDouble();
    
    final minX = roundedMax.subtract(const Duration(hours: 4)).millisecondsSinceEpoch.toDouble();
    final minTime = DateTime.fromMillisecondsSinceEpoch(minX.toInt());

    final recentReadings = widget.readings.where((r) => r.time.isAfter(minTime) || r.time.isAtSameMomentAs(minTime)).toList();
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
        double rateOfChangePerMinute = valueDiff / timeDiffMinutes;
        double currentPredictedValue = last.value.toDouble();

        predictedSpots.add(FlSpot(last.time.millisecondsSinceEpoch.toDouble(), currentPredictedValue));

        for (int i = 1; i <= 4; i++) {
          final futureTime = last.time.add(Duration(minutes: 15 * i));
          currentPredictedValue = currentPredictedValue + (rateOfChangePerMinute * 15);
          currentPredictedValue = currentPredictedValue.clamp(40.0, 300.0); 

          predictedSpots.add(FlSpot(futureTime.millisecondsSinceEpoch.toDouble(), currentPredictedValue));
          rateOfChangePerMinute = rateOfChangePerMinute * 0.65; 
        }
      }
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
          for (int i = 0; i < recentReadings.length; i++) {
            final diff = recentReadings[i].time.difference(event.timestamp).inMilliseconds.abs();
            if (diff < minDiff) {
              minDiff = diff;
              closestIdx = i;
            }
          }
          if (closestIdx != -1) {
            final xVal = recentReadings[closestIdx].time.millisecondsSinceEpoch.toDouble();
            eventsByXValue.putIfAbsent(xVal, () => []).add(event);
          }
        }

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
                        clipData: const FlClipData.all(),
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                            return spotIndexes.map((spotIndex) {
                              return TouchedSpotIndicatorData(
                                const FlLine(color: Colors.blueAccent, strokeWidth: 3),
                                FlDotData(
                                  getDotPainter: (spot, percent, barData, index) {
                                    return FlDotCirclePainter(
                                      radius: 6,
                                      color: Colors.blueAccent,
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
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
                                
                                final displayVal = isMmol 
                                    ? (touchedSpot.y / 18.0).toStringAsFixed(1) 
                                    : touchedSpot.y.round().toString();

                                String tooltipText = "$displayVal $unit\n$timeStr";

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

                                return LineTooltipItem(
                                  tooltipText,
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                );
                              }).toList();
                            },
                          ),
                        ),
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
                                if (value == meta.max || value == meta.min) return const SizedBox();

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
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: realSpots,
                            isCurved: true,
                            color: Colors.blueAccent,
                            barWidth: 3,
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
    );
  }
}