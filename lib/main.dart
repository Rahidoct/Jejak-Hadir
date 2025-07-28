import 'package:flutter/material.dart';
import 'auth_wrapper_local.dart'; // Ganti import

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jejak Hadir Pegawai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue, // Anda bisa ganti ke Colors.blue jika ingin konsisten dengan AppBar
      ),
      // Langsung arahkan ke AuthWrapperLocal untuk menangani logika login
      home: const AuthWrapperLocal(), 
    );
  }
}