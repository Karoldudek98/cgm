import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/glucose_reading.dart';
import 'settings_service.dart';

class DexcomService {
  static final DexcomService _instance = DexcomService._internal();
  factory DexcomService() => _instance;
  DexcomService._internal();

  final _storage = const FlutterSecureStorage();
  static const String _baseUrl = "shareous1.dexcom.com";
  static const String _appId = "d89443d2-327c-4a6f-89e5-496bbb0317db";
  
  String? _sessionId;

  String? _username;

  bool _isFetching = false; 
  
  String get currentUsername => _username ?? "default";

  String get _historyKey => "${currentUsername}_cached_glucose_history";

  Future<bool> initAndLogin() async {
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
        body: jsonEncode({"accountName": username.trim(), "password": password, "applicationId": _appId}),
      ).timeout(const Duration(seconds: 15)); 

      if (authResponse.statusCode != 200) return "Błąd autoryzacji (500)";
      
      final accountId = authResponse.body.trim().replaceAll('"', '');
      if (accountId == "00000000-0000-0000-0000-000000000000") return "Błędne dane.";

      final loginResponse = await http.post(
        Uri.https(_baseUrl, "/ShareWebServices/Services/General/LoginPublisherAccountById"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"accountId": accountId, "password": password, "applicationId": _appId}),
      ).timeout(const Duration(seconds: 15));

      if (loginResponse.statusCode == 200) {
        final token = loginResponse.body.trim().replaceAll('"', '');
        if (token != "00000000-0000-0000-0000-000000000000") {
          _sessionId = token;
          _username = username.trim();
          await _storage.write(key: "dex_user", value: _username!);
          await _storage.write(key: "dex_pass", value: password);
          await SettingsService().loadForUser(_username!);
          
          return "SUCCESS";
        }
      }
      return "Błąd generowania sesji.";
    } on TimeoutException {
      return "Błąd: Przekroczono czas oczekiwania na logowanie.";
    } catch (e) {
      return "Błąd połączenia: $e";
    }
  }

  Future<List<GlucoseReading>> getGlucoseHistory({int retryCount = 0}) async {
    if (_isFetching) {
      print("Zablokowano równoczesne pobieranie danych (race condition).");
      return _loadOfflineHistory(); 
    }

    _isFetching = true;

    try {
      List<GlucoseReading> localHistory = await _loadOfflineHistory();
      if (_sessionId == null) return localHistory;

      final url = Uri.https(_baseUrl, "/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues", {
        "sessionId": _sessionId!, "minutes": "1440", "maxCount": "288",
      });

      final response = await http.post(url, headers: {"Content-Length": "0"}).timeout(const Duration(seconds: 15));
      
      if (response.body.contains("SessionNotValid")) {
        if (retryCount >= 1) {
          print("Przerwano zapętlenie odświeżania sesji.");
          return localHistory; 
        }

        bool refreshed = await initAndLogin();
        if (refreshed) {
          return await getGlucoseHistory(retryCount: retryCount + 1); 
        }
        return localHistory;
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          List<GlucoseReading> apiReadings = decoded.map<GlucoseReading>((item) => GlucoseReading.fromJson(item)).toList();
          final Map<int, GlucoseReading> mergedMap = {};
          
          for (var r in localHistory) mergedMap[r.time.millisecondsSinceEpoch] = r;
          for (var r in apiReadings) mergedMap[r.time.millisecondsSinceEpoch] = r;

          List<GlucoseReading> mergedList = mergedMap.values.toList();
          mergedList.sort((a, b) => b.time.compareTo(a.time));

          const int maxRecords = 8640;
          if (mergedList.length > maxRecords) mergedList = mergedList.sublist(0, maxRecords);

          String serializedJson = jsonEncode(mergedList.map((r) => r.toJson()).toList());
          await _storage.write(key: _historyKey, value: serializedJson);

          return mergedList;
        }
      }
      return localHistory;
    } on TimeoutException {
      print("Błąd: Serwer Dexcom nie odpowiedział w czasie 15s.");
      return _loadOfflineHistory();
    } catch (e) {
      print("Błąd pobierania danych sieciowych: $e");
      return _loadOfflineHistory();
    } finally {
      _isFetching = false;
    }
  }

  Future<List<GlucoseReading>> _loadOfflineHistory() async {
    try {
      String? cachedData = await _storage.read(key: _historyKey);
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

  Future<void> logout() async {
    _sessionId = null;
    _username = null; 
    await _storage.delete(key: "dex_user");
    await _storage.delete(key: "dex_pass");
  }

  String? get sessionId => _sessionId;
}