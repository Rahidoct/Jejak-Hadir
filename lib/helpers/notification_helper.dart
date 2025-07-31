import 'package:flutter/material.dart';

// Enum untuk tipe notifikasi agar lebih mudah dibaca
enum NotificationType { success, error, confirm, info }

class NotificationHelper {
  // Fungsi utama untuk menampilkan dialog kustom
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required NotificationType type,
    VoidCallback? onConfirm, // Callback untuk tombol konfirmasi
  }) {
    // Menentukan ikon dan warna berdasarkan tipe notifikasi
    IconData icon;
    Color color;
    switch (type) {
      case NotificationType.success:
        icon = Icons.check_circle_outline_rounded;
        color = Colors.green;
        break;
      case NotificationType.error:
        icon = Icons.highlight_off_rounded;
        color = Colors.red;
        break;
      case NotificationType.confirm:
        icon = Icons.help_outline_rounded;
        color = Colors.orange;
        break;
      case NotificationType.info:
        icon = Icons.info_outline_rounded;
        color = Colors.blue;
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: type != NotificationType.confirm, // Dialog konfirmasi tidak bisa ditutup dengan tap di luar
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ikon Besar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, color: color, size: 50),
                ),
                const SizedBox(height: 20),
                // Judul
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // Pesan
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                // Tombol-tombol
                _buildButtons(context, type, onConfirm, color),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper untuk membangun tombol berdasarkan tipe notifikasi
  static Widget _buildButtons(BuildContext context, NotificationType type, VoidCallback? onConfirm, Color color) {
    if (type == NotificationType.confirm) {
      // Tombol untuk dialog konfirmasi (Batal & Ya)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Batal', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onConfirm != null) onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Ya, Lanjut', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      );
    } else {
      // Tombol OK untuk dialog informasi (Sukses, Error, Info)
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: color),
          child: const Text('Ok, Sipph', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
    }
  }
}