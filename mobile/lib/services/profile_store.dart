import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room.dart';

class ProfileStore {
  static const _userIdKey = 'profile.userId';
  static const _nameKey = 'profile.displayName';
  static const _historyKey = 'rooms.history';

  Future<String> userId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_userIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final value = 'u_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    await prefs.setString(_userIdKey, value);
    return value;
  }

  Future<String> displayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey) ?? 'Guest';
  }

  Future<void> setDisplayName(String name) async {
    final clean = name.trim().isEmpty ? 'Guest' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, clean);
  }

  Future<List<Map<String, dynamic>>> history() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> rememberRoom(
    Room room, {
    required bool createdByMe,
    String? localSource,
  }) async {
    final items = await history();
    items.removeWhere((e) => e['code'] == room.code);
    items.insert(0, {
      'id': room.id,
      'code': room.code,
      'name': room.name,
      'hostUserId': room.hostUserId,
      'hostName': room.hostName,
      'sourceType': room.sourceType.wire,
      'sourceValue': room.sourceValue,
      'createdByMe': createdByMe,
      'localSource': createdByMe ? localSource : null,
      'lastOpenedAt': DateTime.now().toIso8601String(),
    });
    if (items.length > 20) items.removeRange(20, items.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(items));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
