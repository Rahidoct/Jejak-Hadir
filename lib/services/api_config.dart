// lib/services/api_config.dart
//
// Konfigurasi alamat backend Puskesmas Bunder.
//
// GANTI `baseUrl` sesuai lingkungan pengujian:
//  - Emulator Android : http://10.0.2.2/native/puskesmas   (10.0.2.2 = localhost PC dari emulator)
//  - HP fisik via LAN : http://<IP-PC>/native/puskesmas     (mis. http://192.168.1.10/native/puskesmas)
//  - Produksi          : https://<domain>/...
//
// Catatan: login boleh lewat HTTP saat uji lokal, TAPI fitur absensi (kamera)
// nanti mewajibkan HTTPS — siapkan SSL Laragon / domain sebelum Fase 2.
class ApiConfig {
  ApiConfig._();

  // HP fisik via USB + `adb reverse tcp:8080 tcp:80` → HP:8080 diteruskan ke
  // PC:80 (port 80 di HP tak bisa dipakai tanpa root, jadi pakai 8080).
  // (Emulator Android: ganti ke http://10.0.2.2/native/puskesmas)
  static const String baseUrl = 'http://127.0.0.1:8080/native/puskesmas';

  /// Bentuk URL endpoint: endpoint('mobile_auth&op=login') →
  /// http://.../index.php?mobile_auth&op=login
  static Uri uri(String query) => Uri.parse('$baseUrl/index.php?$query');
}
