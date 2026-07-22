// lib/services/liveness.dart
//
// Tantangan anti-pemalsuan (liveness) untuk absensi.
// Tujuannya menolak foto/cetakan/tangkapan layar: benda mati tak bisa
// menengok atau tersenyum.
//
// Alur: foto 1 (wajah lurus, dipakai untuk embedding) → tantangan ACAK →
// foto 2 (hanya dideteksi) → dibandingkan dengan foto 1.
//
// Catatan arah: sengaja TIDAK menentukan kiri/kanan. Kamera depan menampilkan
// bayangan cermin sehingga patokan kiri/kanan mudah terbalik antar perangkat
// dan membuat pengguna gagal terus. Foto diam tetap tak bisa menengok, jadi
// perlindungannya tidak berkurang.
import 'dart:math';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessChallenge { tengokSamping, senyum }

class Liveness {
  /// Ambang wajah dianggap menghadap depan (foto untuk pencocokan wajah).
  static const double _maxYawFrontal = 15.0;

  /// Minimal sudut menengok & minimal perubahan dari foto pertama.
  static const double _minYawTurn = 18.0;
  static const double _minYawDelta = 15.0;

  /// Minimal probabilitas senyum.
  static const double _minSmile = 0.70;

  static LivenessChallenge acak() {
    final v = Random().nextInt(2);
    return v == 0 ? LivenessChallenge.tengokSamping : LivenessChallenge.senyum;
  }

  static String perintah(LivenessChallenge c) {
    switch (c) {
      case LivenessChallenge.tengokSamping:
        return 'Tengokkan kepala ke samping (kiri atau kanan), tahan, lalu tekan Verifikasi.';
      case LivenessChallenge.senyum:
        return 'Tersenyumlah yang jelas, lalu tekan Verifikasi.';
    }
  }

  static String judul(LivenessChallenge c) {
    switch (c) {
      case LivenessChallenge.tengokSamping:
        return 'Tengok ke Samping';
      case LivenessChallenge.senyum:
        return 'Senyum';
    }
  }

  /// Foto pertama harus wajah lurus & mata terbuka agar layak dicocokkan.
  /// Mengembalikan pesan kesalahan, atau null bila lolos.
  static String? cekFrontal(Face f) {
    final yaw = (f.headEulerAngleY ?? 0).abs();
    if (yaw > _maxYawFrontal) {
      return 'Hadapkan wajah lurus ke kamera (jangan menengok) lalu coba lagi.';
    }
    final l = f.leftEyeOpenProbability, r = f.rightEyeOpenProbability;
    if (l != null && r != null && l < 0.3 && r < 0.3) {
      return 'Mata terpejam. Buka mata lalu coba lagi.';
    }
    return null;
  }

  /// Verifikasi tantangan pada foto kedua, dibandingkan dengan foto pertama.
  /// Mengembalikan pesan kesalahan, atau null bila lolos.
  static String? cekTantangan(LivenessChallenge c, Face awal, Face uji) {
    switch (c) {
      case LivenessChallenge.tengokSamping:
        final y0 = awal.headEulerAngleY ?? 0;
        final y1 = uji.headEulerAngleY ?? 0;
        if (y1.abs() < _minYawTurn || (y1 - y0).abs() < _minYawDelta) {
          return 'Tengokan belum cukup terlihat. Tengokkan kepala lebih jauh ke samping.';
        }
        return null;
      case LivenessChallenge.senyum:
        final s = uji.smilingProbability;
        if (s == null) return 'Senyum tidak terbaca. Coba lagi dengan cahaya lebih terang.';
        if (s < _minSmile) return 'Senyum belum terlihat jelas. Coba tersenyum lebih lebar.';
        return null;
    }
  }
}
