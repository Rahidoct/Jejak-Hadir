import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../models/attendance_local.dart';

class MonthlyDetailScreen extends StatelessWidget {
  final String monthName;
  final List<LocalAttendance> attendances;

  const MonthlyDetailScreen({
    super.key,
    required this.monthName,
    required this.attendances,
  });

  static final List<DateTime> _nationalHolidays2025 = [
    DateTime(2025, 1, 1), DateTime(2025, 1, 27), DateTime(2025, 1, 29),
    DateTime(2025, 3, 29), DateTime(2025, 3, 30), DateTime(2025, 3, 31),
    DateTime(2025, 4, 18), DateTime(2025, 5, 1), DateTime(2025, 5, 12),
    DateTime(2025, 5, 29), DateTime(2025, 6, 1), DateTime(2025, 6, 6),
    DateTime(2025, 6, 26), DateTime(2025, 8, 17), DateTime(2025, 9, 5),
    DateTime(2025, 12, 25),
  ];

  bool _isNationalHoliday(DateTime date) {
    return _nationalHolidays2025.any((holiday) => DateUtils.isSameDay(holiday, date));
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

  Widget _buildHadirTile(int dayIndex, List<LocalAttendance> dailyAttendances) {
    final checkInRecord = dailyAttendances.firstWhereOrNull((att) => att.type == 'check_in');
    final checkOutRecord = dailyAttendances.firstWhereOrNull((att) => att.type == 'check_out');
    final jamMasuk = checkInRecord != null ? DateFormat('HH:mm:ss').format(checkInRecord.timestamp) : '-';
    final jamPulang = checkOutRecord != null ? DateFormat('HH:mm:ss').format(checkOutRecord.timestamp) : '-';
    final lokasi = checkInRecord != null ? '${checkInRecord.latitude.toStringAsFixed(4)}, ${checkInRecord.longitude.toStringAsFixed(4)}' : '-';
    
    return ExpansionTile(
      leading: Text((dayIndex + 1).toString(), style: const TextStyle(fontSize: 16, color: Colors.black54)),
      title: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dailyAttendances.first.timestamp), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
      iconColor: Colors.blue,
      collapsedIconColor: Colors.blue.shade700,
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
      children: [
        _buildDetailRow("Jenis Presensi", "Mobile"),
        _buildDetailRow("Kehadiran", "Hadir"),
        _buildDetailRow("Jam Masuk", jamMasuk),
        _buildDetailRow("Jam Pulang", jamPulang),
        _buildDetailRow("Lokasi", lokasi),
      ],
    );
  }

  Widget _buildStatusTile(int dayIndex, DateTime date, String status, Color color, IconData icon) {
    return ListTile(
      leading: Text((dayIndex + 1).toString(), style: const TextStyle(fontSize: 16, color: Colors.black54)),
      title: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, decoration: status == "Hari Libur" ? TextDecoration.lineThrough : TextDecoration.none, color: status == "Hari Libur" ? Colors.grey : Colors.black87)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final DateFormat monthYearFormat = DateFormat('MMMM yyyy', 'id_ID');
    final DateTime firstDayOfMonth = monthYearFormat.parse(monthName);
    final int daysInMonth = DateTime(firstDayOfMonth.year, firstDayOfMonth.month + 1, 0).day;
    final today = DateUtils.dateOnly(DateTime.now());

    final DateTime? firstAttendanceDate = attendances.isNotEmpty
        ? DateUtils.dateOnly(attendances.sortedBy((att) => att.timestamp).first.timestamp)
        : null;

    return Scaffold(
      appBar: AppBar(
        // --- [PERBAIKAN DI SINI] ---
        // Menambahkan `foregroundColor` akan mengubah warna semua ikon (termasuk tombol kembali)
        // dan teks default (termasuk judul) di dalam AppBar menjadi putih.
        foregroundColor: Colors.white,
        title: const Text('Detail Riwayat Kehadiran'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        itemCount: daysInMonth,
        itemBuilder: (context, index) {
          final DateTime currentDay = DateTime(firstDayOfMonth.year, firstDayOfMonth.month, index + 1);
          final int weekday = currentDay.weekday;

          final dailyAttendances = attendances.where((att) => DateUtils.isSameDay(att.timestamp, currentDay)).toList();
              
          if (weekday == DateTime.sunday || _isNationalHoliday(currentDay)) {
            return _buildStatusTile(index, currentDay, "Hari Libur", Colors.orange, Icons.weekend_outlined);
          }

          if (dailyAttendances.isNotEmpty) {
            return _buildHadirTile(index, dailyAttendances);
          }
          
          if (currentDay.isBefore(today)) {
            if (firstAttendanceDate != null && !currentDay.isBefore(firstAttendanceDate)) {
              return _buildStatusTile(index, currentDay, "Tidak Hadir", Colors.red, Icons.highlight_off_rounded);
            }
          }
          
          return _buildStatusTile(index, currentDay, "Belum ada data", Colors.grey, Icons.hourglass_empty_rounded);
        },
      ),
    );
  }
}