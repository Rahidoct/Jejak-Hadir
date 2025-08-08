// lib/screens/face_data_screen.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/helpers/notification_helper.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'face_enrollment_screen.dart';

class FaceDataScreen extends StatelessWidget {
  final LocalUser user;
  final VoidCallback onDataChanged;

  const FaceDataScreen({
    super.key, 
    required this.user,
    required this.onDataChanged,
  });

  Future<void> _navigateToFaceEnrollment(BuildContext context) async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => FaceEnrollmentScreen(userId: user.uid))
    );
    
    if (result == true && context.mounted) {
      onDataChanged();
      Navigator.pop(context, 'updated');
    }
  }

  void _deleteFaceData(BuildContext context) {
    NotificationHelper.show(
      context, 
      title: "Hapus Data Wajah", 
      message: "Apakah Anda yakin ingin menghapus data wajah Anda?", 
      type: NotificationType.confirm,
      onConfirm: () async {
        await LocalStorageService().updateUserFaceData(user.uid, null);
        if (context.mounted) {
          onDataChanged();
          // Navigasi ke profile_screen.dar
          Navigator.pop(context, 'deleted');
        }
      }
    );
  }

  void _showFaceStatus(BuildContext context) {
    if (user.faceData == null) {
       NotificationHelper.show(context, title: "Info", message: "Data wajah tidak ditemukan.", type: NotificationType.info);
       return;
    }
    
    final Uint8List faceBytes = base64Decode(user.faceData!);

    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        title: const Text("Data Wajah Terekam"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(faceBytes),
            const SizedBox(height: 16),
            const Text("Ini adalah data wajah yang tersimpan di perangkat Anda."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("OK")
          )
        ],
      )
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? Colors.blue;
    return Card(
      color: Colors.grey.shade50,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(icon, color: itemColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: TextStyle(color: itemColor, fontWeight: FontWeight.w500, fontSize: 16)),
              ),
              Icon(Icons.chevron_right, color: color ?? Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Wajah'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: Column(
          children: [
            _buildMenuCard(
              context: context,
              icon: Icons.check_circle_outline,
              title: 'Wajah Terekam',
              color: Colors.green.shade700,
              onTap: () => _showFaceStatus(context),
            ),
            _buildMenuCard(
              context: context,
              icon: Icons.camera_front_outlined,
              title: 'Ubah Data Wajah',
              onTap: () => _navigateToFaceEnrollment(context),
            ),
            _buildMenuCard(
              context: context,
              icon: Icons.delete_outline,
              title: 'Hapus Data Wajah',
              color: Colors.red,
              onTap: () => _deleteFaceData(context),
            ),
          ],
        ),
      ),
    );
  }
}