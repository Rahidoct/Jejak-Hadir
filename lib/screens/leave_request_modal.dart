// lib/screens/leave_request_modal.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:jejak_hadir_app/models/leave_request_local.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class LeaveRequestModal extends StatefulWidget {
  final LocalUser user;
  const LeaveRequestModal({super.key, required this.user});

  @override
  State<LeaveRequestModal> createState() => _LeaveRequestModalState();
}

class _LeaveRequestModalState extends State<LeaveRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  File? _pickedFile;
  bool _isLoading = false;

  // Fungsi untuk memilih rentang tanggal
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      helpText: 'Pilih Rentang Tanggal Izin/Sakit',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }
  
  // [BARU] Fungsi terpusat untuk mengambil gambar
  Future<void> _pickAttachment(ImageSource source) async {
    XFile? pickedXFile;
    if (source == ImageSource.camera) {
      pickedXFile = await ImagePicker().pickImage(source: ImageSource.camera);
    } else {
      // Untuk galeri, kita bisa tetap pakai file_picker agar bisa memilih file selain gambar
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        pickedXFile = XFile(result.files.single.path!);
      }
    }

    if (pickedXFile != null) {
      setState(() {
        _pickedFile = File(pickedXFile!.path);
      });
    }
  }

  // [BARU] Fungsi untuk menampilkan pilihan
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Ambil Foto dari Kamera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri/File'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDateRange == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih tanggal terlebih dahulu.'))
        );
        return;
      }
      
      setState(() => _isLoading = true);

      final newRequest = LeaveRequest(
        id: const Uuid().v4(),
        userId: widget.user.uid,
        requestType: 'Izin', 
        startDate: _selectedDateRange!.start,
        endDate: _selectedDateRange!.end,    
        reason: _reasonController.text,
        status: 'Diajukan',
        submittedDate: DateTime.now(),
        attachmentPath: _pickedFile?.path,
      );

      await LocalStorageService().addLeaveRequest(newRequest);
      
      if (mounted) {
        Navigator.pop(context, true); 
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 20
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Form Pengajuan Izin/Sakit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildDateRangeSelector(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: _inputDecoration('Alasan', 'Contoh: Sakit demam'),
                validator: (val) => val!.isEmpty ? 'Alasan tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                // [GANTI] Panggil fungsi untuk menampilkan pilihan
                onPressed: _showAttachmentOptions, 
                icon: const Icon(Icons.upload_file),
                label: Text(_pickedFile == null ? 'Unggah Bukti' : 'Ganti Bukti'),
                style: _outlineButtonStyle(),
              ),
              if (_pickedFile != null) ...[
                const SizedBox(height: 8),
                Text('File: ${_pickedFile!.path.split('/').last}', style: const TextStyle(color: Colors.green)),
              ],
              
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white, 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('AJUKAN SEKARANG'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    String displayText;
    if (_selectedDateRange == null) {
      displayText = 'Pilih Tanggal';
    } else {
      if (DateUtils.isSameDay(_selectedDateRange!.start, _selectedDateRange!.end)) {
        displayText = DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDateRange!.start);
      } else {
        displayText = '${DateFormat('d MMM', 'id_ID').format(_selectedDateRange!.start)} - ${DateFormat('d MMM yyyy', 'id_ID').format(_selectedDateRange!.end)}';
      }
    }
    
    return InkWell(
      onTap: () => _selectDateRange(context),
      child: InputDecorator(
        decoration: _inputDecoration('').copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(displayText, style: const TextStyle(fontSize: 16)),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, [String? hint]) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.blueGrey),
      floatingLabelStyle: const TextStyle(color: Colors.blue),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue.shade700, width: 2.0),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  ButtonStyle _outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      foregroundColor: Colors.blue.shade700,
      side: BorderSide(color: Colors.blue.shade700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}