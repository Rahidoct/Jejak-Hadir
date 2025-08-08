// lib/screens/face_enrollment_screen.dart

import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'package:image/image.dart' as img;

class FaceEnrollmentScreen extends StatefulWidget {
  final String userId;
  const FaceEnrollmentScreen({super.key, required this.userId});
  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _message = "Posisikan wajah Anda di dalam bingkai";

  @override
  void initState() {
    super.initState();
    _initializeCameraAndDetector();
  }

  Future<void> _initializeCameraAndDetector() async {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);

    final cameras = await availableCameras();
    CameraDescription frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      _cameraController!.startImageStream((image) {
        if (!_isProcessing) {
          _processImage(image);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("FaceEnrollment: Gagal total inisialisasi kamera: $e");
      }
      if (mounted) {
        setState(() {
          _message = "Gagal memulai kamera. Mohon restart aplikasi.";
        });
      }
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (!mounted) return;
    _isProcessing = true;

    try {
      // --- [PERBAIKAN UTAMA DAN FINAL ADA DI SINI] ---
      
      // 1. Gabungkan semua data byte dari semua 'plane' gambar.
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // 2. Tentukan ukuran dan rotasi gambar.
      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameraController!.description;
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;

      // 3. [KUNCI PERBAIKAN] Jangan baca format dari gambar. Paksa ke NV21.
      // Ini adalah format standar untuk YUV420 di Android.
      final inputImageFormat = InputImageFormat.nv21;

      // 4. Buat metadata dengan format yang sudah kita paksa.
      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      // 5. Buat InputImage dari data yang sudah disiapkan.
      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      
      // 6. Proses gambar dengan ML Kit.
      List<Face> faces = await _faceDetector!.processImage(inputImage);
      
      if (faces.isNotEmpty && mounted) {
        await _cameraController?.stopImageStream();
        
        final faceImage = _cropFace(image, faces.first);
        if (faceImage == null) {
          // Jika gagal crop, jangan lanjutkan
          if (kDebugMode) print("Gagal memotong wajah dari gambar.");
          _isProcessing = false;
          return;
        }

        final String base64Image = base64Encode(img.encodeJpg(faceImage));
        await LocalStorageService().updateUserFaceData(widget.userId, base64Image);
        
        setState(() {
          _message = "Wajah terdeteksi! Berhasil.";
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        // Jika tidak ada wajah terdeteksi, biarkan proses berlanjut
        _isProcessing = false;
      }
    } catch (e) {
      if (kDebugMode) {
        // Log error yang lebih spesifik
        print("FaceEnrollment: Error saat deteksi wajah: $e");
      }
      _isProcessing = false;
    }
  }

  img.Image? _cropFace(CameraImage image, Face face) {
    // Fungsi ini mengkonversi gambar YUV (grayscale plane) ke format yang bisa di-crop
    try {
      final img.Image convertedImage = img.Image.fromBytes(
        width: image.width, 
        height: image.height,
        bytes: image.planes[0].bytes.buffer, 
        format: img.Format.uint8, // Format LUMINANCE (grayscale)
        numChannels: 1
      );

      final x = face.boundingBox.left.toInt();
      final y = face.boundingBox.top.toInt();
      final w = face.boundingBox.width.toInt();
      final h = face.boundingBox.height.toInt();

      final img.Image croppedImage = img.copyCrop(convertedImage, x: x, y: y, width: w, height: h);
      return croppedImage;
    } catch (e) {
      if (kDebugMode) print("Error saat cropping: $e");
      return null;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perekaman Wajah"),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: _isCameraInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.height * 0.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(150),
                      // ignore: deprecated_member_use
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 4),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ),
                )
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_message, style: const TextStyle(fontSize: 16)),
                ],
              )
            ),
    );
  }
}