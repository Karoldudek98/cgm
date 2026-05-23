import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/glucose_reading.dart'; // Podpięcie zewnętrznego modelu

class DexcomService {
  static final DexcomService _instance = DexcomService._internal();
  factory DexcomService() => _instance;
  DexcomService._internal();

  final _storage = const FlutterSecureStorage();
  static const String _baseUrl = "shareous1.dexcom.com";
  static const String _appId = "d89443d2-327c-4a6f-89e5-496bbb0317db";
  
  String? _sessionId;
  Map<String, int>? _cachedThresholds;

  Future<bool> initAndLogin() async {
    await getThresholds();
    String? user = await _storage.read(key: "dex_user");
    String? pass = await _storage.read(key: "dex_pass");
    if (user != null && pass != null) {
      final result = await login(user, pass);
      return result == "SUCCESS";
    }
    return false;
  }

  Future<String> login(String username, String password) async {
    try {
      final authResponse = await http.post(
        Uri.https(_baseUrl, "/ShareWebServices/Services/General/AuthenticatePublisherAccount"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({
          "accountName": username.trim(),
          "password": password,
          "applicationId": _appId,
        }),
      );

      if (authResponse.statusCode != 200) return "Błąd autoryzacji (500)";
      
      final accountId = authResponse.body.trim().replaceAll('"', '');
      if (accountId == "00000000-0000-0000-0000-000000000000") return "Błędne dane.";

      final loginResponse = await http.post(
        Uri.https(_baseUrl, "/ShareWebServices/Services/General/LoginPublisherAccountById"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "accountId": accountId,
          "password": password,
          "applicationId": _appId,
        }),
      );

      if (loginResponse.statusCode == 200) {
        final token = loginResponse.body.trim().replaceAll('"', '');
        if (token != "00000000-0000-0000-0000-000000000000") {
          _sessionId = token;
          await _storage.write(key: "dex_user", value: username.trim());
          await _storage.write(key: "dex_pass", value: password);
          return "SUCCESS";
        }
      }
      return "Błąd generowania sesji.";
    } catch (e) {
      return "Błąd połączenia: $e";
    }
  }

  // --- LOGIKA: PRZECHOWYWANIE DO 1 MIESIĄCA (8640 REKORDÓW) ---
  Future<List<GlucoseReading>> getGlucoseHistory() async {
    // 1. Wczytaj istniejącą historię z zaszyfrowanej pamięci podręcznej
    List<GlucoseReading> localHistory = await _loadOfflineHistory();

    if (_sessionId == null) return localHistory;

    // Pobieramy ostatnie 24h z chmury, aby zabezpieczyć aplikację przed lukami w danych (np. gdy była zamknięta)
    final url = Uri.https(_baseUrl, "/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues", {
      "sessionId": _sessionId!,
      "minutes": "1440",
      "maxCount": "288",
    });

    try {
      final response = await http.post(url, headers: {"Content-Length": "0"});
      
      if (response.body.contains("SessionNotValid")) {
        bool refreshed = await initAndLogin();
        if (refreshed) return getGlucoseHistory();
        return localHistory;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          List<GlucoseReading> apiReadings = decoded.map<GlucoseReading>((item) => GlucoseReading.fromJson(item)).toList();

          // 2. ŁĄCZENIE I DEDUPLIKACJA za pomocą słownika Map (kluczem jest milisekundowy timestamp)
          final Map<int, GlucoseReading> mergedMap = {};
          
          for (var r in localHistory) {
            mergedMap[r.time.millisecondsSinceEpoch] = r;
          }
          for (var r in apiReadings) {
            mergedMap[r.time.millisecondsSinceEpoch] = r;
          }

          List<GlucoseReading> mergedList = mergedMap.values.toList();
          
          // 3. SORTOWANIE (od najnowszego do najstarszego)
          mergedList.sort((a, b) => b.time.compareTo(a.time));

          // 4. OGRANICZENIE RETENCJI: 30 dni * 288 odczytów = 8640 maks.
          const int maxRecords = 8640;
          if (mergedList.length > maxRecords) {
            mergedList = mergedList.sublist(0, maxRecords);
          }

          // 5. ZAPIS DO PLIKU
          String serializedJson = jsonEncode(mergedList.map((r) => r.toJson()).toList());
          await _storage.write(key: "cached_glucose_history", value: serializedJson);

          return mergedList;
        }
      }
    } catch (e) {
      print("Błąd pobierania danych sieciowych: $e");
    }

    return localHistory;
  }

  Future<List<GlucoseReading>> _loadOfflineHistory() async {
    try {
      String? cachedData = await _storage.read(key: "cached_glucose_history");
      if (cachedData != null) {
        List<dynamic> jsonData = jsonDecode(cachedData);
        List<GlucoseReading> readings = jsonData.map<GlucoseReading>((item) => GlucoseReading.fromJson(item)).toList();
        readings.sort((a, b) => b.time.compareTo(a.time));
        return readings;
      }
    } catch (e) {
      print("Błąd odczytu dysku offline: $e");
    }
    return [];
  }

  // --- PROGI ALARMOWE ---
  Future<Map<String, int>> getThresholds() async {
    if (_cachedThresholds != null) return _cachedThresholds!;
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
    return _cachedThresholds!;
  }

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

  Map<String, int> get currentThresholds => _cachedThresholds ?? {
    "very_low": 60,
    "low": 70,
    "high": 180,
    "very_high": 240,
  };

  Future<void> logout() async {
    _sessionId = null;
    _cachedThresholds = null;
    await _storage.deleteAll();
  }

  String? get sessionId => _sessionId;
}