// lib/screens/leave_history_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jejak_hadir_app/models/leave_request_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaveHistoryScreen extends StatefulWidget {
  final String userId;
  const LeaveHistoryScreen({super.key, required this.userId, required VoidCallback onDataChanged});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  late Future<List<LeaveRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = LocalStorageService().getLeaveRequestsByUserId(widget.userId);
  }
  
  // [PERUBAHAN 1] Memperbarui logika untuk siklus 3 status
  void _cycleStatus(LeaveRequest request) async {
    final service = LocalStorageService();
    final allRequests = await service.getLeaveRequests();
    
    allRequests.removeWhere((r) => r.id == request.id);
    
    // Logika untuk siklus status: Diajukan -> Disetujui -> Ditolak -> Diajukan
    String newStatus;
    if (request.status == 'Diajukan') {
      newStatus = 'Disetujui';
    } else if (request.status == 'Disetujui') {
      newStatus = 'Ditolak';
    } else { // Jika status 'Ditolak' atau lainnya
      newStatus = 'Diajukan';
    }

    final updatedRequest = LeaveRequest(
      id: request.id, 
      userId: request.userId, 
      requestType: request.requestType, 
      leaveCategory: request.leaveCategory,
      startDate: request.startDate, 
      endDate: request.endDate, 
      reason: request.reason, 
      submittedDate: request.submittedDate,
      attachmentPath: request.attachmentPath,
      status: newStatus,
    );
    allRequests.add(updatedRequest);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('leave_requests', allRequests.map((r) => jsonEncode(r.toMap())).toList());

    setState(() {
      _requestsFuture = LocalStorageService().getLeaveRequestsByUserId(widget.userId);
    });
  }

  // [PERUBAHAN 2] Helper untuk menentukan warna status agar lebih bersih
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disetujui':
        return Colors.green.shade700;
      case 'Ditolak':
        return Colors.red.shade700;
      case 'Diajukan':
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Riwayat'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<LeaveRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Belum ada riwayat pengajuan.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }
          final requests = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  // [PERUBAHAN 3] Memanggil fungsi baru dan memperbarui pesan notifikasi
                  onLongPress: () {
                    _cycleStatus(request); // Panggil fungsi dengan nama baru
                    
                    // Tentukan teks status berikutnya untuk ditampilkan di notifikasi
                    String nextStatusText;
                    if (request.status == 'Diajukan') {
                      nextStatusText = 'Disetujui';
                    } else if (request.status == 'Disetujui') {
                      nextStatusText = 'Ditolak';
                    } else {
                      nextStatusText = 'Diajukan';
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Status diubah menjadi: $nextStatusText'), duration: const Duration(seconds: 2))
                    );
                  },
                  title: Text(request.reason, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${DateFormat('d MMM y', 'id_ID').format(request.startDate)} - ${DateFormat('d MMM y', 'id_ID').format(request.endDate)}',
                  ),
                  trailing: Text(
                    request.status, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      // [PERUBAHAN 4] Menggunakan helper warna yang baru
                      color: _getStatusColor(request.status),
                    )
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}