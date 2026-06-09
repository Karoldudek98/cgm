import 'package:flutter/material.dart';
import '../services/glucose_data_service.dart';
import '../services/settings_service.dart';

class GlucoseThresholdsWidget extends StatefulWidget {
  const GlucoseThresholdsWidget({super.key});

  @override
  State<GlucoseThresholdsWidget> createState() => _GlucoseThresholdsWidgetState();
}

class _GlucoseThresholdsWidgetState extends State<GlucoseThresholdsWidget> {
  final _settingsService = SettingsService();
  
  int _veryLow = 60;
  int _low = 70;
  int _high = 180;
  int _veryHigh = 240;

  List<int> _options = [];

  @override
  void initState() {
    super.initState();
    final current = _settingsService.currentThresholds;
    _veryLow = current["very_low"]!;
    _low = current["low"]!;
    _high = current["high"]!;
    _veryHigh = current["very_high"]!;
    _ensureOptions();
  }

  void _ensureOptions() {
    _options = List.generate((300 - 40) ~/ 5 + 1, (i) => 40 + (i * 5));
    if (!_options.contains(_veryLow)) _options.add(_veryLow);
    if (!_options.contains(_low)) _options.add(_low);
    if (!_options.contains(_high)) _options.add(_high);
    if (!_options.contains(_veryHigh)) _options.add(_veryHigh);
    _options.sort();
  }

  void _updateVeryLow(int val) {
    setState(() {
      _veryLow = val;
      if (_veryLow >= _low) _low = (_veryLow + 5).clamp(40, 300);
      if (_low >= _high) _high = (_low + 5).clamp(40, 300);
      if (_high >= _veryHigh) _veryHigh = (_high + 5).clamp(40, 300);
      _ensureOptions();
    });
  }

  void _updateLow(int val) {
    setState(() {
      _low = val;
      if (_low <= _veryLow) _veryLow = (_low - 5).clamp(40, 300);
      if (_low >= _high) _high = (_low + 5).clamp(40, 300);
      if (_high >= _veryHigh) _veryHigh = (_high + 5).clamp(40, 300);
      _ensureOptions();
    });
  }

  void _updateHigh(int val) {
    setState(() {
      _high = val;
      if (_high <= _low) _low = (_high - 5).clamp(40, 300);
      if (_low <= _veryLow) _veryLow = (_low - 5).clamp(40, 300);
      if (_high >= _veryHigh) _veryHigh = (_high + 5).clamp(40, 300);
      _ensureOptions();
    });
  }

  void _updateVeryHigh(int val) {
    setState(() {
      _veryHigh = val;
      if (_veryHigh <= _high) _high = (_veryHigh - 5).clamp(40, 300);
      if (_high <= _low) _low = (_high - 5).clamp(40, 300);
      if (_low <= _veryLow) _veryLow = (_low - 5).clamp(40, 300);
      _ensureOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _settingsService.isMmolLNotifier,
      builder: (context, isMmol, child) {
        final unitLabel = isMmol ? "mmol/L" : "mg/dL";

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Konfiguracja progów ($unitLabel)",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 16),
                _buildDropdown("Bardzo niski poziom", _veryLow, _updateVeryLow, isMmol),
                const SizedBox(height: 12),
                _buildDropdown("Niski poziom", _low, _updateLow, isMmol),
                const SizedBox(height: 12),
                _buildDropdown("Wysoki poziom", _high, _updateHigh, isMmol),
                const SizedBox(height: 12),
                _buildDropdown("Bardzo wysoki poziom", _veryHigh, _updateVeryHigh, isMmol),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _settingsService.saveThresholds(_veryLow, _low, _high, _veryHigh);
                      GlucoseDataService().emitCurrentReading();
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Zapisano progi glikemii!")),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text("ZAPISZ PROGI"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildDropdown(String label, int val, ValueChanged<int> onChanged, bool isMmol) {
    return DropdownButtonFormField<int>(
      value: val,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: _options.map((v) {
        final displayValue = isMmol ? (v / 18.0).toStringAsFixed(1) : v.toString();
        final unit = isMmol ? "mmol/L" : "mg/dL";
        return DropdownMenuItem(
          value: v, 
          child: Text("$displayValue $unit"),
        );
      }).toList(),
      onChanged: (v) => {if (v != null) onChanged(v)},
    );
  }
}