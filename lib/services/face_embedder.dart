// lib/services/face_embedder.dart
//
// Pipeline pengenalan wajah untuk absensi:
//   JPEG → (bake EXIF) → deteksi ML Kit + 5 landmark → align 112x112 (template
//   ArcFace) → model ONNX MobileFaceNet → embedding 512-d ter-L2-normalize.
//
// Embedding inilah yang dikirim ke server (op=enroll / op=absen, model=arcface512).
// Server yang mencocokkan — aplikasi tidak pernah memutuskan lolos/tidaknya.
//
// KONTRAK PRA-PROSES (WAJIB SAMA saat web disatukan nanti di Fase 1b):
//   - align similarity-transform 5 titik ke template ArcFace 112x112
//   - urutan titik: mata-kiri, mata-kanan, hidung, mulut-kiri, mulut-kanan
//     (kiri/kanan ditentukan dari koordinat X pada gambar, bukan label)
//   - piksel RGB, normalisasi (x - 127.5) / 127.5, tata letak NCHW
//   - output di-L2-normalize
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class FaceResult {
  final List<double> embedding; // 512, sudah L2-normalize
  final img.Image aligned;      // 112x112 (hasil alignment)
  final Face face;              // hasil deteksi (untuk cek kualitas/liveness)
  final img.Image full;         // gambar penuh yang SUDAH diluruskan (EXIF di-bake)
  FaceResult(this.embedding, this.aligned, this.face, this.full);
}

class FaceException implements Exception {
  final String message;
  FaceException(this.message);
  @override
  String toString() => message;
}

class FaceEmbedder {
  FaceEmbedder._();
  static final FaceEmbedder instance = FaceEmbedder._();

  static const String modelAsset = 'assets/models/w600k_mbf.onnx';
  static const String modelVersion = 'arcface512'; // dikirim ke server
  static const String _inputName = 'input.1';
  static const String _outputName = '516';
  static const int _size = 112;

  OrtSession? _session;
  FaceDetector? _detector;

  /// Template 5 titik ArcFace untuk keluaran 112x112 (standar InsightFace).
  static const List<List<double>> _template = [
    [38.2946, 51.6963], // mata kiri (pada gambar)
    [73.5318, 51.5014], // mata kanan
    [56.0252, 71.7366], // hidung
    [41.5493, 92.3655], // sudut mulut kiri
    [70.7299, 92.2041], // sudut mulut kanan
  ];

