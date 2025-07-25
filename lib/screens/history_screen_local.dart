import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_local.dart';
import '../services/local_storage_service.dart';

class HistoryScreenLocal extends StatelessWidget {
  final String userId;
  const HistoryScreenLocal({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final LocalStorageService localStorageService = LocalStorageService();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFDCEDC8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<LocalAttendance>>(
          future: localStorageService.getAttendancesByUserId(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 16)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Belum ada riwayat absensi.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              );
            }

            final attendances = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: attendances.length,
              itemBuilder: (context, index) {
                final attendance = attendances[index];
                final isCheckIn = attendance.type == 'check_in';
                final icon = isCheckIn ? Icons.login : Icons.logout;
                final color = isCheckIn ? Colors.green[700] : Colors.red[700];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 40, color: color),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCheckIn ? 'Check-in' : 'Check-out',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Waktu: ${DateFormat('dd-MM-yyyy HH:mm:ss').format(attendance.timestamp)}',
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                              Text(
                                'Lokasi: ${attendance.latitude.toStringAsFixed(4)}, ${attendance.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(fontSize: 16, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}