import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DexcomService {
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
      final authResponse = await http.post(
        Uri.https(_baseUrl, "/ShareWebServices/Services/General/AuthenticatePublisherAccount"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({
          "accountName": username.trim(),
          "password": password,
          "applicationId": _appId,
        }),
      );

      if (authResponse.statusCode == 200) {
        final accountId = authResponse.body.replaceAll('"', '');
        if (accountId == "00000000-0000-0000-0000-000000000000") return "Błąd danych.";

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
            
            // ZAPIS DANYCH PO SUKCESIE
            await _storage.write(key: "dex_user", value: username.trim());
            await _storage.write(key: "dex_pass", value: password);
            
            return "SUCCESS";
          }
        }
      }
      return "Błąd logowania.";
    } catch (e) {
      return "Błąd połączenia.";
    }
  }

  Future<void> logout() async {
    _sessionId = null;
    await _storage.deleteAll();
  }

  String? get sessionId => _sessionId;
  bool get isLoggedIn => _sessionId != null;
}