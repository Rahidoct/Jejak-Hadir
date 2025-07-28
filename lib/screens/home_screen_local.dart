import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jejak_hadir_app/models/attendance_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/user_local.dart';
import 'history_screen_local.dart';
import 'schedule_screen.dart';
import 'profile_screen.dart';

class HomeScreenLocal extends StatefulWidget {
  final LocalUser user;
  const HomeScreenLocal({super.key, required this.user});

  @override
  State<HomeScreenLocal> createState() => _HomeScreenLocalState();
}

class _HomeScreenLocalState extends State<HomeScreenLocal> {
  int _currentIndex = 0;
  bool _isProcessing = false;
  bool _hasCheckedInToday = false;
  bool _hasCheckedOutToday = false; 
  int _monthlyAttendanceCount = 0;
  
  final int _leaveCount = 0;
  final int _dutyCount = 0;
  final int _alphaCount = 0;

  late final List<Widget> _screens;
  final LocalStorageService _storageService = LocalStorageService();
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    
    _screens = [
      _buildDashboardScreen(),
      HistoryScreenLocal(userId: widget.user.uid),
      ScheduleScreen(user: widget.user),
      ProfileScreen(user: widget.user),
    ];

    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    await _loadLastAttendanceStatus();
    await _calculateMonthlyStats();
  }

  Future<void> _loadLastAttendanceStatus() async {
    final attendances = await _storageService.getAttendancesByUserId(widget.user.uid);
    final now = DateTime.now();
    final todayAttendances = attendances.where((att) => 
        att.timestamp.year == now.year &&
        att.timestamp.month == now.month &&
        att.timestamp.day == now.day
    ).toList();
    if (mounted) {
      setState(() {
        _hasCheckedInToday = todayAttendances.any((att) => att.type == 'check_in');
        _hasCheckedOutToday = todayAttendances.any((att) => att.type == 'check_out');
      });
    }
  }

  Future<void> _calculateMonthlyStats() async {
    final now = DateTime.now();
    final allAttendances = await _storageService.getAttendancesByUserId(widget.user.uid);
    final monthlyCheckIns = allAttendances.where((att) {
      return att.type == 'check_in' &&
             att.timestamp.month == now.month &&
             att.timestamp.year == now.year;
    }).toList();
    final uniqueDays = <String>{};
    for (var att in monthlyCheckIns) {
      uniqueDays.add(DateFormat('yyyy-MM-dd').format(att.timestamp));
    }
    if (mounted) {
      setState(() {
        _monthlyAttendanceCount = uniqueDays.length;
      });
    }
  }

  Future<void> _performAttendance(String type) async {
    setState(() => _isProcessing = true);
    
    var status = await Permission.location.request();
    if (!status.isGranted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi diperlukan untuk absensi.')));
      setState(() => _isProcessing = false);
      return;
    }

    try {
      // ignore: deprecated_member_use
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final newAttendance = LocalAttendance(id: _uuid.v4(), userId: widget.user.uid, type: type, timestamp: DateTime.now(), latitude: position.latitude, longitude: position.longitude);
      await _storageService.addAttendance(newAttendance);
      
      await _loadInitialData();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sipph absen ${type == 'check_in' ? 'masuk' : 'pulang'}, berhasil!')));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mendapatkan lokasi: $e')));
    } finally {
      if(mounted) setState(() => _isProcessing = false);
    }
  }

  bool _isWithinCheckInWindow() {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 6, 0);
    final endTime = DateTime(now.year, now.month, now.day, 10, 0);
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  bool _isWithinCheckOutWindow() {
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 14, 30);
    final endTime = DateTime(now.year, now.month, now.day, 17, 0);
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  Future<void> _showConfirmationDialog(String type) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Ajukan Konfirmasi ${type == 'check_in' ? 'Hadir' : 'Pulang'}'),
          content: const Text('Fitur ini sedang dalam pengembangan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showActionDialog(String title) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pengajuan $title'),
          content: Text('Fitur untuk mengajukan $title sedang dalam pengembangan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _screens[0] = _buildDashboardScreen();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 2,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.blue,
        selectedItemColor: Colors.blue.shade900,
        unselectedItemColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note), label: 'Jadwal'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0: return 'DASHBOARD';
      case 1: return 'JEJAK KEHADIRAN';
      case 2: return 'JADWAL KEGIATAN';
      case 3: return 'PROFIL PENGGUNA';
      default: return 'JEJAK HADIR';
    }
  }

  // --- [PERBAIKAN UTAMA DI SINI] ---
  // Urutan widget di dalam Column diatur ulang sesuai keinginan.
  Widget _buildDashboardScreen() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Profil & Statistik
          _buildProfileCard(),
          const SizedBox(height: 24),

          // 2. Card untuk tombol absensi
          _buildAttendance(formattedDate),
          const SizedBox(height: 24),

          // 3. Menu Aksi Cepat dengan Ikon-ikon
          _buildActionMenu(),
          const SizedBox(height: 24),
          
          // 4. Card untuk kegiatan
          _buildActivity(),
        ],
      ),
    );
  }
  // --- [AKHIR PERBAIKAN] ---

  Card _buildProfileCard() {
    return Card(
      elevation: 4, // Sedikit dinaikkan agar lebih menonjol
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?', style: TextStyle(fontSize: 28, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('NIP: ${widget.user.nip ?? '-'}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text('PUSKESMAS BUNDER', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Jarak dikurangi sedikit
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Jabatan', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  Text(widget.user.position ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Golongan', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  Text(widget.user.grade ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ])),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem("Hadir", _monthlyAttendanceCount.toString(), Colors.green.shade700),
        _buildStatItem("Cuti", _leaveCount.toString(), Colors.orange.shade700),
        _buildStatItem("Dinas Luar", _dutyCount.toString(), Colors.blue.shade700),
        _buildStatItem("Alfa", _alphaCount.toString(), Colors.red.shade700),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }
  
  Widget _buildActionMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionMenuItem(icon: Icons.edit_calendar, label: 'Cuti', onTap: () => _showActionDialog('Cuti')),
        _buildActionMenuItem(icon: Icons.card_travel, label: 'Dinas Luar', onTap: () => _showActionDialog('Dinas Luar')),
        _buildActionMenuItem(icon: Icons.sick_outlined, label: 'Izin', onTap: () => _showActionDialog('Izin')),
        _buildActionMenuItem(icon: Icons.home_work_outlined, label: 'WFH', onTap: () => _showActionDialog('WFH')),
      ],
    );
  }

  Widget _buildActionMenuItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.blue.shade800, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // Card _buildActivityCard() {
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text('Kegiatan yang diikuti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //           const SizedBox(height: 16),
  //           Container(
  //             padding: const EdgeInsets.all(16),
  //             decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
  //             child: const Center(child: Text('Belum ada jadwal kegiatan', style: TextStyle(color: Colors.grey))),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Kegiatan Yang Diikuti',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Jika belum ada jadwal kegiatan, tampilkan pesan
        Container(
          width: double.infinity, // Memastikan container mengambil lebar penuh
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: Text(
              'Belum ada jadwal kegiatan',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
  
  // Card _buildAttendanceCard(String formattedDate) {
  //   return Card(
  //     elevation: 4, 
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.stretch,
  //         children: [
  //           Text(formattedDate, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  //           const SizedBox(height: 16),
  //           if (_isProcessing)
  //             const Center(child: CircularProgressIndicator())
  //           else
  //             _buildAttendanceActionWidget(),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildAttendance(String formattedDate) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(formattedDate, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            _buildAttendanceActionWidget(),
        ],
      ),
    );
  }
  
  Widget _buildAttendanceActionWidget() {
    final now = DateTime.now();

    if (_hasCheckedInToday && _hasCheckedOutToday) {
      return const _StatusInfo(message: 'Anda sudah menyelesaikan absensi hari ini.', icon: Icons.check_circle_outline, color: Colors.green);
    }

    if (_hasCheckedInToday) {
      if (_isWithinCheckOutWindow()) {
        return ElevatedButton.icon(
          onPressed: () => _performAttendance('check_out'),
          icon: const Icon(Icons.logout),
          label: const Text('ABSEN PULANG'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        );
      } else {
        return const _StatusInfo(message: 'Waktu absensi pulang jam 14:30 - 17:00.', icon: Icons.timer_outlined, color: Colors.orange);
      }
    }

    if (!_hasCheckedInToday) {
      if (_isWithinCheckInWindow()) {
        return ElevatedButton.icon(
          onPressed: () => _performAttendance('check_in'),
          icon: const Icon(Icons.login),
          label: const Text('ABSEN MASUK'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        );
      } 
      else if (now.hour >= 10) {
        return ElevatedButton.icon(
          onPressed: () => _showConfirmationDialog('check_in'),
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('LUPA ABSEN'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        );
      } 
      else {
        return const _StatusInfo(message: 'Waktu absensi masuk jam 06:00 - 10:00.', icon: Icons.timer_off_outlined, color: Colors.grey);
      }
    }

    return const SizedBox.shrink();
  }
}

class _StatusInfo extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  const _StatusInfo({required this.message, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      // ignore: deprecated_member_use
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(message, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}