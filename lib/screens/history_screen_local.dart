// lib/screens/history_screen_local.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jejak_hadir_app/models/leave_request_local.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import '../models/attendance_local.dart';
import '../services/local_storage_service.dart';
import 'monthly_detail_screen.dart';

class HistoryScreenLocal extends StatefulWidget {
  final String userId;
  final LocalUser user; 

  const HistoryScreenLocal({
    super.key, 
    required this.userId, 
    required this.user,
  });

  @override
  State<HistoryScreenLocal> createState() => _HistoryScreenLocalState();
}

class _HistoryScreenLocalState extends State<HistoryScreenLocal> {
  final LocalStorageService _localStorageService = LocalStorageService();
  late Future<Map<String, dynamic>> _summaryDataFuture;
  
  int _selectedYear = DateTime.now().year; 
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _reloadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadData();
  }

  void _reloadData() {
    if (mounted) {
      setState(() {
        _summaryDataFuture = _loadSummaryData();
      });
    }
  }

  Future<Map<String, dynamic>> _loadSummaryData() async {
    final attendances = await _localStorageService.getAttendancesByUserId(widget.userId);
    final leaveRequests = await _localStorageService.getLeaveRequestsByUserId(widget.userId);
    return {
      'attendances': attendances,
      'leaveRequests': leaveRequests,
    };
  }

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
                _reloadData();
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Tidak ada data."));
          }

          final allAttendances = snapshot.data!['attendances'] as List<LocalAttendance>;
          final allLeaveRequests = snapshot.data!['leaveRequests'] as List<LeaveRequest>;

          final monthOrder = [ 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember' ];
          
          return Column(
            children: [
              _buildYearFilter(allAttendances),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: 12, 
                    itemBuilder: (context, index) {
                      final monthNumber = index + 1;
                      final monthName = monthOrder[index];
                      
                      final monthlyAttendances = allAttendances.where((att) => att.timestamp.month == monthNumber && att.timestamp.year == _selectedYear).toList();
                      final monthlyLeaveRequests = allLeaveRequests.where((req) => (req.startDate.month == monthNumber || req.endDate.month == monthNumber) && req.startDate.year == _selectedYear).toList();
                      
                      if (monthlyAttendances.isEmpty && monthlyLeaveRequests.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      // --- [PERBAIKAN KUNCI] Logika Kalkulasi Akurat per Bulan ---
                      
                      final Set<String> hadirDays = monthlyAttendances
                          .where((att) => att.type == 'check_in')
                          .map((att) => DateFormat('yyyy-MM-dd').format(att.timestamp))
                          .toSet();
                      
                      final approvedLeaves = monthlyLeaveRequests.where((req) => req.status == 'Disetujui');

                      final Set<String> allNonWorkingDays = {};
                      for (var leave in approvedLeaves) {
                        for (var day = leave.startDate; day.isBefore(leave.endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
                          // Hanya tambahkan hari yang berada di bulan dan tahun yang relevan, dan bukan hari Minggu
                          if (day.month == monthNumber && day.year == _selectedYear && day.weekday != DateTime.sunday) {
                            allNonWorkingDays.add(DateFormat('yyyy-MM-dd').format(day));
                          }
                        }
                      }
                      
                      // Pisahkan lagi untuk hitungan per kategori
                      final izinSakitDays = allNonWorkingDays.where((dayStr) {
                        final day = DateTime.parse(dayStr);
                        return approvedLeaves.any((l) => l.requestType == 'Izin' && !day.isBefore(l.startDate) && !day.isAfter(l.endDate));
                      }).toSet();

                      final cutiDays = allNonWorkingDays.where((dayStr) {
                        final day = DateTime.parse(dayStr);
                        return approvedLeaves.any((l) => l.requestType == 'Cuti' && !day.isBefore(l.startDate) && !day.isAfter(l.endDate));
                      }).toSet();

                      final dinasLuarDays = allNonWorkingDays.where((dayStr) {
                        final day = DateTime.parse(dayStr);
                        return approvedLeaves.any((l) => l.requestType == 'Dinas Luar' && !day.isBefore(l.startDate) && !day.isAfter(l.endDate));
                      }).toSet();

                      int alfaCount = 0;
                      final daysInMonth = DateTime(_selectedYear, monthNumber + 1, 0).day;
                      final today = DateUtils.dateOnly(DateTime.now());
                      final registrationDate = DateUtils.dateOnly(widget.user.registrationDate);

                      for (int i = 1; i <= daysInMonth; i++) {
                        DateTime currentDay = DateTime(_selectedYear, monthNumber, i);
                        if (currentDay.isAfter(today) || currentDay.isBefore(registrationDate)) {
                          continue;
                        }
                        
                        if (currentDay.weekday != DateTime.sunday) {
                          String dayString = DateFormat('yyyy-MM-dd').format(currentDay);
                          if (!hadirDays.contains(dayString) && !allNonWorkingDays.contains(dayString)) {
                            alfaCount++;
                          }
                        }
                      }

                      final int hadirCount = hadirDays.length;
                      final int izinCount = izinSakitDays.length;
                      final int cutiCount = cutiDays.length;
                      final int dinasLuarCount = dinasLuarDays.length;
                      final int tidakHadirCount = alfaCount;
                      final int jumlahHari = hadirCount + izinCount + cutiCount + dinasLuarCount + tidakHadirCount;
                      
                      // Jangan tampilkan card jika tidak ada aktivitas sama sekali
                      if (jumlahHari == 0) return const SizedBox.shrink();

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
                                  user: widget.user,
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
                                    Text(monthName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    _buildStatItem("Hadir", hadirCount.toString()),
                                    _buildStatItem("Izin / Sakit", izinCount.toString()),
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