// lib/screens/absen_screen.dart
//
// Absensi dengan verifikasi wajah.
// HP hanya MENGIRIM bukti (embedding wajah, lokasi, perangkat, foto);
// SERVER yang memutuskan sah/tidaknya — jadi tak bisa dicurangi dari HP.
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../helpers/notification_helper.dart';
import '../services/absensi_service.dart';
import '../services/api_service.dart';
import '../services/face_embedder.dart';
import '../services/liveness.dart';
import 'face_enrollment_screen.dart';

class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  CameraController? _cam;
  bool _camReady = false;
  bool _busy = false;
  bool _loadingStatus = true;

  Map<String, dynamic>? _status; // balasan op=status
  double? _jarak;                // meter ke puskesmas
  String _msg = 'Menyiapkan…';
  String? _fatal;                // error yang menghentikan alur

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await FaceEmbedder.instance.init();
      await _initCamera();
      await _refreshStatus();
      await _refreshLokasi();
    } catch (e) {
      if (mounted) setState(() => _fatal = 'Gagal menyiapkan: $e');
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    _cam = CameraController(front, ResolutionPreset.medium, enableAudio: false);
    await _cam!.initialize();
    if (mounted) setState(() => _camReady = true);
  }

  Future<void> _refreshStatus() async {
    try {
      final s = await AbsensiService.instance.status();
      // Daftarkan perangkat bila belum terdaftar (butuh persetujuan admin).
      final device = s['device'] as Map<String, dynamic>?;
      if (device != null && device['terdaftar'] != true) {
        try {
          await AbsensiService.instance.registerDevice('HP ${DateTime.now().year}');
        } catch (_) {/* diamkan; status perangkat tampil apa adanya */}
      }
      if (mounted) setState(() => _status = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _fatal = e.message);
    }
  }

  Future<void> _refreshLokasi() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _msg = 'Izin lokasi ditolak. Aktifkan untuk bisa absen.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final cfg = _status?['config'] as Map<String, dynamic>?;
      if (cfg != null) {
        final d = Geolocator.distanceBetween(
          pos.latitude, pos.longitude,
          (cfg['lokasi_lat'] as num).toDouble(), (cfg['lokasi_lng'] as num).toDouble(),
        );
        if (mounted) setState(() => _jarak = d);
      }
      _lastPos = pos;
    } catch (e) {
      if (mounted) setState(() => _msg = 'Lokasi tidak terbaca: $e');
    }
  }

  Position? _lastPos;

  // Tahap tantangan liveness (anti foto/cetakan)
  LivenessChallenge? _challenge;
  Face? _faceAwal;
  List<double>? _embedTertunda;
  String? _fotoTertunda;

  // ---------- turunan status ----------
  bool get _enrolled => _status?['enrolled'] == true;
  Map<String, dynamic>? get _jendela => _status?['jendela'] as Map<String, dynamic>?;
  String get _jenis => (_jendela?['jenis'] ?? '-').toString();
  bool get _bolehJendela => _jendela?['boleh'] == true;
  int get _radius => ((_status?['config']?['radius_meter']) as num?)?.toInt() ?? 100;
  bool get _dalamRadius => _jarak != null && _jarak! <= _radius;
  bool get _selesai => (_status?['today']?['sudah_pulang']) == true;

  String? get _alasanTakBisa {
    if (_status == null) return 'Status belum dimuat.';
    if (_selesai) return 'Absensi hari ini sudah lengkap.';
    if (!_enrolled) return 'Wajah belum terdaftar di aplikasi ini.';
    if (_jendela == null) return 'Di luar jadwal absen.';
    if (!_bolehJendela) return (_jendela?['alasan'] ?? 'Di luar jendela waktu absen.').toString();
    if (_jarak == null) return 'Lokasi belum terbaca.';
    if (!_dalamRadius) return 'Anda ${_jarak!.round()} m dari puskesmas (maks $_radius m).';
    return null; // boleh absen
  }

  // ---------- aksi: TAHAP 1 — wajah lurus ----------
  Future<void> _mulaiAbsen() async {
    if (_busy || _cam == null || _lastPos == null) return;
    setState(() { _busy = true; _msg = 'Memverifikasi wajah…'; });
    try {
      final shot = await _cam!.takePicture();
      final res = await FaceEmbedder.instance.processJpeg(await shot.readAsBytes());

      // Wajah harus lurus & mata terbuka agar layak dicocokkan.
      final salah = Liveness.cekFrontal(res.face);
      if (salah != null) {
        if (mounted) setState(() { _busy = false; _msg = salah; });
        return;
      }
      // Foto bukti dibuat dari gambar yang SUDAH diluruskan (bukan berkas mentah
      // kamera), supaya tidak tampil miring di monitoring admin.
      final fotoBukti = await FaceEmbedder.instance.tulisFotoBukti(res.full);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _embedTertunda = res.embedding;
        _fotoTertunda = fotoBukti;
        _faceAwal = res.face;
        _challenge = Liveness.acak(); // tantangan ACAK: tak bisa ditebak
        _msg = Liveness.perintah(_challenge!);
      });
    } on FaceException catch (e) {
      if (mounted) setState(() { _busy = false; _msg = e.message; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _msg = 'Gagal: $e'; });
    }
  }

  // ---------- aksi: TAHAP 2 — tantangan liveness ----------
  Future<void> _verifikasiTantangan() async {
    if (_busy || _cam == null || _challenge == null) return;
    setState(() { _busy = true; _msg = 'Memeriksa gerakan…'; });
    try {
      final shot = await _cam!.takePicture();
      // Deteksi saja (tanpa embedding) → jauh lebih cepat.
      final face = await FaceEmbedder.instance.detectOnly(await shot.readAsBytes());
      final salah = Liveness.cekTantangan(_challenge!, _faceAwal!, face);
      if (salah != null) {
        if (mounted) setState(() { _busy = false; _msg = salah; });
        return;
      }
      await _kirim();
    } on FaceException catch (e) {
      if (mounted) setState(() { _busy = false; _msg = e.message; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _msg = 'Gagal: $e'; });
    }
  }

  void _ulangi() {
    setState(() {
      _challenge = null; _faceAwal = null;
      _embedTertunda = null; _fotoTertunda = null;
      _msg = 'Posisikan wajah di bingkai, lalu tekan tombol.';
    });
  }

  // ---------- kirim ke server ----------
  Future<void> _kirim() async {
    if (mounted) setState(() { _busy = true; _msg = 'Mengirim ke server…'; });
    try {
      final out = await AbsensiService.instance.absen(
        descriptor: _embedTertunda!,
        lat: _lastPos!.latitude,
        lng: _lastPos!.longitude,
        fotoPath: _fotoTertunda!, // foto wajah lurus sebagai bukti
      );

      if (!mounted) return;
      final tipe = (out['tipe'] ?? '').toString();
      final jam = (out['jam'] ?? '').toString();
      final statusAdmin = (out['status_admin'] ?? '').toString();
      final ket = (out['keterangan'] ?? '').toString();
      final ketepatan = (out['ketepatan'] ?? '').toString();
      final pending = statusAdmin != 'approved';

      // Keterlambatan dinilai SERVER (jam_masuk + toleransi resmi), bukan jam
      // HP — jadi tak bisa diakali dengan mengubah waktu di perangkat.
      final terlambat = tipe == 'masuk' && ketepatan.contains('terlambat');

      setState(() { _busy = false; _msg = 'Absen $tipe tercatat pukul $jam'; });

      final statusTeks = pending
          ? '\n\nStatus: MENUNGGU VERIFIKASI Kepegawaian.'
          : '\n\nStatus: Terverifikasi otomatis.';

      await NotificationHelper.show(
        context,
        title: terlambat
            ? 'Astagfirullah!'
            : 'Absen ${tipe == 'pulang' ? 'Pulang' : 'Masuk'} Berhasil',
        message: terlambat
            ? 'Jam segini baru datang? Hadeh! parah banget.\n\nAbsen masuk tetap tercatat pukul $jam.$statusTeks'
            : 'Tercatat pukul $jam.$statusTeks'
              '${ket.isNotEmpty && ket != 'Tidak ada catatan' ? '\nCatatan: $ket' : ''}',
        type: terlambat ? NotificationType.info : (pending ? NotificationType.info : NotificationType.success),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _msg = e.message; });
      await NotificationHelper.show(
        context,
        title: 'Absen Ditolak',
        message: e.message,
        type: NotificationType.error,
      );
      if (mounted) await _refreshStatus();
    } catch (e) {
      if (mounted) setState(() { _busy = false; _msg = 'Gagal: $e'; });
    }
  }

  Future<void> _keEnrollment() async {
    final ok = await Navigator.push(
      context, MaterialPageRoute(builder: (_) => const FaceEnrollmentScreen()),
    );
    if (ok == true && mounted) await _refreshStatus();
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  // ---------- UI ----------
  Widget _chip(IconData ic, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 14, color: c),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.bold)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final alasan = _alasanTakBisa;
    final bisa = alasan == null && !_busy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absen Kehadiran'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang status',
            onPressed: _busy ? null : () async {
              setState(() => _loadingStatus = true);
              await _refreshStatus();
              await _refreshLokasi();
              if (mounted) setState(() => _loadingStatus = false);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _fatal != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 14),
                  Text(_fatal!, textAlign: TextAlign.center),
                ]),
              ),
            )
          : !_camReady || _loadingStatus
              ? const Center(child: CircularProgressIndicator())
              : Stack(fit: StackFit.expand, children: [
                  CameraPreview(_cam!),
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.72,
                      height: MediaQuery.of(context).size.height * 0.42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(200),
                        border: Border.all(color: bisa ? Colors.greenAccent : Colors.white70, width: 4),
                      ),
                    ),
                  ),
                  // Info atas
                  Positioned(
                    top: 12, left: 12, right: 12,
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      _chip(Icons.login, _jenis == 'pulang' ? 'Absen Pulang' : 'Absen Masuk', Colors.lightBlueAccent),
                      if (_jendela != null)
                        _chip(Icons.schedule, '${_jendela!['buka']}–${_jendela!['tutup']}',
                            _bolehJendela ? Colors.greenAccent : Colors.orangeAccent),
                      _chip(Icons.place, _jarak == null ? 'Lokasi…' : '${_jarak!.round()} m',
                          _dalamRadius ? Colors.greenAccent : Colors.redAccent),
                      _chip(Icons.face, _enrolled ? 'Wajah OK' : 'Belum daftar',
                          _enrolled ? Colors.greenAccent : Colors.redAccent),
                    ]),
                  ),
                  // Panel bawah
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          _busy ? _msg : (alasan ?? 'Posisikan wajah di bingkai, lalu tekan tombol.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: alasan == null ? Colors.white : Colors.orangeAccent,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (!_enrolled && !_selesai)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _keEnrollment,
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Daftarkan Wajah Dulu'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                          )
                        else if (_challenge != null)
                          // TAHAP 2 — tantangan liveness
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.verified_user, color: Colors.amberAccent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tantangan: ${Liveness.judul(_challenge!)}',
                                    style: const TextStyle(
                                        color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy ? null : _ulangi,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                  child: const Text('Ulangi'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _busy ? null : _verifikasiTantangan,
                                  icon: _busy
                                      ? const SizedBox(height: 18, width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.check),
                                  label: Text(_busy ? 'Memeriksa…' : 'Verifikasi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                ),
                              ),
                            ]),
                          ])
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: bisa ? _mulaiAbsen : null,
                              icon: _busy
                                  ? const SizedBox(height: 18, width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(_jenis == 'pulang' ? Icons.logout : Icons.login),
                              label: Text(_busy
                                  ? 'Memproses…'
                                  : (_jenis == 'pulang' ? 'ABSEN PULANG' : 'ABSEN MASUK')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _jenis == 'pulang' ? Colors.redAccent : Colors.green,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}
