import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../models/attendance_local.dart';
import '../models/user_local.dart';

class MonthlyDetailScreen extends StatelessWidget {
  final String monthName;
  final List<LocalAttendance> attendances;
  final LocalUser user; 

  const MonthlyDetailScreen({
    super.key,
    required this.monthName,
    required this.attendances,
    required this.user,
  });

  static final List<DateTime> _nationalHolidays2025 = [
    DateTime(2025, 1, 1), DateTime(2025, 1, 27), DateTime(2025, 1, 29),
    DateTime(2025, 3, 29), DateTime(2025, 3, 30), DateTime(2025, 3, 31),
    DateTime(2025, 4, 18), DateTime(2025, 5, 1), DateTime(2025, 5, 12),
    DateTime(2025, 5, 29), DateTime(2025, 6, 1), DateTime(2025, 6, 6),
    DateTime(2025, 6, 26), DateTime(2025, 8, 17), DateTime(2025, 9, 5),
    DateTime(2025, 12, 25),
  ];

  // ignore: unused_element
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

  // --- [BARU] Fungsi Tunggal untuk Membangun Semua Jenis Tile ---
  Widget _buildDayTile({
    required int dayIndex,
    required DateTime date,
    required String status,
    required Color color,
    required List<LocalAttendance>? dailyAttendances,
  }) {
    String kehadiranValue = status;
    String jamMasuk = "-";
    String jamPulang = "-";
    String lokasi = "-";

    bool isHadir = status == "Hadir";
    bool isAlpa = status == "Alpa / Tidak Hadir";

    if (isHadir && dailyAttendances != null) {
      final checkInRecord = dailyAttendances.firstWhereOrNull((att) => att.type == 'check_in');
      final checkOutRecord = dailyAttendances.firstWhereOrNull((att) => att.type == 'check_out');
      jamMasuk = checkInRecord != null ? DateFormat('HH:mm:ss').format(checkInRecord.timestamp) : '-';
      jamPulang = checkOutRecord != null ? DateFormat('HH:mm:ss').format(checkOutRecord.timestamp) : '-';
      lokasi = checkInRecord != null ? '${checkInRecord.latitude.toStringAsFixed(4)}, ${checkInRecord.longitude.toStringAsFixed(4)}' : '-';
    }

    return ExpansionTile(
      leading: Text(
        (dayIndex + 1).toString(),
        style: TextStyle(
          fontSize: 16,
          color: isAlpa
              ? Colors.red
              : isHadir
                  ? Colors.blue
                  : Colors.black87,
        ),
      ),
      title: Text(
        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isAlpa
              ? Colors.red
              : isHadir
                  ? Colors.blue
                  : Colors.black87,
        ),
      ),

      // Tampilkan status kehadiran
      iconColor: color,
      collapsedIconColor: color,
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
      // Anak-anak yang akan ditampilkan saat tile dibuka
      children: [
        _buildDetailRow("Jenis Presensi", "Mobile"),
        _buildDetailRow("Kehadiran", kehadiranValue),
        // Tampilkan detail Jam Masuk, Pulang, dan Lokasi HANYA JIKA HADIR
        if(isHadir) ...[
          _buildDetailRow("Jam Masuk", jamMasuk),
          _buildDetailRow("Jam Pulang", jamPulang),
          _buildDetailRow("Lokasi", lokasi),
        ]
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final DateFormat monthYearFormat = DateFormat('MMMM yyyy', 'id_ID');
    final DateTime firstDayOfMonth = monthYearFormat.parse(monthName);
    final int daysInMonth = DateTime(firstDayOfMonth.year, firstDayOfMonth.month + 1, 0).day;
    final today = DateUtils.dateOnly(DateTime.now());
    final registrationDate = DateUtils.dateOnly(user.registrationDate);

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('Riwayat Kehadiran'),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        itemCount: daysInMonth,
        itemBuilder: (context, index) {
          final DateTime currentDay = DateTime(firstDayOfMonth.year, firstDayOfMonth.month, index + 1);
          final int weekday = currentDay.weekday;

          // Kondisi 1 & 2: Sembunyikan hari di masa depan atau sebelum pendaftaran
          if (currentDay.isAfter(today) || currentDay.isBefore(registrationDate)) {
            return const SizedBox.shrink();
          }

          final dailyAttendances = attendances.where((att) => DateUtils.isSameDay(att.timestamp, currentDay)).toList();
              
          // Kondisi 3: Cek Hari Libur
          if (weekday == DateTime.sunday) {
            // Kita tidak bisa memperluas tile ini, jadi kita gunakan ListTile statis
            return ListTile(
                leading: Text((index + 1).toString(), style: const TextStyle(fontSize: 16, color: Colors.black54)),
                title: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(currentDay), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                trailing: const Text("Libur", style: TextStyle(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold)),
              );
          }

          // Kondisi 4: Cek jika ada data absensi (Hadir)
          if (dailyAttendances.isNotEmpty) {
            return _buildDayTile(
              dayIndex: index,
              date: currentDay,
              status: "Hadir",
              color: Colors.blue,
              dailyAttendances: dailyAttendances
            );
          }
          
          // Kondisi 5: Cek jika HARI INI dan belum ada data
          if (DateUtils.isSameDay(currentDay, today)) {
            return _buildDayTile(
              dayIndex: index,
              date: currentDay,
              status: "Belum Absen",
              color: Colors.grey,
              dailyAttendances: null
            );
          }

          // Kondisi 6: Hari kerja di masa lalu dan tidak ada data
          return _buildDayTile(
            dayIndex: index,
            date: currentDay,
            status: "Alpa / Tidak Hadir",
            color: Colors.red,
            dailyAttendances: null
          );
        },
      ),
    );
  }
}