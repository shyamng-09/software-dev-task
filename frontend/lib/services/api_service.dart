import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiService {
  static const String baseUrl = AppConfig.serverUrl;

  static Future<Map<String, dynamic>> createRoom(String name) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/rooms/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'message': 'Request failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> joinRoom(String pin) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/rooms/join'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pin': pin}),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'message': 'Request failed: $e'};
    }
  }
}
