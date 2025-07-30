import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/services/auth_service_local.dart';

// Halaman untuk melihat detail profil (tidak berubah)
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

// Halaman Profil Utama (tidak berubah)
class ProfileScreen extends StatefulWidget {
  final LocalUser user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                AuthServiceLocal.instance.signOut();
                if (Navigator.of(context).canPop()) {
                   Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext modalContext) {
        // Kirim email user ke form agar bisa digunakan untuk ubah password
        return ChangePasswordForm(userEmail: widget.user.email); 
      },
    );
  }

  Widget _buildMenuTile({ required IconData icon, required String title, required VoidCallback onTap, Color? color }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blue),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: color ?? Colors.grey.shade400),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    _buildMenuTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Lihat Profil',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ViewProfileDetailScreen(user: widget.user)),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildMenuTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Ubah Password',
                      onTap: () {
                        _showChangePasswordModal(context);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildMenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      color: Colors.red,
                      onTap: () {
                        _showLogoutConfirmation(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- [PERBAIKAN UTAMA DI SINI] ---
// Widget terpisah untuk Form di dalam Modal
class ChangePasswordForm extends StatefulWidget {
  final String userEmail; // Menerima email pengguna aktif
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

  // State visibilitas untuk SEMUA field password
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

  // --- [PERBAIKAN LOGIKA SUBMIT] ---
  void _submitChangePassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Panggil fungsi changePassword yang asli
      final result = await AuthServiceLocal.instance.changePassword(
        email: widget.userEmail,
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      
      // Beri umpan balik ke pengguna
      if (mounted) {
        if (result) {
          // Jika berhasil
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password berhasil diubah!'), backgroundColor: Colors.green),
          );
        } else {
          // Jika gagal (kemungkinan password lama salah)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengubah password. Pastikan password lama Anda benar.'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
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