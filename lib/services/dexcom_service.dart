import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- MODEL DANYCH ---
class GlucoseReading {
  final int value;
  final String direction;
  final DateTime time;

  GlucoseReading({required this.value, required this.direction, required this.time});

  factory GlucoseReading.fromJson(Map<String, dynamic> json) {
    // ST to czas systemowy w formacie "/Date(1234567890)/"
    String rawDate = json['ST'];
    int timestamp = int.parse(rawDate.replaceAll(RegExp(r'[^0-9]'), ''));
    
    return GlucoseReading(
      value: json['Value'],
      direction: json['Trend'],
      time: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}

class DexcomService {
  // Singleton
  static final DexcomService _instance = DexcomService._internal();
  factory DexcomService() => _instance;
  DexcomService._internal();

  final _storage = const FlutterSecureStorage();
  static const String _baseUrl = "shareous1.dexcom.com";
  static const String _appId = "d89443d2-327c-4a6f-89e5-496bbb0317db";
  
  String? _sessionId;

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
      // KROK 1: Authenticate
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
      
      final accountId = authResponse.body.replaceAll('"', '');
      if (accountId == "00000000-0000-0000-0000-000000000000") return "Błędne dane.";

      // KROK 2: Login By ID
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
        final token = loginResponse.body.replaceAll('"', '');
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

  Future<GlucoseReading?> getLatestReading() async {
    if (_sessionId == null) return null;

    final url = Uri.https(_baseUrl, "/ShareWebServices/Services/Publisher/ReadPublisherLatestGlucoseValues", {
      "sessionId": _sessionId,
      "minutes": "1440",
      "maxCount": "1",
    });

    try {
      final response = await http.post(url, headers: {"Content-Length": "0"});
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return GlucoseReading.fromJson(data.first);
        }
      } else if (response.statusCode == 500 || response.body.contains("SessionNotValid")) {
        // Próba odświeżenia sesji przy błędzie
        await initAndLogin();
      }
    } catch (e) {
      print("Błąd pobierania: $e");
    }
    return null;
  }

  Future<void> logout() async {
    _sessionId = null;
    await _storage.deleteAll();
  }

  String? get sessionId => _sessionId;
}