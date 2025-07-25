import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';

class ScheduleScreen extends StatelessWidget {
  final LocalUser user;
  const ScheduleScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Jadwal Kegiatan ${user.name}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text('Belum ada jadwal tersedia'),
          ],
        ),
      ),
    );
  }
}