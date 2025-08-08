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

  @override
  void initState() {
    super.initState();
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
    await _loadLastAttendanceStatus();
    await _calculateYearlyStats();
  }

  Future<void> _loadLastAttendanceStatus() async {
    final attendances = await _storageService.getAttendancesByUserId(widget.user.uid);
    final now = DateTime.now();
    final todayAttendances = attendances.where((att) => DateUtils.isSameDay(att.timestamp, now)).toList();
    if (mounted) {
      setState(() {
        _hasCheckedInToday = todayAttendances.any((att) => att.type == 'check_in');
        _hasCheckedOutToday = todayAttendances.any((att) => att.type == 'check_out');
      });
    }
  }

  Future<void> _calculateYearlyStats() async {
    final now = DateTime.now();
    
    final allAttendances = await _storageService.getAttendancesByUserId(widget.user.uid);
    final allLeaveRequests = await _storageService.getLeaveRequestsByUserId(widget.user.uid);

    // Filter data tahun ini
    final yearlyAttendances = allAttendances.where((att) => att.timestamp.year == now.year);
    final yearlyLeaveRequests = allLeaveRequests.where((req) => req.startDate.year == now.year);

    // Kumpulkan hari-hari hadir
    final Set<String> hadirDays = yearlyAttendances
        .where((att) => att.type == 'check_in')
        .map((att) => DateFormat('yyyy-MM-dd').format(att.timestamp))
        .toSet();
    
    // Kumpulkan hari-hari izin/sakit yang disetujui
    final Set<String> izinSakitDays = {};
    final approvedLeaves = yearlyLeaveRequests.where((req) => req.status == 'Disetujui');
    for (var leave in approvedLeaves) {
      DateTime day = leave.startDate;
      while (day.isBefore(leave.endDate.add(const Duration(days: 1)))) {
        if (day.year == now.year) {
          izinSakitDays.add(DateFormat('yyyy-MM-dd').format(day));
        }
        day = day.add(const Duration(days: 1));
      }
    }
    izinSakitDays.removeAll(hadirDays);

    int alfaCount = 0;
    final today = DateUtils.dateOnly(DateTime.now());
    final registrationDate = DateUtils.dateOnly(widget.user.registrationDate);

    DateTime startOfYear = DateTime(now.year, 1, 1);
    DateTime startDate = registrationDate.isAfter(startOfYear) ? registrationDate : startOfYear;

    // PERBAIKAN UTAMA: Hitung hari kerja (Senin-Sabtu) yang belum terisi
    DateTime currentDay = startDate;
    while (currentDay.isBefore(today)) {
      // Skip hari Minggu dan hari sebelum tanggal registrasi
      if (currentDay.weekday != DateTime.sunday && !currentDay.isBefore(registrationDate)) {
        String dayString = DateFormat('yyyy-MM-dd').format(currentDay);

        // Dianggap ALPA jika:
        // 1. Hari kerja (bukan Minggu)
        // 2. Tidak tercatat hadir
        // 3. Tidak ada izin/sakit
        if (!hadirDays.contains(dayString) && !izinSakitDays.contains(dayString)) {
          alfaCount++;
        }
      }
      currentDay = currentDay.add(const Duration(days: 1));
    }

    if (mounted) {
      setState(() {
        _yearlyAttendanceCount = hadirDays.length;
        _yearlyLeaveCount = izinSakitDays.length;
        _yearlyAlphaCount = alfaCount;
        _yearlyCutiCount = 0;
        _yearlyDutyCount = 0;
      });
    }
  }

  Future<void> _performAttendance(String type) async {
    setState(() => _isProcessing = true);
    
    var status = await Permission.location.request();
    if (!status.isGranted) {
      setState(() => _isProcessing = false);
      // ignore: use_build_context_synchronously
      NotificationHelper.show(context, title: "Akses Ditolak", message: "Izin lokasi diperlukan untuk absensi.", type: NotificationType.error);
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
      NotificationHelper.show(context, title: "Terjadi Kesalahan", message: "Gagal mendapatkan lokasi. Pastikan GPS aktif.", type: NotificationType.error);
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
    showDialog(context: context, builder: (context) => AlertDialog(
        title: Text('Ajukan Konfirmasi ${type == 'check_in' ? 'Hadir' : 'Pulang'}'),
        content: const Text('Fitur ini sedang dalam pengembangan.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  void _showActionDialog(String title) {
    showDialog(context: context, builder: (context) => AlertDialog(
        title: Text('Pengajuan $title'),
        content: Text('Fitur untuk mengajukan $title sedang dalam pengembangan.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildDashboardScreen(),
      HistoryScreenLocal(key: ValueKey(_historyKey), userId: widget.user.uid, user: widget.user),
      ScheduleScreen(user: widget.user),
      ProfileScreen(user: widget.user, onDataChanged: () {  },),
    ];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 2,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0 || index == 1) {
            _loadInitialData();
          }
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
      case 1: return 'RIWAYAT KEHADIRAN';
      case 2: return 'JADWAL KEGIATAN';
      case 3: return 'PROFIL PENGGUNA';
      default: return 'JEJAK HADIR';
    }
  }

  Widget _buildDashboardScreen() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    
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
            _buildAttendance(formattedDate),
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
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.shade100,
                child: Text(widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?', style: TextStyle(fontSize: 28, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('NIP: ${widget.user.nip ?? '-'}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('PUSKESMAS BUNDER', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Jabatan', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text(widget.user.position ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Golongan', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                Text(widget.user.grade ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
          _buildStatItem("Izin/Sakit", _yearlyLeaveCount.toString(), Colors.blueGrey.shade700),
          _buildStatItem("Cuti", _yearlyCutiCount.toString(), Colors.orange.shade700),
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
  
  void _showLeaveRequestModal() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => LeaveRequestModal(user: widget.user),
    );

    if (result == true && mounted) {
      NotificationHelper.show(context, title: "Berhasil Diajukan", message: "Pengajuan izin Anda telah berhasil dikirim.", type: NotificationType.success);
      _loadInitialData();
    }
  }

  Widget _buildActionMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionMenuItem(icon: Icons.edit_calendar, label: 'Cuti', onTap: () => _showActionDialog('Cuti')),
        _buildActionMenuItem(icon: Icons.card_travel, label: 'Dinas Luar', onTap: () => _showActionDialog('Dinas Luar')),
        _buildActionMenuItem(icon: Icons.sick_outlined, label: 'Izin', onTap: _showLeaveRequestModal),
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

  Widget _buildActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Kegiatan Yang Diikuti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: Text('Belum ada jadwal kegiatan', style: TextStyle(color: Colors.grey)),
          ),
        ),
      ],
    );
  }
  
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
    final today = DateUtils.dateOnly(now);

    // We'll need to make this widget build method handle async data
    return FutureBuilder<List<LeaveRequest>>(
      future: _storageService.getLeaveRequestsByUserId(widget.user.uid),
      builder: (context, snapshot) {
        // Check if today is a leave/sick day that has been approved
        bool isApprovedLeaveToday = false;
        if (snapshot.hasData) {
          for (var leave in snapshot.data!) {
            if (leave.status == 'Disetujui' && 
                !today.isBefore(leave.startDate) && 
                !today.isAfter(leave.endDate)) {
              isApprovedLeaveToday = true;
              break;
            }
          }
        }

        if (isApprovedLeaveToday) {
          return const _StatusInfo(
            message: 'Pengajuan izin / sakit disetujui.', 
            icon: Icons.assignment_turned_in_outlined, 
            color: Colors.blue
          );
        }

        if (now.weekday == DateTime.sunday) {
          return const _StatusInfo(message: 'Hari ini libur. Waktunya istirahat!', icon: Icons.weekend_outlined, color: Colors.blueGrey);
        }

        if (_hasCheckedInToday && _hasCheckedOutToday) {
          return const _StatusInfo(message: 'Absensi sudah selesai hari ini.', icon: Icons.check_circle_outline, color: Colors.green);
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
            return const _StatusInfo(message: 'Absensi pulang dimulai jam 14:30.', icon: Icons.timer_outlined, color: Colors.orange);
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
            return const _StatusInfo(message: 'Absensi masuk dimulai jam 06:00.', icon: Icons.timer_off_outlined, color: Colors.grey);
          }
        }

        return const SizedBox.shrink();
      },
    );
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