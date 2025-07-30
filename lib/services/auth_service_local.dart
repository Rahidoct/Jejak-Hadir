import 'dart:async';
import 'dart:convert';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthServiceLocal {
  AuthServiceLocal._internal() {
    _initUserStream();
  }
  static final AuthServiceLocal instance = AuthServiceLocal._internal();

  final LocalStorageService _localStorageService = LocalStorageService();
  final StreamController<LocalUser?> _userStreamController = StreamController<LocalUser?>.broadcast();
  Stream<LocalUser?> get user => _userStreamController.stream;
  
  // --- [BARU] Kunci untuk menyimpan Map password ---
  static const String _userPasswordsKey = 'user_passwords_map';

  Future<void> _initUserStream() async {
    final currentUser = await _localStorageService.getCurrentUser();
    if (!_userStreamController.isClosed) {
      _userStreamController.add(currentUser);
    }
  }

  // --- [PERBAIKAN LOGIKA DAFTAR] ---
  Future<LocalUser?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allUsers = await _localStorageService.getRegisteredUsers();
      if (allUsers.any((user) => user.email == email)) {
        // ignore: avoid_print
        print("Registrasi Gagal: Email sudah terdaftar.");
        return null;
      }
      
      // 1. Simpan password pengguna ke dalam Map
      final passwordsString = prefs.getString(_userPasswordsKey) ?? '{}';
      final passwordsMap = jsonDecode(passwordsString) as Map<String, dynamic>;
      passwordsMap[email] = password; // Simpan password baru
      await prefs.setString(_userPasswordsKey, jsonEncode(passwordsMap));
      
      // 2. Buat & Simpan data pengguna
      final newUser = LocalUser(
        uid: email, email: email, name: name,
        nip: '199110032023211001', position: 'DOKTER AHLI PERTAMA', grade: 'X',
      );
      await _localStorageService.saveRegisteredUser(newUser);
      
      return newUser;
    } catch (e) {
      // ignore: avoid_print
      print("Error saat registrasi: $e");
      return null;
    }
  }

  // --- [PERBAIKAN LOGIKA LOGIN] ---
  Future<LocalUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allUsers = await _localStorageService.getRegisteredUsers();

      // 1. Cek apakah password cocok
      final passwordsString = prefs.getString(_userPasswordsKey) ?? '{}';
      final passwordsMap = jsonDecode(passwordsString) as Map<String, dynamic>;
      if (passwordsMap[email] != password) {
        // ignore: avoid_print
        print("Login Gagal: Password salah.");
        return null; // Password tidak cocok atau email tidak ada di map password
      }

      // 2. Jika password cocok, ambil data user
      LocalUser? userToLogin;
      try {
        userToLogin = allUsers.firstWhere((user) => user.email == email);
      } catch (e) {
        userToLogin = null;
      }
      
      if (userToLogin == null) {
        // ignore: avoid_print
        print("Login Gagal: User data tidak ditemukan (konsistensi error).");
        return null;
      }

      // 3. Login berhasil
      await _localStorageService.saveCurrentUser(userToLogin);
      _userStreamController.add(userToLogin);
      return userToLogin;

    } catch (e) {
      // ignore: avoid_print
      print("Error saat login: $e");
      return null;
    }
  }
  
  // --- [BARU] Fungsi Ubah Password yang sesungguhnya ---
  Future<bool> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordsString = prefs.getString(_userPasswordsKey) ?? '{}';
      final passwordsMap = jsonDecode(passwordsString) as Map<String, dynamic>;

      // Verifikasi password lama
      if (passwordsMap[email] != oldPassword) {
        // ignore: avoid_print
        print("Ubah Password Gagal: Password lama salah.");
        return false;
      }

      // Simpan password baru
      passwordsMap[email] = newPassword;
      await prefs.setString(_userPasswordsKey, jsonEncode(passwordsMap));
      // ignore: avoid_print
      print("Password berhasil diubah untuk $email");
      return true;

    } catch (e) {
      // ignore: avoid_print
      print("Error saat ubah password: $e");
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      // clearCurrentUser sekarang menjadi AMAN untuk dipanggil
      await _localStorageService.clearCurrentUser();
      _userStreamController.add(null);
    } catch (e) {
      // ignore: avoid_print
      print("Error saat sign out: $e");
    }
  }
}