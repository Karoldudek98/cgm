import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- BEZPIECZNY MODEL DANYCH ---
class GlucoseReading {
  final int value;
  final String direction;
  final DateTime time;

  GlucoseReading({required this.value, required this.direction, required this.time});

  factory GlucoseReading.fromJson(Map<String, dynamic> json) {
    final rawDate = json['ST']?.toString() ?? "";
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    if (rawDate.isNotEmpty) {
      final numbersOnly = rawDate.replaceAll(RegExp(r'[^0-9]'), '');
      if (numbersOnly.isNotEmpty) {
        timestamp = int.parse(numbersOnly);
      }
    }
    
    // Bezpieczna konwersja trendu (obsługuje int oraz String z API Dexcom)
    String trendStr = "Flat";
    if (json['Trend'] != null) {
      if (json['Trend'] is int) {
        int trendInt = json['Trend'];
        switch (trendInt) {
          case 1: trendStr = "DoubleUp"; break;
          case 2: trendStr = "SingleUp"; break;
          case 3: trendStr = "FortyFiveUp"; break;
          case 4: trendStr = "Flat"; break;
          case 5: trendStr = "FortyFiveDown"; break;
          case 6: trendStr = "SingleDown"; break;
          case 7: trendStr = "DoubleDown"; break;
          default: trendStr = "Flat";
        }
      } else {
        trendStr = json['Trend'].toString();
      }
    }

    return GlucoseReading(
      value: json['Value'] ?? 0,
      direction: trendStr,
      time: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Value': value,
      'Trend': direction,
      'ST': "/Date(${time.millisecondsSinceEpoch})/",
    };
  }
}

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
    await getThresholds(); // Wczytanie progów do RAMu przy starcie
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

  // POBIERANIE HISTORII (Z OBSŁUGĄ TRYBU OFFLINE)
  Future<List<GlucoseReading>> getGlucoseHistory({int minutes = 1440, int maxCount = 288}) async {
    if (_sessionId == null) return await _loadOfflineHistory();

    final url = Uri.https(_baseUrl, "/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues", {
      "sessionId": _sessionId!,
      "minutes": minutes.toString(),
      "maxCount": maxCount.toString(),
    });

    try {
      final response = await http.post(url, headers: {"Content-Length": "0"});
      
      if (response.body.contains("SessionNotValid")) {
        bool refreshed = await initAndLogin();
        if (refreshed) {
          return getGlucoseHistory(minutes: minutes, maxCount: maxCount);
        }
        return await _loadOfflineHistory();
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          List<GlucoseReading> readings = decoded.map<GlucoseReading>((item) => GlucoseReading.fromJson(item)).toList();
          readings.sort((a, b) => b.time.compareTo(a.time));

          String serializedJson = jsonEncode(readings.map((r) => r.toJson()).toList());
          await _storage.write(key: "cached_glucose_history", value: serializedJson);

          return readings;
        }
      }
    } catch (e) {
      print("Błąd sieci, próba odczytu cache: $e");
    }

    return await _loadOfflineHistory();
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
      print("Błąd odczytu offline: $e");
    }
    return [];
  }

  // OBSŁUGA PROGÓW ZAPISANYCH W CACHE RAM / ZASZYFROWANYM DYSKU
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

  // NAPRAWA BŁĘDU: Dodano brakujący getter synchroniczny dla wykresów i widżetów
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