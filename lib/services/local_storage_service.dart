import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_local.dart';
import '../models/attendance_local.dart';

class LocalStorageService {
  static const String _currentUserKey = 'current_user';
  static const String _attendancesKey = 'attendances';
  static const String _registeredUsersKey = 'registered_users'; // Gunakan satu nama kunci yang konsisten

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();
  
  // --- USER METHODS ---
  
  Future<List<LocalUser>> getRegisteredUsers() async {
    final prefs = await _prefs;
    final usersString = prefs.getString(_registeredUsersKey) ?? '[]';
    final List<dynamic> usersJson = jsonDecode(usersString);
    // Pastikan menggunakan fromMap
    return usersJson.map((json) => LocalUser.fromMap(json)).toList();
  }

  Future<void> saveRegisteredUser(LocalUser user) async {
    final prefs = await _prefs;
    final users = await getRegisteredUsers();
    // Tambahkan hanya jika email belum ada
    if (!users.any((u) => u.email == user.email)) {
      users.add(user);
      await prefs.setString(_registeredUsersKey, jsonEncode(users.map((u) => u.toMap()).toList()));
    }
  }
  
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
  
  // --- ATTENDANCE METHODS ---
  
  Future<void> addAttendance(LocalAttendance attendance) async {
    final prefs = await _prefs;
    final attendances = await getAttendances();
    attendances.add(attendance);
    await prefs.setStringList(
      _attendancesKey,
      attendances.map((a) => jsonEncode(a.toMap())).toList(),
    );
  }

  Future<List<LocalAttendance>> getAttendances() async {
    final prefs = await _prefs;
    final attendancesJson = prefs.getStringList(_attendancesKey) ?? [];
    return attendancesJson.map((json) => LocalAttendance.fromMap(jsonDecode(json))).toList();
  }

  Future<List<LocalAttendance>> getAttendancesByUserId(String userId) async {
    final allAttendances = await getAttendances();
    return allAttendances
        .where((attendance) => attendance.userId == userId)
        .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  Future<void> clearAllAttendances() async {
    final prefs = await _prefs;
    await prefs.remove(_attendancesKey);
  }
}