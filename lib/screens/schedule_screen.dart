import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:jejak_hadir_app/models/user_local.dart';

class ScheduleScreen extends StatefulWidget {
  final LocalUser user;
  const ScheduleScreen({super.key, required this.user});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // State untuk mengelola kalender
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  // --- KERANGKA DATA JADWAL (DUMMY) ---
  // Di masa depan, data ini akan Anda isi dari API.
  // Kuncinya adalah DateTime (tanpa jam), nilainya adalah daftar acara (List<String>).
  late final Map<DateTime, List<String>> _events;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();

    // Inisialisasi data jadwal palsu untuk demonstrasi
    final today = DateUtils.dateOnly(DateTime.now());
    _events = {
      today: ['Rapat Koordinasi Bulanan'],
      today.add(const Duration(days: 3)): ['Kunjungan Dinas ke Kantor Cabang'],
      today.add(const Duration(days: 7)): ['Pelatihan Penggunaan Sistem Baru', 'Acara Tim Building'],
      today.subtract(const Duration(days: 5)): ['Presentasi Proyek X'],
    };
  }

  // Fungsi untuk mengambil daftar acara untuk hari tertentu
  List<String> _getEventsForDay(DateTime day) {
    // Menggunakan DateUtils.dateOnly untuk memastikan perbandingan tanggal akurat (tanpa jam)
    return _events[DateUtils.dateOnly(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // --- WIDGET KALENDER ---
          TableCalendar(
            locale: 'id_ID', // Menggunakan format bahasa Indonesia
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, // Sembunyikan tombol format (2 weeks, month)
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            // Logika untuk menandai hari yang memiliki acara
            eventLoader: _getEventsForDay,
            
            // Logika untuk memilih hari
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; // Update juga focusedDay
              });
            },
            
            // --- STYLING KALENDER ---
            calendarStyle: CalendarStyle(
              // Styling untuk "bulatan biru" (marker)
              markerDecoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
              ),
              // Styling untuk hari ini
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade200,
                shape: BoxShape.circle,
              ),
              // Styling untuk hari yang dipilih
              selectedDecoration: BoxDecoration(
                color: Colors.blue.shade400,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8.0),

          // --- DAFTAR ACARA UNTUK HARI YANG DIPILIH ---
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }

  // Widget untuk membangun daftar acara di bawah kalender
  Widget _buildEventList() {
    final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    if (selectedEvents.isEmpty) {
      return const Center(
        child: Text(
          "Tidak ada jadwal kegiatan.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: selectedEvents.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: ListTile(
            leading: const Icon(Icons.event_note, color: Colors.blue),
            title: Text(selectedEvents[index]),
          ),
        );
      },
    );
  }
}