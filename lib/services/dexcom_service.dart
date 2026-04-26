import 'dart:convert';
import 'package:http/http.dart' as http;

class DexcomService {
  // Adresy serwerów Dexcom (OUS = Outside US, czyli np. Polska)
  static const String serverOUS = "shareous1.dexcom.com";
  static const String serverUS = "share1.dexcom.com";

  String? _sessionId;

  // Funkcja logowania
  Future<bool> login(String username, String password) async {
    final url = Uri.https(serverOUS, "/ShareWebServices/Services/General/LoginPublisherAccountByName");
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "accountName": username,
          "password": password,
          "applicationId": "d89443d2-327c-4a6f-89e5-ada9f8730b61", // Stałe ID Dexcom
        }),
      );

      if (response.statusCode == 200) {
        // ID sesji przychodzi w cudzysłowie, np. "uuid-string"
        _sessionId = response.body.replaceAll('"', '');
        print("Zalogowano! ID Sesji: $_sessionId");
        return true;
      }
    } catch (e) {
      print("Błąd logowania: $e");
    }
    return false;
  }
}