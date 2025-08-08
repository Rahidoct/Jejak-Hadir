// lib/services/local_storage_service.dart

import 'dart:convert';
import 'package:jejak_hadir_app/models/leave_request_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_local.dart';
import '../models/attendance_local.dart';

class LocalStorageService {
  static const String _currentUserKey = 'current_user';
  static const String _attendancesKey = 'attendances';
  static const String _registeredUsersKey = 'registered_users';
  static const String _leaveRequestsKey = 'leave_requests';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();
  
  // --- USER METHODS ---
  
  Future<List<LocalUser>> getRegisteredUsers() async {
    final prefs = await _prefs;
    await prefs.reload();
    final usersString = prefs.getString(_registeredUsersKey) ?? '[]';
    final List<dynamic> usersJson = jsonDecode(usersString);
    return usersJson.map((json) => LocalUser.fromMap(json)).toList();
  }

  Future<void> saveRegisteredUser(LocalUser user) async {
    final prefs = await _prefs;
    final users = await getRegisteredUsers();
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
      await prefs.reload();
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

  // CHANGED: This function now saves a String? (face data) or null (to delete)
  Future<void> updateUserFaceData(String userId, String? faceData) async {
    final prefs = await _prefs;
    final users = await getRegisteredUsers();
    
    final userIndex = users.indexWhere((user) => user.uid == userId);
    if (userIndex != -1) {
      // Use copyWith to update the faceData field.
      // Passing null to faceData will correctly set it to null.
      final updatedUser = users[userIndex].copyWith(faceData: faceData);
      users[userIndex] = updatedUser;
      
      await prefs.setString(_registeredUsersKey, jsonEncode(users.map((u) => u.toMap()).toList()));
      
      final currentUser = await getCurrentUser();
      if (currentUser?.uid == userId) {
        await saveCurrentUser(updatedUser);
      }
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
    await prefs.reload();
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
  
  // --- LEAVE REQUEST METHODS ---

  Future<void> addLeaveRequest(LeaveRequest request) async {
    final prefs = await _prefs;
    final requests = await getLeaveRequests();
    requests.add(request);
    await prefs.setStringList(
      _leaveRequestsKey,
      requests.map((r) => jsonEncode(r.toMap())).toList(),
    );
  }

  Future<List<LeaveRequest>> getLeaveRequests() async {
    final prefs = await _prefs;
    await prefs.reload();
    final requestsJson = prefs.getStringList(_leaveRequestsKey) ?? [];
    return requestsJson.map((json) => LeaveRequest.fromMap(jsonDecode(json))).toList();
  }
  
  Future<List<LeaveRequest>> getLeaveRequestsByUserId(String userId) async {
    final allRequests = await getLeaveRequests();
    return allRequests
        .where((request) => request.userId == userId)
        .toList()
        ..sort((a, b) => b.submittedDate.compareTo(a.submittedDate));
  }
  
  Future<List<LeaveRequest>> getApprovedLeaveRequestsByUserId(String userId) async {
    final allRequests = await getLeaveRequestsByUserId(userId);
    return allRequests.where((req) => req.status == 'Disetujui').toList();
  }
}