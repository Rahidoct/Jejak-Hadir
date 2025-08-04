import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/auth_service_local.dart';
import 'package:jejak_hadir_app/helpers/notification_helper.dart';

// --- Halaman-Halaman Placeholder (diletakkan di file yang sama untuk kemudahan) ---

// Halaman untuk melihat detail profil (tidak ada perubahan)
class ViewProfileDetailScreen extends StatelessWidget {
  final LocalUser user;
  const ViewProfileDetailScreen({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Profil'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(title: const Text("Nama Lengkap"), subtitle: Text(user.name, style: const TextStyle(fontSize: 16))), const Divider(),
            ListTile(title: const Text("Email"), subtitle: Text(user.email, style: const TextStyle(fontSize: 16))), const Divider(),
            ListTile(title: const Text("NIP"), subtitle: Text(user.nip ?? '-', style: const TextStyle(fontSize: 16))), const Divider(),
            ListTile(title: const Text("Jabatan"), subtitle: Text(user.position ?? '-', style: const TextStyle(fontSize: 16))), const Divider(),
            ListTile(title: const Text("Golongan"), subtitle: Text(user.grade ?? '-', style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }
}

// [BARU] Halaman kerangka untuk Perekaman Wajah
class FaceEnrollmentScreen extends StatelessWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perekaman Wajah'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_front, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Fitur perekaman wajah sedang dalam tahap pengembangan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// [BARU] Halaman kerangka untuk Pengaturan
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Halaman pengaturan sedang dalam tahap pengembangan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// --- Halaman Profil Utama ---
class ProfileScreen extends StatefulWidget {
  final LocalUser user;
  const ProfileScreen({super.key, required this.user});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showLogoutConfirmation(BuildContext context) {
    NotificationHelper.show(
      context,
      title: "Konfirmasi Logout",
      message: "Apakah Anda yakin ingin keluar dari akun Anda?",
      type: NotificationType.confirm,
      onConfirm: () {
        AuthServiceLocal.instance.signOut(context);
        if (Navigator.of(context).canPop()) {
           Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext modalContext) {
        return ChangePasswordForm(userEmail: widget.user.email); 
      },
    );
  }

  // Helper TIDAK LAGI menggunakan ListTile, tetapi langsung membangun Card
  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    // Tentukan warna default jika tidak ada warna khusus yang diberikan
    final itemColor = color ?? Colors.blue;
    
    return Card(
      color: Colors.grey.shade50,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell( // Menggunakan InkWell agar seluruh card bisa diklik
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(icon, color: itemColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: TextStyle(color: itemColor, fontWeight: FontWeight.w500, fontSize: 16)),
              ),
              Icon(Icons.chevron_right, color: color ?? Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- BAGIAN HEADER PROFIL ---
            Container(
              padding: const EdgeInsets.all(24.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 45, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  // ignore: deprecated_member_use
                  Text(widget.user.email, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // --- [PERUBAHAN UTAMA DI SINI] ---
            // Setiap menu sekarang adalah Card-nya sendiri
            _buildMenuCard(
              context: context,
              icon: Icons.person_outline_rounded,
              title: 'Lihat Profil',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ViewProfileDetailScreen(user: widget.user)));
              },
            ),
            _buildMenuCard(
              context: context,
              icon: Icons.camera_front_outlined,
              title: 'Perekaman Wajah',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const FaceEnrollmentScreen()));
              },
            ),
             _buildMenuCard(
              context: context,
              icon: Icons.lock_outline_rounded,
              title: 'Ubah Password',
              onTap: () {
                _showChangePasswordModal(context);
              },
            ),
            _buildMenuCard(
              context: context,
              icon: Icons.settings_outlined,
              title: 'Pengaturan',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              },
            ),
            _buildMenuCard(
              context: context,
              icon: Icons.logout_rounded,
              title: 'Logout',
              color: Colors.red,
              onTap: () {
                _showLogoutConfirmation(context);
              },
            ),
            const SizedBox(height: 24), // Beri sedikit ruang di bawah
          ],
        ),
      ),
    );
  }
}

class ChangePasswordForm extends StatefulWidget {
  final String userEmail;
  const ChangePasswordForm({super.key, required this.userEmail});
  @override
  // ignore: library_private_types_in_public_api
  _ChangePasswordFormState createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController(); 
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    // 2. Jangan lupa di-dispose
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitChangePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final result = await AuthServiceLocal.instance.changePassword(
        email: widget.userEmail,
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        if (result) {
          NotificationHelper.show(context,
            title: "Yay.. Berhasil",
            message: "Password kamu telah berhasil diperbarui.",
            type: NotificationType.success,
          );
        } else {
          NotificationHelper.show(context,
            title: "Aduh..Gagal!",
            message: "Coba deh cek password lama kamu bener engga.?",
            type: NotificationType.error,
          );
        }
      }
    }
  }

  Widget _buildPasswordInputField({ required TextEditingController controller, required String label, required bool isVisible, required VoidCallback onVisibilityToggle, String? Function(String?)? validator }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off), onPressed: onVisibilityToggle),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3. Dibungkus dengan SingleChildScrollView
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          // Padding ini akan mendorong konten ke atas saat keyboard muncul
          bottom: MediaQuery.of(context).viewInsets.bottom, 
          left: 16,
          right: 16,
          top: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ubah Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              // 4. Input "Password Lama" ditambahkan kembali ke UI
              _buildPasswordInputField(
                controller: _oldPasswordController,
                label: 'Password Lama',
                isVisible: _isOldPasswordVisible,
                onVisibilityToggle: () => setState(() => _isOldPasswordVisible = !_isOldPasswordVisible),
                validator: (val) => val!.isEmpty ? 'Field ini tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              
              _buildPasswordInputField(
                controller: _newPasswordController,
                label: 'Password Baru',
                isVisible: _isNewPasswordVisible,
                onVisibilityToggle: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Field ini tidak boleh kosong';
                  if (val.length < 6) return 'Password minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordInputField(
                controller: _confirmPasswordController,
                label: 'Konfirmasi Password Baru',
                isVisible: _isConfirmPasswordVisible,
                onVisibilityToggle: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                validator: (val) {
                  if (val != _newPasswordController.text) return 'Konfirmasi password tidak cocok';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitChangePassword,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SIMPAN'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}