import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jejak_hadir_app/models/leave_request_local.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class DutyLeaveModal extends StatefulWidget {
  final LocalUser user;
  const DutyLeaveModal({super.key, required this.user});

  @override
  State<DutyLeaveModal> createState() => _DutyLeaveModalState();
}

class _DutyLeaveModalState extends State<DutyLeaveModal> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  File? _pickedFile;
  bool _isLoading = false;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      helpText: 'Pilih Rentang Tanggal Dinas',
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
  
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
      });
    }
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
        requestType: 'Dinas Luar',
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
              const Text('Form Pengajuan Dinas Luar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              _buildDateRangeSelector(),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: _inputDecoration('Keterangan/Tujuan', 'Contoh: Kunjungan ke Dinas Kesehatan...'),
                validator: (val) => val!.isEmpty ? 'Keterangan tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_pickedFile == null ? 'Unggah Surat Tugas (Opsional)' : 'Ganti Surat Tugas'),
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
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('AJUKAN DINAS LUAR'),
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