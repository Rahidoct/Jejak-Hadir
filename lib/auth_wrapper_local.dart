import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/screens/auth_screen_local.dart';
import 'package:jejak_hadir_app/screens/home_screen_local.dart';
import 'package:jejak_hadir_app/services/auth_service_local.dart';

// Diubah menjadi StatelessWidget karena widget ini tidak perlu menyimpan state apapun lagi.
// Ia hanya bertugas mendengarkan si "Juru Bicara".
class AuthWrapperLocal extends StatelessWidget {
  const AuthWrapperLocal({super.key});

  // TIDAK ADA LAGI variabel _auth dan method dispose() di sini.
  // Ini sangat penting.

  @override
  Widget build(BuildContext context) {
    // Kita gunakan StreamBuilder untuk mendengarkan perubahan dari si "Juru Bicara"
    return StreamBuilder<LocalUser?>(
      
      // Di sinilah kita mendengarkan "Juru Bicara" yang resmi dan satu-satunya.
      stream: AuthServiceLocal.instance.user,
      
      builder: (context, snapshot) {
        // Jika "Juru Bicara" masih mencari tahu status login, tampilkan loading.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } 
        // Jika "Juru Bicara" berkata "Ada pengguna yang sedang login!",
        // maka tampilkan halaman utama (HomeScreenLocal).
        else if (snapshot.hasData && snapshot.data != null) {
          return HomeScreenLocal(user: snapshot.data!);
        } 
        // Jika "Juru Bicara" berkata "Tidak ada yang login!",
        // maka tampilkan halaman login (AuthScreenLocal).
        else {
          return const AuthScreenLocal();
        }
      },
    );
  }
}