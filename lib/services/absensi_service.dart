// lib/services/absensi_service.dart
//
// Pembungkus endpoint absensi (index.php?absensi_action&op=...).
// Semua keputusan (wajah cocok / dalam radius / dalam jendela waktu) diambil
// SERVER — aplikasi hanya mengirim bukti: descriptor, lokasi, perangkat, foto.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';
import 'face_embedder.dart';

/// Token perangkat: identitas HP ini, dibuat sekali lalu dipakai selamanya.
/// Admin harus menyetujui perangkat sebelum absen dianggap sah otomatis.
class DeviceId {
  static const _key = 'pkm_device_token';
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var t = prefs.getString(_key);
    if (t == null || t.isEmpty) {
      t = const Uuid().v4();
      await prefs.setString(_key, t);
    }
    _cached = t;
    return t;
  }
}

class AbsensiService {
  AbsensiService._();
  static final AbsensiService instance = AbsensiService._();

  final ApiService _api = ApiService.instance;

  /// Status hari ini: sudah masuk/pulang, jendela waktu, konfigurasi lokasi,
  /// status perangkat, dan apakah wajah sudah terdaftar untuk model mobile.
  Future<Map<String, dynamic>> status() async {
    final token = await DeviceId.get();
    return _api.get(
      'absensi_action&op=status&model=${FaceEmbedder.modelVersion}&device_token=$token',
    );
  }

  /// Daftarkan perangkat ini (status awal biasanya 'pending' menunggu admin).
  Future<Map<String, dynamic>> registerDevice(String deviceName) async {
    final token = await DeviceId.get();
    return _api.postForm(
      'absensi_action&op=register_device',
      {'device_token': token, 'device_name': deviceName},
      auth: true,
    );
  }

  /// Kirim absen. Server menentukan masuk/pulang secara otomatis,
  /// mencocokkan wajah, memeriksa radius & jendela waktu.
  Future<Map<String, dynamic>> absen({
    required List<double> descriptor,
    required double lat,
    required double lng,
    required String fotoPath,
  }) async {
    final token = await DeviceId.get();
    return _api.postMultipart(
      'absensi_action&op=absen&model=${FaceEmbedder.modelVersion}',
      {
        'descriptor': jsonEncode(descriptor),
        'lat': lat.toString(),
        'lng': lng.toString(),
        'device_token': token,
      },
      filePath: fotoPath,
      fileField: 'foto',
      auth: true,
    );
  }
}
