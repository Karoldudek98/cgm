import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _storage = const FlutterSecureStorage();
  
  // Przełącznik jednostek
  final ValueNotifier<bool> isMmolLNotifier = ValueNotifier<bool>(false);
  
  // Zmienna przechowująca progi
  Map<String, int>? _cachedThresholds;

  // Inicjalizacja przy starcie aplikacji
  Future<void> init() async {
    // 1. Ładowanie jednostki
    String? val = await _storage.read(key: "unit_is_mmol");
    isMmolLNotifier.value = val == "true";

    // 2. Ładowanie progów (zawsze trzymamy je w mg/dL w bazie)
    String? vLow = await _storage.read(key: "thresh_very_low");
    String? low = await _storage.read(key: "thresh_low");
    String? high = await _storage.read(key: "thresh_high");
    String? vHigh = await _storage.read(key: "thresh_very_high");

    _cachedThresholds = {
      "very_low": int.tryParse(vLow ?? "") ?? 60,
      "low": int.tryParse(low ?? "") ?? 70,
      "high": int.tryParse(high ?? "") ?? 180,
      "very_high": int.tryParse(vHigh ?? "") ?? 240,
    };
  }

  // --- LOGIKA JEDNOSTEK ---
  bool get isMmolL => isMmolLNotifier.value;

  Future<void> setUnit(bool isMmol) async {
    isMmolLNotifier.value = isMmol;
    await _storage.write(key: "unit_is_mmol", value: isMmol.toString());
  }

  // --- LOGIKA PROGÓW ALARMOWE ---
  Map<String, int> get currentThresholds => _cachedThresholds ?? {
    "very_low": 60,
    "low": 70,
    "high": 180,
    "very_high": 240,
  };

  Future<void> saveThresholds(int veryLow, int low, int high, int veryHigh) async {
    await _storage.write(key: "thresh_very_low", value: veryLow.toString());
    await _storage.write(key: "thresh_low", value: low.toString());
    await _storage.write(key: "thresh_high", value: high.toString());
    await _storage.write(key: "thresh_very_high", value: veryHigh.toString());

    _cachedThresholds = {
      "very_low": veryLow,
      "low": low,
      "high": high,
      "very_high": veryHigh,
    };
  }
}