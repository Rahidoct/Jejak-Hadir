// lib/services/api_service.dart
//
// Klien HTTP tingkat rendah untuk backend Puskesmas Bunder. Menangani:
//  - lampiran token Bearer pada request ber-auth,
//  - decode JSON + konvensi { ok: bool, error: string } dari server,
//  - normalisasi error (termasuk 401 = sesi berakhir) jadi ApiException.
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_store.dart';

/// Error terstruktur dari lapisan API. [status] = kode HTTP bila ada;
/// [status] == 401 menandai token tidak valid / sesi berakhir.
class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  bool get isUnauthorized => status == 401;
  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final TokenStore _tokens = TokenStore.instance;
  static const Duration _timeout = Duration(seconds: 20);

  Future<Map<String, String>> _authHeader() async {
    final token = await _tokens.read();
    return (token != null && token.isNotEmpty) ? {'Authorization': 'Bearer $token'} : {};
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw ApiException('Respons server tidak valid (HTTP ${res.statusCode}).', res.statusCode);
    }
    if (res.statusCode == 401) {
      throw ApiException(body['error']?.toString() ?? 'Sesi berakhir. Silakan login ulang.', 401);
    }
    if (body['ok'] != true) {
      throw ApiException(body['error']?.toString() ?? 'Terjadi kesalahan (HTTP ${res.statusCode}).', res.statusCode);
    }
    return body;
  }

  /// POST form-urlencoded. Set [auth] true untuk melampirkan token.
  Future<Map<String, dynamic>> postForm(
    String query,
    Map<String, String> fields, {
    bool auth = false,
  }) async {
    try {
      final headers = auth ? await _authHeader() : <String, String>{};
      final res = await http.post(ApiConfig.uri(query), headers: headers, body: fields).timeout(_timeout);
      return _decode(res);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Server tidak merespons (timeout). Cek koneksi & alamat server.');
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Cek koneksi & alamat server.');
    }
  }

  /// POST multipart — dipakai saat perlu mengunggah berkas (mis. foto bukti absen).
  /// Timeout lebih panjang karena ada unggahan berkas.
  Future<Map<String, dynamic>> postMultipart(
    String query,
    Map<String, String> fields, {
    String? filePath,
    String fileField = 'foto',
    bool auth = true,
  }) async {
    try {
      final req = http.MultipartRequest('POST', ApiConfig.uri(query));
      if (auth) req.headers.addAll(await _authHeader());
      req.fields.addAll(fields);
      if (filePath != null && filePath.isNotEmpty) {
        req.files.add(await http.MultipartFile.fromPath(fileField, filePath));
      }
      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamed);
      return _decode(res);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Server tidak merespons (timeout) saat mengunggah.');
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Cek koneksi & alamat server.');
    }
  }

  /// GET. Default ber-auth (token dilampirkan).
  Future<Map<String, dynamic>> get(String query, {bool auth = true}) async {
    try {
      final headers = auth ? await _authHeader() : <String, String>{};
      final res = await http.get(ApiConfig.uri(query), headers: headers).timeout(_timeout);
      return _decode(res);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Server tidak merespons (timeout). Cek koneksi & alamat server.');
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Cek koneksi & alamat server.');
    }
  }
}
