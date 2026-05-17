import 'package:flutter/material.dart';
import '../services/dexcom_service.dart';
import '../services/glucose_data_service.dart';



class GlucoseThresholdsWidget extends StatefulWidget {
  const GlucoseThresholdsWidget({super.key});

  @override
  State<GlucoseThresholdsWidget> createState() => _GlucoseThresholdsWidgetState();
}

class _GlucoseThresholdsWidgetState extends State<GlucoseThresholdsWidget> {
  final _dexService = DexcomService();
  
  int _veryLow = 60;
  int _low = 70;
  int _high = 180;
  int _veryHigh = 240;

  final List<int> _options = List.generate((300 - 40) ~/ 5 + 1, (i) => 40 + (i * 5));

  @override
  void initState() {
    super.initState();
    final current = _dexService.currentThresholds;
    _veryLow = current["very_low"]!;
    _low = current["low"]!;
    _high = current["high"]!;
    _veryHigh = current["very_high"]!;
  }

  void _updateVeryLow(int val) {
    setState(() {
      _veryLow = val;
      if (_veryLow >= _low) _low = (_veryLow + 5).clamp(40, 300);
      if (_low >= _high) _high = (_low + 5).clamp(40, 300);
      if (_high >= _veryHigh) _veryHigh = (_high + 5).clamp(40, 300);
    });
  }

  void _updateLow(int val) {
    setState(() {
      _low = val;
      if (_low <= _veryLow) _veryLow = (_low - 5).clamp(40, 300);
      if (_low >= _high) _high = (_low + 5).clamp(40, 300);
      if (_high >= _veryHigh) _veryHigh = (_high + 5).clamp(40, 300);
    });
  }

  void _updateHigh(int val) {
    setState(() {
      _high = val;
      if (_high <= _low) _low = (_high - 5).clamp(40, 300);
      if (_low <= _veryLow) _veryLow = (_low - 5).clamp(40, 300);
      if (_high >= _veryHigh) _veryHigh = (_high + 5).clamp(40, 300);
    });
  }

  void _updateVeryHigh(int val) {
    setState(() {
      _veryHigh = val;
      if (_veryHigh <= _high) _high = (_veryHigh - 5).clamp(40, 300);
      if (_high <= _low) _low = (_high - 5).clamp(40, 300);
      if (_low <= _veryLow) _veryLow = (_low - 5).clamp(40, 300);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Konfiguracja progów (mg/dL)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 16),
            _buildDropdown("Bardzo niski poziom", _veryLow, _updateVeryLow),
            const SizedBox(height: 12),
            _buildDropdown("Niski poziom", _low, _updateLow),
            const SizedBox(height: 12),
            _buildDropdown("Wysoki poziom", _high, _updateHigh),
            const SizedBox(height: 12),
            _buildDropdown("Bardzo wysoki poziom", _veryHigh, _updateVeryHigh),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _dexService.saveThresholds(_veryLow, _low, _high, _veryHigh);

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

  Widget _buildDropdown(String label, int val, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      value: val,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: _options.map((v) => DropdownMenuItem(value: v, child: Text("$v mg/dL"))).toList(),
      onChanged: (v) => {if (v != null) onChanged(v)},
    );
  }
}