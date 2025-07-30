import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:collection/collection.dart';

import '../models/attendance_local.dart';
import '../services/local_storage_service.dart';
import 'monthly_detail_screen.dart';

// Diubah menjadi StatefulWidget agar bisa memuat ulang data secara dinamis
class HistoryScreenLocal extends StatefulWidget {
  final String userId;
  const HistoryScreenLocal({super.key, required this.userId});

  @override
  State<HistoryScreenLocal> createState() => _HistoryScreenLocalState();
}

class _HistoryScreenLocalState extends State<HistoryScreenLocal> {
  final LocalStorageService _localStorageService = LocalStorageService();
  // Gunakan Future sebagai variabel state
  late Future<List<LocalAttendance>> _attendancesFuture;
  
  int _selectedYear = DateTime.now().year; 
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    // Panggil future pertama kali saat widget dibuat
    _reloadData();
  }

  // --- [PERBAIKAN KRUSIAL DI SINI] ---
  // Metode ini akan dipanggil setiap kali pengguna kembali ke tab Riwayat,
  // memaksa data untuk dimuat ulang.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadData();
  }

  // Fungsi helper untuk memuat ulang data agar tidak duplikat kode
  void _reloadData() {
    if (mounted) {
      setState(() {
        _attendancesFuture = _localStorageService.getAttendancesByUserId(widget.userId);
      });
    }
  }
  // --- AKHIR PERBAIKAN ---

  Widget _buildYearFilter(List<LocalAttendance> allAttendances) {
    _availableYears = allAttendances
        .map((att) => att.timestamp.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); 

    if (_availableYears.isEmpty) {
      _availableYears.add(DateTime.now().year);
    }
    if (!_availableYears.contains(_selectedYear)) {
      _selectedYear = _availableYears.first;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Pilih Tahun:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          DropdownButton<int>(
            value: _selectedYear,
            items: _availableYears.map((int year) {
              return DropdownMenuItem<int>(
                value: year,
                child: Text(year.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              );
            }).toList(),
            onChanged: (int? newValue) {
              setState(() {
                _selectedYear = newValue!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<List<LocalAttendance>>(
        future: _attendancesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada riwayat absensi.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final allAttendances = snapshot.data!;
          final yearlyAttendances = allAttendances.where((att) => att.timestamp.year == _selectedYear).toList();
          
          final groupedByMonth = groupBy(
            yearlyAttendances,
            (LocalAttendance att) => DateFormat('MMMM', 'id_ID').format(att.timestamp),
          );
          
          final monthOrder = [
            'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
            'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
          ];
          final monthKeys = groupedByMonth.keys.toList()
            ..sort((a, b) => monthOrder.indexOf(a).compareTo(monthOrder.indexOf(b)));
          
          return Column(
            children: [
              _buildYearFilter(allAttendances),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: yearlyAttendances.isEmpty
                ? Center(child: Text("Tidak ada data untuk tahun $_selectedYear", style: const TextStyle(fontSize: 16, color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: monthKeys.length,
                    itemBuilder: (context, index) {
                      final monthName = monthKeys[index];
                      final monthlyAttendances = groupedByMonth[monthName]!;
                      final uniqueCheckInDays = monthlyAttendances.where((att) => att.type == 'check_in').map((att) => DateFormat('yyyy-MM-dd').format(att.timestamp)).toSet().length;
                      const sakitCount = 0;
                      const cutiCount = 0;
                      const dinasLuarCount = 0;
                      const tidakHadirCount = 0;
                      final jumlahHari = uniqueCheckInDays;

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MonthlyDetailScreen(
                                  monthName: "$monthName $_selectedYear",
                                  attendances: monthlyAttendances,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      monthName,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    _buildStatItem("Hadir", uniqueCheckInDays.toString()),
                                    _buildStatItem("Izin / Sakit", sakitCount.toString()),
                                    _buildStatItem("Cuti", cutiCount.toString()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildStatItem("Tidak Hadir", tidakHadirCount.toString()),
                                    _buildStatItem("Dinas Luar", dinasLuarCount.toString()),
                                    _buildStatItem("Jumlah Hari", jumlahHari.toString()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ),
            ],
          );
        },
      ),
    );
  }
}