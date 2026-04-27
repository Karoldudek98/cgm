import 'dart:convert';
import 'package:http/http.dart' as http;

class DexcomService {
  static const String _baseUrl = "shareous1.dexcom.com";
  
  // To ID zadziałało w Twoich testach - zostawiamy je jako stałą
  static const String _appId = "d89443d2-327c-4a6f-89e5-496bbb0317db";
  
  String? _sessionId;

  /// Logowanie dwuetapowe (Authenticate -> Login)
  Future<String> login(String username, String password) async {
    try {
      // KROK 1: Pobranie Account ID
      final authResponse = await http.post(
        Uri.https(_baseUrl, "/ShareWebServices/Services/General/AuthenticatePublisherAccount"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({
          "accountName": username.trim(),
          "password": password,
          "applicationId": _appId,
        }),
      );

      if (authResponse.statusCode != 200) {
        return "Błąd serwera (Krok 1): ${authResponse.statusCode}";
      }

      final accountId = authResponse.body.replaceAll('"', '');
      if (accountId == "00000000-0000-0000-0000-000000000000") {
        return "Niepoprawny login lub hasło.";
      }

      // KROK 2: Pobranie Session ID
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
          return "SUCCESS";
        }
      }
      
      return "Błąd podczas generowania sesji.";
    } catch (e) {
      return "Błąd połączenia: $e";
    }
  }

  String? get sessionId => _sessionId;
  bool get isLoggedIn => _sessionId != null;
}