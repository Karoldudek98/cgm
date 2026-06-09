import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _storage = const FlutterSecureStorage();
  String? _username;

  Map<String, int> _currentThresholds = {
    "very_low": 54,
    "low": 80,
    "high": 180,
    "very_high": 250
  };
  Map<String, int> get currentThresholds => _currentThresholds;

  bool _isMmol = false;
  final ValueNotifier<bool> isMmolLNotifier = ValueNotifier<bool>(false);
  bool get isMmolL => _isMmol;

  bool _useVibrations = true;
  final ValueNotifier<bool> isVibrationsEnabledNotifier = ValueNotifier<bool>(true);
  bool get useVibrations => _useVibrations;

  Future<void> loadForUser(String username) async {
    _username = username;
    
    String? vlStr = await _storage.read(key: "vlow_thresh_$username");
    String? lStr = await _storage.read(key: "low_thresh_$username");
    String? hStr = await _storage.read(key: "high_thresh_$username");
    String? vhStr = await _storage.read(key: "vhigh_thresh_$username");

    if (lStr != null && hStr != null && vlStr != null && vhStr != null) {
      _currentThresholds = {
        "very_low": int.parse(vlStr),
        "low": int.parse(lStr),
        "high": int.parse(hStr),
        "very_high": int.parse(vhStr)
      };
    }

    String? mmolStr = await _storage.read(key: "is_mmol_$username");
    _isMmol = mmolStr == 'true';
    isMmolLNotifier.value = _isMmol;

    String? vibStr = await _storage.read(key: "use_vibrations_$username");
    _useVibrations = vibStr == null ? true : (vibStr == 'true');
    isVibrationsEnabledNotifier.value = _useVibrations;
  }

  Future<void> saveThresholds(int veryLow, int low, int high, int veryHigh) async {
    _currentThresholds = {
      "very_low": veryLow,
      "low": low,
      "high": high,
      "very_high": veryHigh
    };
    await _storage.write(key: "vlow_thresh_${_username ?? 'default'}", value: veryLow.toString());
    await _storage.write(key: "low_thresh_${_username ?? 'default'}", value: low.toString());
    await _storage.write(key: "high_thresh_${_username ?? 'default'}", value: high.toString());
    await _storage.write(key: "vhigh_thresh_${_username ?? 'default'}", value: veryHigh.toString());
  }

  Future<void> toggleMmolL(bool value) async {
    _isMmol = value;
    isMmolLNotifier.value = value;
    await _storage.write(key: "is_mmol_${_username ?? 'default'}", value: value.toString());
  }

  Future<void> toggleVibrations(bool value) async {
    _useVibrations = value;
    isVibrationsEnabledNotifier.value = value;
    await _storage.write(key: "use_vibrations_${_username ?? 'default'}", value: value.toString());
  }
}