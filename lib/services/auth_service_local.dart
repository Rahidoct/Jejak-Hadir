import 'dart:async';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';

class AuthServiceLocal {
  final LocalStorageService _localStorageService = LocalStorageService();
  final StreamController<LocalUser?> _userStreamController = StreamController<LocalUser?>.broadcast();

  AuthServiceLocal() {
    _initUserStream();
  }

  Stream<LocalUser?> get user => _userStreamController.stream;

  Future<void> _initUserStream() async {
    final currentUser = await _localStorageService.getCurrentUser();
    _userStreamController.add(currentUser);
  }

  Future<LocalUser?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      final newUser = LocalUser(
        uid: email, 
        email: email, 
        name: name,
        nip: '199110032023211001',
        position: 'DOKTER AHLI PERTAMA',
        grade: 'X',
      );
      await _localStorageService.saveCurrentUser(newUser);
      _userStreamController.add(newUser);
      return newUser;
    } catch (e) {
      // ignore: avoid_print
      print('Error during registration: $e');
      return null;
    }
  }

  Future<LocalUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final storedUser = await _localStorageService.getCurrentUser();
      
      if (storedUser != null && storedUser.email == email) {
        if (password == 'password123') { // Password default
          _userStreamController.add(storedUser);
          return storedUser;
        } else {
          // ignore: avoid_print
          print('Password salah');
          return null;
        }
      }
      // ignore: avoid_print
      print('User tidak ditemukan');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error during login: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _localStorageService.clearCurrentUser();
      _userStreamController.add(null);
    } catch (e) {
      // ignore: avoid_print
      print('Error during sign out: $e');
    }
  }

  void dispose() {
    _userStreamController.close();
  }
}