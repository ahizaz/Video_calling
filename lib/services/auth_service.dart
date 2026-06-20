import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_calling/core/constrants/app_constrants.dart';



class AuthService {
  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('access_token', data['access'] ?? '');
      await prefs.setString('refresh_token', data['refresh'] ?? '');
      await prefs.setString('user_name', data['user']?['name'] ?? '');
    } else {
      throw Exception(
        data['detail']?.toString() ??
            data['non_field_errors']?.toString() ??
            'Login failed',
      );
    }
  }
}