  Future<void> init() async {
    _session ??= await OnnxRuntime().createSessionFromAsset(modelAsset);
    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true, // WAJIB: butuh 5 titik untuk alignment
        enableClassification: true, // probabilitas mata terbuka (untuk liveness)
        minFaceSize: 0.15,
      ),
    );
  }

  /// Decode + terapkan orientasi EXIF + deteksi wajah terbesar.
  /// Ditulis ulang ke file sementara supaya ML Kit melihat piksel yang SAMA
  /// dengan yang di-align (tanpa ini, rotasi EXIF bikin landmark meleset).
  Future<(img.Image, Face)> _decodeAndDetect(Uint8List jpegBytes) async {
    await init();

    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) throw FaceException('Gambar tidak bisa dibaca.');
    final image = img.bakeOrientation(decoded);

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/face_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await f.writeAsBytes(img.encodeJpg(image, quality: 95), flush: true);

    try {
      final faces = await _detector!.processImage(InputImage.fromFilePath(f.path));
      if (faces.isEmpty) throw FaceException('Wajah tidak terdeteksi. Posisikan wajah di dalam bingkai.');
      // Ambil wajah terbesar (paling dekat kamera).
      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
          .compareTo(a.boundingBox.width * a.boundingBox.height));
      return (image, faces.first);
    } finally {
      if (await f.exists()) {
        try { await f.delete(); } catch (_) {}
      }
    }
  }

  /// Proses satu foto JPEG menjadi embedding siap kirim.
  /// Melempar [FaceException] bila wajah tak terdeteksi / landmark kurang.
  Future<FaceResult> processJpeg(Uint8List jpegBytes) async {
    final (image, face) = await _decodeAndDetect(jpegBytes);
    final pts = _fivePoints(face);
    final aligned = _alignTo112(image, pts);
    final embedding = await _embed(aligned);
    return FaceResult(embedding, aligned, face, image);
  }

  /// Tulis foto bukti ke berkas sementara dari gambar yang SUDAH diluruskan.
  ///
  /// Penting: jangan mengunggah JPEG mentah kamera — tegaknya bergantung pada
  /// metadata EXIF, sedangkan server menyimpan ulang gambar tanpa membaca EXIF
  /// sehingga hasilnya miring. Gambar di sini sudah di-bake orientasinya, jadi
  /// tegak apa adanya. Sekalian diperkecil supaya unggahan ringan.
  Future<String> tulisFotoBukti(img.Image full, {int lebar = 720}) async {
    final kecil = full.width > lebar ? img.copyResize(full, width: lebar) : full;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/absen_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await f.writeAsBytes(img.encodeJpg(kecil, quality: 85), flush: true);
    return f.path;
  }

  /// Deteksi saja, TANPA embedding — dipakai untuk memverifikasi tantangan
  /// liveness (jauh lebih cepat karena melewati alignment & inferensi model).
  Future<Face> detectOnly(Uint8List jpegBytes) async {
    final (_, face) = await _decodeAndDetect(jpegBytes);
    return face;
  }

  /// Ambil 5 titik. Kiri/kanan ditentukan dari koordinat X (bukan label ML Kit)
  /// agar tahan terhadap gambar tercermin pada kamera depan.
  List<List<double>> _fivePoints(Face face) {
    math.Point<int>? p(FaceLandmarkType t) => face.landmarks[t]?.position;
    final e1 = p(FaceLandmarkType.leftEye), e2 = p(FaceLandmarkType.rightEye);
    final nose = p(FaceLandmarkType.noseBase);
    final m1 = p(FaceLandmarkType.leftMouth), m2 = p(FaceLandmarkType.rightMouth);
    if (e1 == null || e2 == null || nose == null || m1 == null || m2 == null) {
      throw FaceException('Landmark wajah tidak lengkap. Hadapkan wajah lurus ke kamera.');
    }
    final eyes = [[e1.x.toDouble(), e1.y.toDouble()], [e2.x.toDouble(), e2.y.toDouble()]]
      ..sort((a, b) => a[0].compareTo(b[0]));
    final mouth = [[m1.x.toDouble(), m1.y.toDouble()], [m2.x.toDouble(), m2.y.toDouble()]]
      ..sort((a, b) => a[0].compareTo(b[0]));
    return [eyes[0], eyes[1], [nose.x.toDouble(), nose.y.toDouble()], mouth[0], mouth[1]];
  }

  /// Similarity transform (skala+rotasi+translasi) kuadrat terkecil memakai
  /// bentuk tertutup bilangan kompleks: dst = a*src + b.
  /// Lalu warp balik (inverse) dengan sampling bilinear ke kanvas 112x112.
  img.Image _alignTo112(img.Image src, List<List<double>> pts) {
    final n = pts.length;
    double mpx = 0, mpy = 0, mqx = 0, mqy = 0;
    for (var i = 0; i < n; i++) {
      mpx += pts[i][0]; mpy += pts[i][1];
      mqx += _template[i][0]; mqy += _template[i][1];
    }
    mpx /= n; mpy /= n; mqx /= n; mqy /= n;

    double num1 = 0, num2 = 0, den = 0;
    for (var i = 0; i < n; i++) {
      final px = pts[i][0] - mpx, py = pts[i][1] - mpy;
      final qx = _template[i][0] - mqx, qy = _template[i][1] - mqy;
      num1 += qx * px + qy * py; // bagian real
      num2 += qy * px - qx * py; // bagian imajiner
      den += px * px + py * py;
    }
    if (den == 0) throw FaceException('Titik wajah tidak valid.');
    final ax = num1 / den, ay = num2 / den;
    final bx = mqx - (ax * mpx - ay * mpy);
    final by = mqy - (ay * mpx + ax * mpy);

    final aNorm2 = ax * ax + ay * ay;
    if (aNorm2 == 0) throw FaceException('Transformasi wajah gagal.');

    final out = img.Image(width: _size, height: _size);
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        // inverse: src = (dst - b) / a
        final dx = x - bx, dy = y - by;
        final sx = (dx * ax + dy * ay) / aNorm2;
        final sy = (dy * ax - dx * ay) / aNorm2;
        final c = _bilinear(src, sx, sy);
        out.setPixelRgb(x, y, c[0], c[1], c[2]);
      }
    }
    return out;
  }

  List<int> _bilinear(img.Image im, double x, double y) {
    if (x < 0 || y < 0 || x > im.width - 1 || y > im.height - 1) return const [0, 0, 0];
    final x0 = x.floor(), y0 = y.floor();
    final x1 = math.min(x0 + 1, im.width - 1), y1 = math.min(y0 + 1, im.height - 1);
    final fx = x - x0, fy = y - y0;
    final p00 = im.getPixel(x0, y0), p10 = im.getPixel(x1, y0);
    final p01 = im.getPixel(x0, y1), p11 = im.getPixel(x1, y1);
    double mix(num a, num b, num c, num d) =>
        (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy;
    return [
      mix(p00.r, p10.r, p01.r, p11.r).round().clamp(0, 255),
      mix(p00.g, p10.g, p01.g, p11.g).round().clamp(0, 255),
      mix(p00.b, p10.b, p01.b, p11.b).round().clamp(0, 255),
    ];
  }

  /// Jalankan model: RGB → (x-127.5)/127.5 → NCHW → ONNX → L2-normalize.
  Future<List<double>> _embed(img.Image aligned) async {
    final n = _size * _size;
    final input = Float32List(3 * n);
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        final p = aligned.getPixel(x, y);
        final i = y * _size + x;
        input[i] = (p.r - 127.5) / 127.5;             // R
        input[n + i] = (p.g - 127.5) / 127.5;         // G
        input[2 * n + i] = (p.b - 127.5) / 127.5;     // B
      }
    }

    final value = await OrtValue.fromList(input, [1, 3, _size, _size]);
    try {
      final outputs = await _session!.run({_inputName: value});
      final raw = await outputs[_outputName]!.asList();

      // Output berbentuk [1, 512] → bisa datang bersarang (mis. [Float32List])
      // atau sudah datar. Ratakan apa pun bentuknya, jangan diasumsikan.
      final vec = _flatten(raw);
      if (vec.length != 512) {
        throw FaceException('Panjang embedding tak wajar: ${vec.length} (harusnya 512).');
      }

      double sum = 0;
      for (final v in vec) { sum += v * v; }
      final norm = math.sqrt(sum);
      if (norm == 0) throw FaceException('Embedding tidak valid.');
      return vec.map((v) => v / norm).toList(growable: false);
    } finally {
      try { await value.dispose(); } catch (_) {}
    }
  }

  /// Ratakan hasil ONNX menjadi `List<double>`, apa pun bentuk sarangnya
  /// (List, Float32List, atau campuran). Menghindari asumsi bentuk keluaran.
  List<double> _flatten(dynamic v) {
    final out = <double>[];
    void walk(dynamic x) {
      if (x is num) {
        out.add(x.toDouble());
      } else if (x is Iterable) {
        for (final e in x) { walk(e); }
      }
    }
    walk(v);
    return out;
  }

  Future<void> dispose() async {
    try { await _session?.close(); } catch (_) {}
    try { await _detector?.close(); } catch (_) {}
    _session = null;
    _detector = null;
  }
}
