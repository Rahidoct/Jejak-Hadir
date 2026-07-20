import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/services/auth_service_local.dart';

class AuthScreenLocal extends StatefulWidget {
  const AuthScreenLocal({super.key});

  @override
  State<AuthScreenLocal> createState() => _AuthScreenLocalState();
}

class _AuthScreenLocalState extends State<AuthScreenLocal> {
  final AuthServiceLocal _auth = AuthServiceLocal.instance;
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // --- LOGIKA UTAMA UNTUK SUBMIT FORM DENGAN NOTIFIKASI BARU ---
  void _submitForm() async {
    // Sembunyikan keyboard untuk UX yang lebih baik
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      // Login ke backend. Notifikasi sukses/gagal ditangani di AuthService.
      // Akun pegawai dibuat oleh admin Kepegawaian di web — tak ada registrasi
      // mandiri dari aplikasi.
      await _auth.signInWithEmailAndPassword(email, password, context);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper untuk membangun input field (tidak ada perubahan)
  Widget _buildTextField({
    required String label,
    required IconData icon,
    required Function(String) onChanged,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: isPassword && !_isPasswordVisible,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade600),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  )
                : null,
            hintText: 'Ketik ${label.toLowerCase()}mu...',
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // --- BAGIAN HEADER & LOGO ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo_puskesmas.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.contain,
                        // Dekode pada resolusi kecil (bukan 1280px asli) — hemat memori/CPU.
                        cacheWidth: 200,
                        cacheHeight: 200,
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JEJAK HADIR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Puskesmas Bunder', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // --- JUDUL FORM ---
                  const Text(
                    'Masuk untuk mulai absensi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // --- INPUT FIELDS ---
                  _buildTextField(
                    label: 'Username atau Email',
                    icon: Icons.person_outline,
                    onChanged: (val) => setState(() => email = val),
                    validator: (val) => val!.isEmpty ? 'Username / email tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    onChanged: (val) => setState(() => password = val),
                    validator: (val) {
                      if (val!.isEmpty) return 'Password tidak boleh kosong';
                      if (val.length < 6) return 'Password minimal 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // --- TOMBOL AKSI ---
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm, // Panggil fungsi _submitForm yang baru
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : const Text(
                            'Masuk',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Akun dibuat oleh admin Kepegawaian — tak ada registrasi mandiri.
                  Text(
                    'Gunakan akun yang terdaftar di sistem kepegawaian.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}