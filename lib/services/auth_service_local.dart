// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jejak_hadir_app/helpers/notification_helper.dart';

class AuthServiceLocal {
  AuthServiceLocal._internal() {
    _initUserStream();
  }
  static final AuthServiceLocal instance = AuthServiceLocal._internal();

  final LocalStorageService _localStorageService = LocalStorageService();
  final StreamController<LocalUser?> _userStreamController = StreamController<LocalUser?>.broadcast();
  Stream<LocalUser?> get user => _userStreamController.stream;
  
  static const String _userPasswordsKey = 'user_passwords_map';

  Future<void> _initUserStream() async {
    final currentUser = await _localStorageService.getCurrentUser();
    if (!_userStreamController.isClosed) {
      _userStreamController.add(currentUser);
    }
  }

  Future<LocalUser?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allUsers = await _localStorageService.getRegisteredUsers();
      if (allUsers.any((user) => user.email == email)) {
        print("Registrasi Gagal: Email sudah terdaftar.");
        return null;
      }
      
      final passwordsString = prefs.getString(_userPasswordsKey) ?? '{}';
      final passwordsMap = jsonDecode(passwordsString) as Map<String, dynamic>;
      passwordsMap[email] = password;
      await prefs.setString(_userPasswordsKey, jsonEncode(passwordsMap));
      
      final newUser = LocalUser(
        uid: email, email: email, name: name,
        nip: '199110032023211001', position: 'DOKTER AHLI PERTAMA', grade: 'X',
        registrationDate: DateTime.now(),
      );
      await _localStorageService.saveRegisteredUser(newUser);
      
      return newUser;
    } catch (e) {
      print("Error saat registrasi: $e");
      return null;
    }
  }

  Future<LocalUser?> signInWithEmailAndPassword(String email, String password, BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allUsers = await _localStorageService.getRegisteredUsers();

      // 1. Cek apakah email terdaftar
      final userExists = allUsers.any((user) => user.email == email);
      if (!userExists) {
        print("Login Gagal: Email tidak terdaftar");
        NotificationHelper.show(
          // ignore: use_build_context_synchronously
          context,
          title: "Penyebabnya Disini",
          message: "Login gagal disebabkan email yang kamu ketik salah / tidak terdaftar",
          type: NotificationType.info,
        );
        return null;
      }

      // 2. Cek password
      final passwordsString = prefs.getString(_userPasswordsKey) ?? '{}';
      final passwordsMap = jsonDecode(passwordsString) as Map<String, dynamic>;
      if (passwordsMap[email] != password) {
        print("Login Gagal: Password salah");
        NotificationHelper.show(
          // ignore: use_build_context_synchronously
          context,
          title: "Penyebabnya Disini",
          message: "Login gagal disebabkan password yang kamu ketik salah",
          type: NotificationType.info,
        );
        return null;
      }

      // 3. Jika semua valid, lanjutkan login
      final userToLogin = allUsers.firstWhere((user) => user.email == email);
      await _localStorageService.saveCurrentUser(userToLogin);
      _userStreamController.add(userToLogin);
      
      NotificationHelper.show(
        // ignore: use_build_context_synchronously
        context,
        title: "Login Berhasil",
        message: "Selamat datang ${userToLogin.name}",
        type: NotificationType.success,
      );
      
      return userToLogin;

    } catch (e) {
      print("Error saat login: $e");
      NotificationHelper.show(
        // ignore: use_build_context_synchronously
        context,
        title: "Error Sistem",
        message: "Terjadi kesalahan saat login. Silakan coba lagi.",
        type: NotificationType.error,
      );
      return null;
    }
  }
  
  Future<bool> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordsString = prefs.getString(_userPasswordsKey) ?? '{}';
      final passwordsMap = jsonDecode(passwordsString) as Map<String, dynamic>;

      if (passwordsMap[email] != oldPassword) {
        print("Ubah Password Gagal: Password lama salah.");
        return false;
      }

      passwordsMap[email] = newPassword;
      await prefs.setString(_userPasswordsKey, jsonEncode(passwordsMap));
      print("Password berhasil diubah untuk $email");
      return true;

    } catch (e) {
      print("Error saat ubah password: $e");
      return false;
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await _localStorageService.clearCurrentUser();
      _userStreamController.add(null);
      
      // Tambahkan notifikasi logout berhasil
      NotificationHelper.show(
        // ignore: use_build_context_synchronously
        context,
        title: "Logout Berhasil",
        message: "Jangan lupa login lagi yah..",
        type: NotificationType.info,
      );
    } catch (e) {
      print("Error saat sign out: $e");
      NotificationHelper.show(
        // ignore: use_build_context_synchronously
        context,
        title: "Logout Gagal",
        message: "Gagal melakukan logout, Cek koneksi internet kamu.",
        type: NotificationType.error,
      );
    }
  }

  void dispose() {
    _userStreamController.close();
  }
}