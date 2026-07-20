// lib/screens/edit_profile_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jejak_hadir_app/helpers/notification_helper.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/local_storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  final LocalUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nipController;
  late TextEditingController _positionController;
  late TextEditingController _gradeController;
  String? _profilePictureBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nipController = TextEditingController(text: widget.user.nip);
    _positionController = TextEditingController(text: widget.user.position);
    _gradeController = TextEditingController(text: widget.user.grade);
    _profilePictureBase64 = widget.user.profilePicture;
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        _profilePictureBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final updatedUser = widget.user.copyWith(
        nip: _nipController.text,
        position: _positionController.text,
        grade: _gradeController.text,
        profilePicture: _profilePictureBase64,
      );

      await LocalStorageService().updateUserProfile(updatedUser);
      
      if (mounted) {
        NotificationHelper.show(context, title: "Berhasil", message: "Profil Anda telah diperbarui.", type: NotificationType.success);
        Navigator.pop(context, true);
      }
      
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Foto Profil
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: _profilePictureBase64 != null 
                      ? MemoryImage(base64Decode(_profilePictureBase64!))
                      : null,
                  child: _profilePictureBase64 == null
                      ? Icon(Icons.camera_alt, size: 40, color: Colors.blue.shade700)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              const Text("Ketuk untuk mengubah foto", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              
              // Form
              TextFormField(
                controller: _nipController,
                decoration: const InputDecoration(labelText: 'NIP', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'NIP tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _positionController,
                decoration: const InputDecoration(labelText: 'Jabatan', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Jabatan tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gradeController,
                decoration: const InputDecoration(labelText: 'Golongan', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Golongan tidak boleh kosong' : null,
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text('SIMPAN PERUBAHAN'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}