import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'SYNCROOM_API_BASE',
    defaultValue: 'http://10.0.2.2:8787',
  );

  Future<Room> createRoom({
    required String name,
    required String hostName,
    required String hostUserId,
    required MediaSourceType sourceType,
    String? sourceValue,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/rooms'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'hostName': hostName,
        'hostUserId': hostUserId,
        'sourceType': sourceType.wire,
        'sourceValue': sourceValue,
      }),
    );
    if (response.statusCode >= 300) {
      throw Exception('Room yaratilmadi: ${response.body}');
    }
    return Room.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Room> getRoom(String code) async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/rooms/${code.trim().toUpperCase()}'));
    if (response.statusCode == 404) throw Exception('Room topilmadi');
    if (response.statusCode >= 300) throw Exception('Room ochilmadi');
    return Room.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
