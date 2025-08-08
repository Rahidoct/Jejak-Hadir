// lib/screens/monthly_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:jejak_hadir_app/models/leave_request_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import '../models/attendance_local.dart';
import '../models/user_local.dart';

class MonthlyDetailScreen extends StatefulWidget {
  final String monthName;
  final List<LocalAttendance> attendances;
  final LocalUser user; 

  const MonthlyDetailScreen({
    super.key,
    required this.monthName,
    required this.attendances,
    required this.user,
  });

  @override
  State<MonthlyDetailScreen> createState() => _MonthlyDetailScreenState();
}

class _MonthlyDetailScreenState extends State<MonthlyDetailScreen> {
  late Future<Map<String, dynamic>> _dataFuture;
  final LocalStorageService _storageService = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAllData();
  }

  Future<Map<String, dynamic>> _loadAllData() async {
    final approvedLeaves = await _storageService.getApprovedLeaveRequestsByUserId(widget.user.uid);
    return {
      'attendances': widget.attendances,
      'approvedLeaves': approvedLeaves,
    };
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade700))),
          const Text(":  ", style: TextStyle(fontSize: 15)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // [PERUBAHAN 1] Perbarui _buildDayTile untuk menangani detail izin
  Widget _buildDayTile({
    required int dayIndex,
    required DateTime date,
    required String status,
    required Color color,
    List<LocalAttendance>? dailyAttendances,
    LeaveRequest? leaveRequest, // Tambahkan parameter untuk data izin
  }) {
    String kehadiranValue = status;
    String jamMasuk = "-";
    String jamPulang = "-";
    String lokasi = "-";

    bool isHadir = status == "Hadir";
    bool isAlpa = status == "Alpa / Tidak Hadir";
    bool isOnLeave = status == "Izin / Sakit";
    
    Color textColor = Colors.black87;
    if (isAlpa) textColor = Colors.red;
    if (isHadir) textColor = Colors.blue;
    if (isOnLeave) textColor = Colors.orange.shade800;
    
    if (isHadir && dailyAttendances != null) {
      final checkInRecord = dailyAttendances.firstWhereOrNull((att) => att.type == 'check_in');
      final checkOutRecord = dailyAttendances.firstWhereOrNull((att) => att.type == 'check_out');
      jamMasuk = checkInRecord != null ? DateFormat('HH:mm:ss').format(checkInRecord.timestamp) : '-';
      jamPulang = checkOutRecord != null ? DateFormat('HH:mm:ss').format(checkOutRecord.timestamp) : '-';
      lokasi = checkInRecord != null ? '${checkInRecord.latitude.toStringAsFixed(4)}, ${checkInRecord.longitude.toStringAsFixed(4)}' : '-';
    }

    return ExpansionTile(
      leading: Text((dayIndex + 1).toString(), style: TextStyle(fontSize: 16, color: textColor)),
      title: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
      iconColor: color,
      collapsedIconColor: color,
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
      children: [
        _buildDetailRow("Status", kehadiranValue),
        // Tampilkan detail kehadiran jika statusnya "Hadir"
        if(isHadir) ...[
          _buildDetailRow("Jam Masuk", jamMasuk),
          _buildDetailRow("Jam Pulang", jamPulang),
          _buildDetailRow("Lokasi", lokasi),
        ],
        // Tampilkan detail izin jika statusnya "Izin / Sakit"
        if(isOnLeave && leaveRequest != null) ...[
          _buildDetailRow("Alasan", leaveRequest.reason),
          if (leaveRequest.attachmentPath != null)
             _buildDetailRow("Keterangan", leaveRequest.status),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('Riwayat Kehadiran'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Data tidak ditemukan."));
          }

          final allAttendances = snapshot.data!['attendances'] as List<LocalAttendance>;
          final approvedLeaves = snapshot.data!['approvedLeaves'] as List<LeaveRequest>;

          final DateFormat monthYearFormat = DateFormat('MMMM yyyy', 'id_ID');
          final DateTime firstDayOfMonth = monthYearFormat.parse(widget.monthName);
          final int daysInMonth = DateTime(firstDayOfMonth.year, firstDayOfMonth.month + 1, 0).day;
          final today = DateUtils.dateOnly(DateTime.now());
          final registrationDate = DateUtils.dateOnly(widget.user.registrationDate);

          return ListView.builder(
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final DateTime currentDay = DateTime(firstDayOfMonth.year, firstDayOfMonth.month, index + 1);
              final int weekday = currentDay.weekday;

              if (currentDay.isAfter(today) || currentDay.isBefore(registrationDate)) {
                return const SizedBox.shrink();
              }
              
              // Prioritas 1: Hari libur (Minggu) -> Menggunakan ListTile statis
              if (weekday == DateTime.sunday) {
                return ListTile(
                  leading: Text((index + 1).toString(), style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  title: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(currentDay), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                  trailing: const Text("Libur", style: TextStyle(fontSize: 15, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                );
              }

              // Prioritas 2: Ada catatan kehadiran (Check-in)
              final dailyAttendances = allAttendances.where((att) => DateUtils.isSameDay(att.timestamp, currentDay)).toList();
              if (dailyAttendances.isNotEmpty) {
                return _buildDayTile(dayIndex: index, date: currentDay, status: "Hadir", color: Colors.blue, dailyAttendances: dailyAttendances);
              }
              
              // [PERUBAHAN 2] Ubah logika izin untuk menggunakan _buildDayTile
              // Cek apakah hari ini tercover oleh izin yang disetujui
              final leaveRecord = approvedLeaves.firstWhereOrNull((leave) => 
                (currentDay.isAtSameMomentAs(leave.startDate) || currentDay.isAfter(leave.startDate)) &&
                (currentDay.isAtSameMomentAs(leave.endDate) || currentDay.isBefore(leave.endDate))
              );
              if (leaveRecord != null) {
                 return _buildDayTile(
                   dayIndex: index, 
                   date: currentDay, 
                   status: "Izin / Sakit", 
                   color: Colors.orange, 
                   leaveRequest: leaveRecord, // Kirim data izin ke tile
                 );
              }

              // Prioritas 4: Hari ini, tetapi belum ada data absen
              if (DateUtils.isSameDay(currentDay, today)) {
                return _buildDayTile(dayIndex: index, date: currentDay, status: "Belum Absen", color: Colors.grey, dailyAttendances: null);
              }

              // Prioritas 5 (Default): Hari kerja di masa lalu & tidak ada data = Alpa
              return _buildDayTile(dayIndex: index, date: currentDay, status: "Alpa / Tidak Hadir", color: Colors.red, dailyAttendances: null);
            },
          );
        },
      ),
    );
  }
}