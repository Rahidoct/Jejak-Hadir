import 'dart:async';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';

class AuthServiceLocal {
  // Private constructor
  AuthServiceLocal._internal() {
    _initUserStream();
  }

  // Satu-satunya instance publik yang bisa diakses
  static final AuthServiceLocal instance = AuthServiceLocal._internal();

  final LocalStorageService _localStorageService = LocalStorageService();
  final StreamController<LocalUser?> _userStreamController = StreamController<LocalUser?>.broadcast();

  Stream<LocalUser?> get user => _userStreamController.stream;

  Future<void> _initUserStream() async {
    final currentUser = await _localStorageService.getCurrentUser();
    if (!_userStreamController.isClosed) {
      _userStreamController.add(currentUser);
    }
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
      return null;
    }
  }

  Future<LocalUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final storedUser = await _localStorageService.getCurrentUser();
      if (storedUser != null && storedUser.email == email) {
        if (password == 'password123') {
          _userStreamController.add(storedUser);
          return storedUser;
        } else {
          return null;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _localStorageService.clearCurrentUser();
      _userStreamController.add(null);
    // ignore: empty_catches
    } catch (e) {
    }
  }
  
  // dispose() tidak lagi dipanggil dari widget karena service ini hidup terus
}