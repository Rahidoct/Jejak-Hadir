// lib/screens/home_screen_local.dart

// Import libraries
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

// Import local files
import '../helpers/notification_helper.dart';
import '../models/leave_request_local.dart';
import '../models/attendance_local.dart';
import '../models/user_local.dart';
import '../services/local_storage_service.dart';

// Import screens
import 'leave_request_screen.dart';
import 'annual_leave_modal.dart';
import 'duty_leave_modal.dart';
import 'history_screen_local.dart';
import 'schedule_screen.dart';
import 'profile_screen.dart';

class HomeScreenLocal extends StatefulWidget {
  final LocalUser user;
  const HomeScreenLocal({super.key, required this.user});
  @override
  State<HomeScreenLocal> createState() => _HomeScreenLocalState();
}

class _HomeScreenLocalState extends State<HomeScreenLocal> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isProcessing = false;
  bool _hasCheckedInToday = false;
  bool _hasCheckedOutToday = false; 
  
  int _yearlyAttendanceCount = 0;
  int _yearlyLeaveCount = 0;
  int _yearlyAlphaCount = 0;
  int _yearlyCutiCount = 0;
  int _yearlyDutyCount = 0;

  int _historyKey = 0;
  final LocalStorageService _storageService = LocalStorageService();
  final Uuid _uuid = const Uuid();
  late LocalUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    WidgetsBinding.instance.addObserver(this);
    initializeDateFormatting('id_ID', null);
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadInitialData();
    }
  }
  
  Future<void> _loadInitialData() async {
    final updatedUser = await _storageService.getCurrentUser();
    if(updatedUser != null && mounted) {
      setState(() {
        _currentUser = updatedUser;
      });
    }
    await _loadLastAttendanceStatus();
    await _calculateYearlyStats();
  }

  Future<void> _loadLastAttendanceStatus() async {
    final attendances = await _storageService.getAttendancesByUserId(_currentUser.uid);
    final now = DateTime.now();
    final todayAttendances = attendances.where((att) => DateUtils.isSameDay(att.timestamp, now)).toList();
    if (mounted) {
      setState(() {
        _hasCheckedInToday = todayAttendances.any((att) => att.type == 'check_in');
        _hasCheckedOutToday = todayAttendances.any((att) => att.type == 'check_out');
      });
    }
  }

  // --- [PERBAIKAN UTAMA DI SINI] ---

  // [BARU] Fungsi helper untuk menghitung hari kerja (Senin - Sabtu)
  int _countWorkingDays(DateTime startDate, DateTime endDate) {
    int workingDays = 0;
    for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      // Hitung jika hari BUKAN Minggu
      if (day.weekday != DateTime.sunday) {
        workingDays++;
      }
    }
    return workingDays;
  }

  Future<void> _calculateYearlyStats() async {
    final now = DateTime.now();
    
    final allAttendances = await _storageService.getAttendancesByUserId(_currentUser.uid);
    final allLeaveRequests = await _storageService.getLeaveRequestsByUserId(_currentUser.uid);

    final yearlyAttendances = allAttendances.where((att) => att.timestamp.year == now.year);
    final yearlyLeaveRequests = allLeaveRequests.where((req) => req.startDate.year == now.year);

    final Set<String> hadirDays = yearlyAttendances
        .where((att) => att.type == 'check_in')
        .map((att) => DateFormat('yyyy-MM-dd').format(att.timestamp))
        .toSet();
    
    final approvedLeaves = yearlyLeaveRequests.where((req) => req.status == 'Disetujui');
    
    // [FIX] Gunakan fungsi helper untuk menghitung hari kerja
    int totalIzinSakitDays = 0;
    approvedLeaves.where((req) => req.requestType == 'Izin').forEach((leave) {
      totalIzinSakitDays += _countWorkingDays(leave.startDate, leave.endDate);
    });

    int totalCutiDays = 0;
    approvedLeaves.where((req) => req.requestType == 'Cuti').forEach((leave) {
      totalCutiDays += _countWorkingDays(leave.startDate, leave.endDate);
    });

    int totalDinasLuarDays = 0;
    approvedLeaves.where((req) => req.requestType == 'Dinas Luar').forEach((leave) {
      totalDinasLuarDays += _countWorkingDays(leave.startDate, leave.endDate);
    });

    // Kumpulkan semua hari yang tidak masuk kerja (selain alfa) untuk pengecualian
    final Set<String> allNonWorkingDays = {};
    for (var leave in approvedLeaves) {
      for (var day = leave.startDate; day.isBefore(leave.endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
          if (day.year == now.year && day.weekday != DateTime.sunday) {
            allNonWorkingDays.add(DateFormat('yyyy-MM-dd').format(day));
          }
      }
    }

    int alfaCount = 0;
    final today = DateUtils.dateOnly(DateTime.now());
    final registrationDate = DateUtils.dateOnly(_currentUser.registrationDate);
    DateTime startOfYear = DateTime(now.year, 1, 1);
    DateTime startDate = registrationDate.isAfter(startOfYear) ? registrationDate : startOfYear;

    for (var day = startDate; day.isBefore(today); day = day.add(const Duration(days: 1))) {
      if (day.weekday != DateTime.sunday) {
        String dayString = DateFormat('yyyy-MM-dd').format(day);
        if (!hadirDays.contains(dayString) && !allNonWorkingDays.contains(dayString)) {
          alfaCount++;
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _yearlyAttendanceCount = hadirDays.length;
        _yearlyLeaveCount = totalIzinSakitDays;
        _yearlyCutiCount = totalCutiDays;
        _yearlyDutyCount = totalDinasLuarDays;
        _yearlyAlphaCount = alfaCount;
      });
    }
  }

  Future<void> _performAttendance(String type) async {
    setState(() => _isProcessing = true);
    var status = await Permission.location.request();
    if (!status.isGranted) {
      setState(() => _isProcessing = false);
      // ignore: use_build_context_synchronously
      NotificationHelper.show(context, title: "Akses Ditolak", message: "Izin lokasi diperlukan.", type: NotificationType.error);
      return;
    }
    try {
      // ignore: deprecated_member_use
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final now = DateTime.now();
      final newAttendance = LocalAttendance(
        id: _uuid.v4(),
        userId: widget.user.uid,
        type: type,
        timestamp: now,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      await _storageService.addAttendance(newAttendance);
      setState(() { _historyKey++; });
      await _loadInitialData();

      if (type == 'check_in' && now.hour >= 8) {
        // ignore: use_build_context_synchronously
        NotificationHelper.show(context, title: "Astagfirullah!", message: "Jam segini baru datang? Hadeh! parah banget.", type: NotificationType.info);
      } else {
        // ignore: use_build_context_synchronously
        NotificationHelper.show(context, title: "Sipph!", message: "Absen ${type == 'check_in' ? 'masuk' : 'pulang'} berhasil dicatat.", type: NotificationType.success);
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      NotificationHelper.show(context, title: "Terjadi Kesalahan", message: "Gagal mendapatkan lokasi.", type: NotificationType.error);
    } finally {
      if(mounted) setState(() => _isProcessing = false);
    }
  }

  bool _isWithinCheckInWindow() {
    final now = DateTime.now();
    return now.hour >= 6 && now.hour < 10;
  }

  bool _isWithinCheckOutWindow() {
    final now = DateTime.now();
    return now.hour >= 14 && now.minute >= 30 && now.hour < 17;
  }

  void _showLeaveRequestModal() async {
    final result = await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => LeaveRequestModal(user: _currentUser));
    if (result == true && mounted) {
      NotificationHelper.show(context, title: "Berhasil Diajukan", message: "Pengajuan izin Anda telah berhasil dikirim.", type: NotificationType.success);
      _loadInitialData();
    }
  }

  void _showAnnualLeaveModal() async {
    final result = await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => AnnualLeaveModal(user: _currentUser));
    if (result == true && mounted) {
      NotificationHelper.show(context, title: "Cuti Diajukan", message: "Pengajuan cuti Anda telah berhasil dikirim.", type: NotificationType.success);
      _loadInitialData();
    }
  }

  void _showDutyLeaveModal() async {
    final result = await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DutyLeaveModal(user: _currentUser));
    if (result == true && mounted) {
      NotificationHelper.show(context, title: "Dinas Luar Diajukan", message: "Pengajuan Anda telah berhasil dikirim.", type: NotificationType.success);
      _loadInitialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildDashboardScreen(),
      HistoryScreenLocal(key: ValueKey(_historyKey), userId: _currentUser.uid, user: _currentUser),
      ScheduleScreen(user: _currentUser),
      ProfileScreen(user: _currentUser, onDataChanged: _loadInitialData),
    ];
    
    return Scaffold(
      appBar: AppBar(title: Text(_getAppBarTitle()), centerTitle: true, backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0 || index == 1) _loadInitialData();
          setState(() => _currentIndex = index);
        },
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

  Widget _buildDashboardScreen() {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 24),
            _buildAttendance(),
            const SizedBox(height: 24),
            _buildActionMenu(),
            const SizedBox(height: 24),
            _buildActivity(),
          ],
        ),
      ),
    );
  }

  Card _buildProfileCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(children: [
              CircleAvatar(radius: 30, backgroundColor: Colors.blue.shade100, child: Text(_currentUser.name.isNotEmpty ? _currentUser.name[0].toUpperCase() : '?', style: TextStyle(fontSize: 28, color: Colors.blue.shade800, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_currentUser.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('NIP: ${_currentUser.nip ?? '-'}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('PUSKESMAS BUNDER', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Jabatan', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text(_currentUser.position ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Golongan', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text(_currentUser.grade ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ])),
            ]),
            const Divider(height: 24, thickness: 1),
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem("Hadir", _yearlyAttendanceCount.toString(), Colors.green.shade700),
          _buildStatItem("Izin/Sakit", _yearlyLeaveCount.toString(), Colors.orange.shade700),
          _buildStatItem("Cuti", _yearlyCutiCount.toString(), Colors.blueGrey.shade700),
          _buildStatItem("Dinas Luar", _yearlyDutyCount.toString(), Colors.blue.shade700),
          _buildStatItem("Alfa", _yearlyAlphaCount.toString(), Colors.red.shade700),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }
  
  Widget _buildActionMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionMenuItem(icon: Icons.edit_calendar, label: 'Cuti', onTap: _showAnnualLeaveModal),
        _buildActionMenuItem(icon: Icons.card_travel, label: 'Dinas Luar', onTap: _showDutyLeaveModal),
        _buildActionMenuItem(icon: Icons.sick_outlined, label: 'Izin', onTap: _showLeaveRequestModal),
        _buildActionMenuItem(icon: Icons.home_work_outlined, label: 'WFH', onTap: () => NotificationHelper.show(context, title: 'Oopss..', message: 'Fitur ini hanya tersedia selama kondisi darurat maupun pandemi.', type: NotificationType.info)),
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
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.blue.shade800, size: 28)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Kegiatan Yang Diikuti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(16), child: const Center(child: Text('Belum ada jadwal kegiatan', style: TextStyle(color: Colors.grey)))),
      ],
    );
  }
  
  Widget _buildAttendance() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
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
    final today = DateUtils.dateOnly(now);

    return FutureBuilder<List<LeaveRequest>>(
      future: _storageService.getApprovedLeaveRequestsByUserId(_currentUser.uid),
      builder: (context, snapshot) {
        bool isCoveredByRequest = false;
        if (snapshot.hasData) {
          isCoveredByRequest = snapshot.data!.any((leave) => 
            !today.isBefore(leave.startDate) && !today.isAfter(leave.endDate));
        }

        if (isCoveredByRequest) {
          return const _StatusInfo(message: 'Anda saat ini cuti/izin/dinas luar.', icon: Icons.task_alt_outlined, color: Colors.grey);
        }
        if (now.weekday == DateTime.sunday) {
          return const _StatusInfo(message: 'Hari ini libur. Waktunya istirahat!', icon: Icons.weekend_outlined, color: Colors.blueGrey);
        }
        if (_hasCheckedInToday && _hasCheckedOutToday) {
          return const _StatusInfo(message: 'Absensi sudah selesai hari ini.', icon: Icons.check_circle_outline, color: Colors.green);
        }
        if (_hasCheckedInToday) {
          if (_isWithinCheckOutWindow()) {
            return ElevatedButton.icon(onPressed: () => _performAttendance('check_out'), icon: const Icon(Icons.logout), label: const Text('ABSEN PULANG'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
          } else {
            return const _StatusInfo(message: 'Absensi pulang dimulai jam 14:30.', icon: Icons.timer_outlined, color: Colors.orange);
          }
        }
        if (!_hasCheckedInToday) {
          if (_isWithinCheckInWindow()) {
            return ElevatedButton.icon(onPressed: () => _performAttendance('check_in'), icon: const Icon(Icons.login), label: const Text('ABSEN MASUK'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
          } 
          else if (now.hour >= 10) {
            return ElevatedButton.icon(onPressed: _showConfirmationDialog, icon: const Icon(Icons.edit_calendar_outlined), label: const Text('LUPA ABSEN'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
          } 
          else {
            return const _StatusInfo(message: 'Absensi masuk dimulai jam 06:00.', icon: Icons.timer_off_outlined, color: Colors.blue);
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _showConfirmationDialog() async {
    // Implementasi dialog konfirmasi lupa absen
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