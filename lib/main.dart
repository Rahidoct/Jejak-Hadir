import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/screens/home_screen_local.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Buat user dummy langsung
    final dummyUser = LocalUser(
      uid: 'dummy-123',
      email: 'dokter@puskesmasbunder.com',
      name: 'drg. Adiba Artanti',
      nip: '199110032023211001',
      position: 'DOKTER GIGI AHLI PERTAMA',
      grade: 'X',
    );

    return MaterialApp(
      title: 'Jejak Hadir Pegawai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: HomeScreenLocal(user: dummyUser), // Langsung ke HomeScreen dengan user dummy
    );
  }
}