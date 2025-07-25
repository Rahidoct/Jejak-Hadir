import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_local.dart';
import '../models/attendance_local.dart';

class LocalStorageService {
  static const String _currentUserKey = 'current_user';
  static const String _attendancesKey = 'attendances';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<void> saveCurrentUser(LocalUser user) async {
    final prefs = await _prefs;
    await prefs.setString(_currentUserKey, jsonEncode(user.toMap()));
  }

  Future<LocalUser?> getCurrentUser() async {
    try {
      final prefs = await _prefs;
      final userData = prefs.getString(_currentUserKey);
      if (userData != null) {
        return LocalUser.fromMap(jsonDecode(userData));
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error getting user: $e');
      return null;
    }
  }

  Future<void> clearCurrentUser() async {
    final prefs = await _prefs;
    await prefs.remove(_currentUserKey);
  }

  Future<void> addAttendance(LocalAttendance attendance) async {
    try {
      final prefs = await _prefs;
      final attendances = await getAttendances();
      attendances.add(attendance);
      await prefs.setStringList(
        _attendancesKey,
        attendances.map((a) => jsonEncode(a.toMap())).toList(),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error adding attendance: $e');
    }
  }

  Future<List<LocalAttendance>> getAttendances() async {
    try {
      final prefs = await _prefs;
      final attendancesJson = prefs.getStringList(_attendancesKey) ?? [];
      return attendancesJson.map((json) => LocalAttendance.fromMap(jsonDecode(json))).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error getting attendances: $e');
      return [];
    }
  }

  Future<List<LocalAttendance>> getAttendancesByUserId(String userId) async {
    try {
      final allAttendances = await getAttendances();
      return allAttendances
          .where((attendance) => attendance.userId == userId)
          .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      // ignore: avoid_print
      print('Error getting attendances by user: $e');
      return [];
    }
  }

  Future<void> clearAllAttendances() async {
    final prefs = await _prefs;
    await prefs.remove(_attendancesKey);
  }
}