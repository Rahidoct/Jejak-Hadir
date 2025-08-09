// lib/screens/monthly_detail_screen.dart

import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../models/attendance_local.dart';
import '../models/user_local.dart';
import '../models/leave_request_local.dart';
import '../services/local_storage_service.dart';

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

  Widget _buildDayTile({
    required int dayIndex,
    required DateTime date,
    required String status,
    required Color color,
    List<LocalAttendance>? dailyAttendances,
    LeaveRequest? leaveRequest,
  }) {
    String kehadiranValue = status;
    String jamMasuk = "-";
    String jamPulang = "-";
    String lokasi = "-";
    String leaveType = "-";
    String leaveReason = "-";
    String leaveStatus = "-";

    bool isHadir = status == "Hadir";
    bool isAlpa = status == "Alpa / Tidak Hadir";
    bool isOnLeave = status == "Izin / Sakit" || status == "Cuti" || status == "Dinas Luar";

    // ignore: unused_local_variable
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

    if (leaveRequest != null) {
      leaveType = leaveRequest.requestType;
      leaveReason = leaveRequest.reason;
      leaveStatus = leaveRequest.status;
      kehadiranValue = leaveRequest.requestType; 
    }

    return ExpansionTile(
      leading: Text((dayIndex + 1).toString(), style: TextStyle(fontSize: 16, color: textColor)),
      title: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
      iconColor: textColor,
      collapsedIconColor: textColor,
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
      children: [
        // Only show status row if NOT a leave day
        if (!isOnLeave) _buildDetailRow("Status", kehadiranValue),
        
        // Attendance details
        if(isHadir) ...[
          _buildDetailRow("Jam Masuk", jamMasuk),
          _buildDetailRow("Jam Pulang", jamPulang),
          _buildDetailRow("Lokasi", lokasi),
        ],
        
        // Leave details
        if(isOnLeave && leaveRequest != null) ...[
          _buildDetailRow("Status", leaveStatus),
          _buildDetailRow("Alasan", leaveReason),
          _buildDetailRow("Keterangan", leaveType),
          if (leaveRequest.attachmentPath != null && leaveRequest.attachmentPath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text("Lampiran", style: TextStyle(fontSize: 15, color: Colors.grey.shade700))),
                  const Text(":  ", style: TextStyle(fontSize: 15)),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAttachment(leaveRequest.attachmentPath!),
                      child: Text(
                        "Lihat File",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ]
      ],
    );
  }

  Future<void> _openAttachment(String filePath) async {
    try {
      if (await File(filePath).exists()) {
        if (Platform.isAndroid || Platform.isIOS) {
          await OpenFile.open(filePath);
        } else {
          final uri = Uri.file(filePath);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File lampiran tidak ditemukan')),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka lampiran: ${e.toString()}')),
      );
    }
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

              // pengecekan hari
              if (currentDay.isBefore(registrationDate)) {
                // Tetap sembunyikan tanggal sebelum registrasi
                return const SizedBox.shrink();
              }

              // Cek apakah hari ini adalah hari esok
              final isFutureDay = currentDay.isAfter(today);

              // Jika hari esok dan BUKAN cuti/izin/dinas luar yang disetujui, jangan tampilkan
              if (isFutureDay) {
                final hasApprovedLeave = approvedLeaves.any((leave) => 
                  !currentDay.isBefore(leave.startDate) && 
                  !currentDay.isAfter(leave.endDate) &&
                  leave.status == 'Disetujui' &&
                  (leave.requestType == 'Cuti' || 
                  leave.requestType == 'Izin / Sakit' || 
                  leave.requestType == 'Dinas Luar')
                );
                
                if (!hasApprovedLeave) {
                  return const SizedBox.shrink();
                }
              }
              
              // Prioritas 1: Hari libur (Minggu) -> Menggunakan ListTile statis
              if (weekday == DateTime.sunday) {
                return ListTile(
                  leading: Text((index + 1).toString(), style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  title: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(currentDay), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                  trailing: const Text("Libur", style: TextStyle(fontSize: 15, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                );
              }

              // Cek kehadiran
              final dailyAttendances = allAttendances.where((att) => DateUtils.isSameDay(att.timestamp, currentDay)).toList();
              if (dailyAttendances.isNotEmpty) {
                return _buildDayTile(
                  dayIndex: index,
                  date: currentDay,
                  status: "Hadir",
                  color: Colors.blue,
                  dailyAttendances: dailyAttendances,
                );
              }
              
              // Cek izin yang disetujui
              final leaveRecord = approvedLeaves.firstWhereOrNull((leave) => 
                !currentDay.isBefore(leave.startDate) && 
                !currentDay.isAfter(leave.endDate)
              );
              
              if (leaveRecord != null) {
                String statusText = "Izin / Sakit";
                Color statusColor = Colors.orange;
                
                // Sesuaikan teks status berdasarkan jenis izin
                if (leaveRecord.requestType == 'Cuti') {
                  statusText = "Cuti";
                  statusColor = Colors.blueGrey;
                } else if (leaveRecord.requestType == 'Dinas Luar') {
                  statusText = "Dinas Luar";
                  statusColor = Colors.blue;
                }
                
                return _buildDayTile(
                  dayIndex: index,
                  date: currentDay,
                  status: statusText,
                  color: statusColor,
                  leaveRequest: leaveRecord,
                );
              }

              // Hari ini belum absen
              if (DateUtils.isSameDay(currentDay, today)) {
                return _buildDayTile(
                  dayIndex: index,
                  date: currentDay,
                  status: "Belum Absen",
                  color: Colors.grey,
                );
              }

              // Alpa/Tidak Hadir
              return _buildDayTile(
                dayIndex: index,
                date: currentDay,
                status: "Alpa / Tidak Hadir",
                color: Colors.red,
              );
            },
          );
        },
      ),
    );
  }
}