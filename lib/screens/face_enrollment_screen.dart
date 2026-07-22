// lib/screens/face_enrollment_screen.dart
//
// Pendaftaran wajah (enrollment) untuk absensi.
// Ambil 3 sampel foto → hitung embedding di HP (MobileFaceNet ONNX) →
// kirim ke server (op=enroll, model=arcface512).
//
// Catatan: embedding dihitung di HP, tetapi PENCOCOKAN saat absen tetap
// dilakukan server — aplikasi tak pernah memutuskan lolos/tidaknya.
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../helpers/notification_helper.dart';
import '../services/api_service.dart';
import '../services/face_embedder.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  static const int _targetSamples = 3;

  CameraController? _cam;
  bool _ready = false;
  bool _busy = false;
  String _msg = 'Menyiapkan kamera…';
  final List<List<double>> _samples = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await FaceEmbedder.instance.init(); // muat model lebih awal
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      _cam = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _cam!.initialize();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _msg = 'Posisikan wajah di dalam bingkai, lalu tekan Ambil Sampel.';
      });
    } catch (e) {
      if (mounted) setState(() => _msg = 'Gagal menyiapkan kamera/model: $e');
    }
  }

  Future<void> _capture() async {
    if (!_ready || _busy || _cam == null) return;
    setState(() { _busy = true; _msg = 'Memproses wajah…'; });

    try {
      final shot = await _cam!.takePicture();
      final bytes = await shot.readAsBytes();
      final res = await FaceEmbedder.instance.processJpeg(bytes);

      _samples.add(res.embedding);
      if (!mounted) return;

      if (_samples.length >= _targetSamples) {
        setState(() => _msg = 'Mengirim ${_samples.length} sampel ke server…');
        await _submit();
      } else {
        setState(() {
          _busy = false;
          _msg = 'Sampel ${_samples.length}/$_targetSamples tersimpan. '
                 'Ubah sedikit posisi/ekspresi, lalu ambil lagi.';
        });
      }
    } on FaceException catch (e) {
      if (mounted) setState(() { _busy = false; _msg = e.message; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _msg = 'Gagal memproses: $e'; });
    }
  }

  Future<void> _submit() async {
    try {
      await ApiService.instance.postForm(
        'absensi_action&op=enroll&model=${FaceEmbedder.modelVersion}',
        {'descriptors': jsonEncode(_samples)},
        auth: true,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _msg = 'Perekaman wajah berhasil ✓';
      });

      // Tampilkan notifikasi lalu TUNGGU sampai ditutup pengguna, baru keluar.
      // (Kalau tidak ditunggu, Navigator.pop akan menutup dialognya — bukan
      // layar ini — sehingga layar tersangkut.)
      await NotificationHelper.show(
        context,
        title: 'Perekaman Wajah Berhasil',
        message: 'Data wajah Anda sudah tersimpan. Sekarang Anda bisa melakukan absensi.',
        type: NotificationType.success,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _samples.clear();
        _msg = 'Gagal mendaftar: ${e.message}. Silakan ulangi.';
      });
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _samples.length / _targetSamples;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Wajah'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: !_ready
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_msg, textAlign: TextAlign.center),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cam!),
                // Bingkai panduan
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.72,
                    height: MediaQuery.of(context).size.height * 0.46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(200),
                      border: Border.all(color: Colors.white70, width: 4),
                    ),
                  ),
                ),
                // Panel bawah
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          color: Colors.lightBlueAccent,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sampel ${_samples.length} / $_targetSamples',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _msg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _capture,
                            icon: _busy
                                ? const SizedBox(
                                    height: 18, width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.camera_alt),
                            label: Text(_busy ? 'Memproses…' : 'Ambil Sampel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
