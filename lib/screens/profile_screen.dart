import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';

class ProfileScreen extends StatelessWidget {
  final LocalUser user;
  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('NIP'),
                subtitle: Text(user.nip ?? '-'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.work),
                title: const Text('Jabatan'),
                subtitle: Text(user.position ?? '-'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Golongan'),
                subtitle: Text(user.grade ?? '-'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}