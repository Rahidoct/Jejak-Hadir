// lib/services/auth_service_local.dart
//
// Auth terhubung backend (Fase 0). Nama kelas, stream, dan signature method
// SENGAJA dipertahankan dari versi lokal lama agar pemanggil (auth_wrapper,
// auth_screen, profile_screen) tak perlu diubah. Yang berubah: sumber data —
// dari shared_preferences lokal menjadi endpoint mobile_auth (token Bearer).
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'package:jejak_hadir_app/services/api_service.dart';
import 'package:jejak_hadir_app/services/token_store.dart';
import 'package:jejak_hadir_app/helpers/notification_helper.dart';

class AuthServiceLocal {
  AuthServiceLocal._internal() {
    _bootstrap();
  }
  static final AuthServiceLocal instance = AuthServiceLocal._internal();

  final LocalStorageService _local = LocalStorageService();
  final ApiService _api = ApiService.instance;
  final TokenStore _tokens = TokenStore.instance;

  final StreamController<LocalUser?> _userStreamController = StreamController<LocalUser?>.broadcast();
  Stream<LocalUser?> get user => _userStreamController.stream;

  LocalUser? _current;
  LocalUser? get currentUser => _current;

  /// Petakan payload `user` dari server → LocalUser yang dipakai UI.
  /// uid memakai pegawai_id (kunci data absensi); bila akun belum tertaut
  /// pegawai, pakai prefiks user id agar tetap unik.
  LocalUser _mapUser(Map<String, dynamic> u) {
    final pegawaiId = u['pegawai_id'];
    final uid = pegawaiId != null ? 'p$pegawaiId' : 'u${u['id']}';
    return LocalUser(
      uid: uid,
      email: (u['email'] ?? u['username'] ?? '').toString(),
      name: (u['nama'] ?? u['username'] ?? '').toString(),
      nip: u['nip']?.toString(),
      position: u['jabatan']?.toString(),
      grade: u['golongan']?.toString(),
      registrationDate: DateTime.now(),
      // profilePicture (foto) sengaja tak diisi: app menampilkannya sebagai
      // base64, sedangkan backend menyajikan foto sebagai URL → ditangani terpisah nanti.
    );
  }

  void _emit(LocalUser? u) {
    _current = u;
    if (!_userStreamController.isClosed) {
      _userStreamController.add(u);
    }
  }

  /// Saat app dibuka: bila ada token tersimpan, validasi ke server (op=me).
  Future<void> _bootstrap() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      _emit(null);
      return;
    }
    try {
      final res = await _api.get('mobile_auth&op=me', auth: true);
      final u = _mapUser(res['user'] as Map<String, dynamic>);
      await _local.saveCurrentUser(u);
      _emit(u);
    } catch (_) {
      // Token tak valid / server tak terjangkau → paksa login ulang.
      await _tokens.clear();
      _emit(null);
    }
  }

  /// Login ke backend. Mengembalikan LocalUser bila sukses, null bila gagal.
  Future<LocalUser?> signInWithEmailAndPassword(String login, String password, BuildContext context) async {
    try {
      final res = await _api.postForm('mobile_auth&op=login', {
        'username': login.trim(),
        'password': password,
        'device_label': 'Aplikasi Jejak Hadir',
      });

      await _tokens.save(res['token'].toString());
      final userJson = res['user'] as Map<String, dynamic>;
      final u = _mapUser(userJson);
      await _local.saveCurrentUser(u);
      _emit(u);

      if (context.mounted) {
        NotificationHelper.show(
          context,
          title: 'Login Berhasil',
          message: 'Selamat datang ${u.name}',
          type: NotificationType.success,
        );
      }
      // Akun tanpa data pegawai tak bisa memakai fitur absensi — beri tahu.
      if (userJson['tertaut_pegawai'] != true && context.mounted) {
        NotificationHelper.show(
          context,
          title: 'Perhatian',
          message: 'Akun ini belum tertaut data pegawai. Hubungi Kepegawaian.',
          type: NotificationType.info,
        );
      }
      return u;
    } on ApiException catch (e) {
      if (context.mounted) {
        NotificationHelper.show(context, title: 'Login Gagal', message: e.message, type: NotificationType.error);
      }
      return null;
    }
  }

  /// Registrasi mandiri TIDAK tersedia — akun pegawai dibuat oleh admin
  /// Kepegawaian di sistem web. Dipertahankan agar pemanggil lama tetap kompilasi.
  Future<LocalUser?> registerWithEmailAndPassword(String email, String password, String name) async {
    return null;
  }

  /// Ganti password belum didukung dari mobile (endpoint backend menyusul).
  /// Dipertahankan agar profile_screen tetap kompilasi.
  Future<bool> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    return false;
  }

  Future<void> signOut(BuildContext context) async {
    // Cabut token di server (best-effort — jangan blokir logout bila gagal).
    try {
      await _api.postForm('mobile_auth&op=logout', {}, auth: true);
    } catch (_) {}
    await _tokens.clear();
    await _local.clearCurrentUser();
    _emit(null);

    if (context.mounted) {
      NotificationHelper.show(
        context,
        title: 'Logout Berhasil',
        message: 'Sampai jumpa lagi.',
        type: NotificationType.info,
      );
    }
  }

  void dispose() {
    _userStreamController.close();
  }
}
