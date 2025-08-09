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
  DateTime? _startDate;
  DateTime? _endDate;
  File? _pickedFile;
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
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
      if (_startDate == null || _endDate == null) {
        return;
      }
      
      setState(() => _isLoading = true);

      final newRequest = LeaveRequest(
        id: const Uuid().v4(),
        userId: widget.user.uid,
        requestType: 'Dinas Luar',
        startDate: _startDate!,
        endDate: _endDate!,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Form Pengajuan Dinas Luar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(child: _buildDateSelector("Tanggal Mulai", _startDate, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDateSelector("Tanggal Selesai", _endDate, false)),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Keterangan/Tujuan', 
                  hintText: 'Contoh: Kunjungan ke Dinas Kesehatan...', 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                ),
                validator: (val) => val!.isEmpty ? 'Keterangan tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text(_pickedFile == null ? 'Unggah Surat Tugas (Opsional)' : 'Ganti Surat Tugas'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (_pickedFile != null) ...[
                const SizedBox(height: 8),
                Text('File: ${_pickedFile!.path.split('/').last}', style: const TextStyle(color: Colors.green)),
              ],
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('AJUKAN DINAS LUAR'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context, isStart),
          child: InputDecorator(
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15)),
            child: Text(
              date == null ? 'Pilih' : DateFormat('dd/MM/yy').format(date),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}