import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_calling/core/constrants/app_constrants.dart';



class VideoRoomService {
  Future<int> getMyRoomId() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/video-rooms/rooms/my-rooms/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (data is List && data.isNotEmpty) {
        return data.first['id'];
      } else {
        throw Exception('No video room found');
      }
    } else {
      throw Exception(
        data['detail']?.toString() ?? 'Failed to load video rooms',
      );
    }
  }

  Future<Map<String, dynamic>> getAgoraToken(int roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/video-rooms/rooms/$roomId/token/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(
        data['detail']?.toString() ?? 'Failed to get video call token',
      );
    }
  }
}