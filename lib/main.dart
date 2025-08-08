import 'package:flutter/material.dart';
import 'auth_wrapper_local.dart';

void main() async {
  // Pastikan binding Flutter sudah siap
  WidgetsFlutterBinding.ensureInitialized();
  
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
        primarySwatch: Colors.blue,
      ),
      // Langsung arahkan ke AuthWrapperLocal untuk menangani logika login
      home: const AuthWrapperLocal(), 
    );
  }
}