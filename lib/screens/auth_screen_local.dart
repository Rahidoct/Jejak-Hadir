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
  String name = '';
  bool isLogin = true;
  String error = '';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // --- [PERBAIKAN LOGIKA DISINI] ---
  // Fungsi untuk menangani proses submit form
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
                  // --- [PERBAIKAN DI SINI] ---
                  // Row header sekarang diatur agar berada di tengah
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Ini kuncinya
                    children: [
                      // Logo Dummy
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        // ubah icon aplikasi disini 
                        child: const Icon(Icons.location_city, size: 40, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      // Kolom untuk teks tetap rata kiri
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
                  // --- AKHIR PERBAIKAN ---

                  // --- JUDUL FORM ---
                  Text(
                    isLogin ? 'Masuk untuk mulai absensi' : 'Daftarkan Akun',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  
                  // --- INPUT FIELDS ---
                  if (!isLogin) ...[
                    _buildTextField(
                      label: 'Nama Lengkap',
                      icon: Icons.person_outline,
                      onChanged: (val) => setState(() => name = val),
                      validator: (val) => val!.isEmpty ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildTextField(
                    label: 'Email',
                    icon: Icons.email_outlined,
                    onChanged: (val) => setState(() => email = val),
                    validator: (val) => val!.isEmpty ? 'Email tidak boleh kosong' : null,
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
                    onPressed: _isLoading 
                        ? null 
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _isLoading = true);
                              dynamic result;
                              
                              if (isLogin) {
                                result = await _auth.signInWithEmailAndPassword(email, password);
                                if (result == null) {
                                  setState(() => error = 'Login gagal. Email/Password salah.');
                                }
                              } else {
                                result = await _auth.registerWithEmailAndPassword(email, password, name);
                                if (result == null) {
                                  setState(() => error = 'Pendaftaran gagal. Coba lagi.');
                                } else {
                                  // INI BAGIAN YANG DITAMBAHKAN
                                  // Reset form setelah pendaftaran berhasil
                                  setState(() {
                                    isLogin = !isLogin;
                                    error = '';
                                    // Tambahkan ini untuk reset form saat toggle login/daftar
                                    _formKey.currentState?.reset();
                                    email = '';
                                    password = '';
                                    name = '';
                                  });
                                  // Tampilkan pesan sukses
                                  // ignore: use_build_context_synchronously
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Pendaftaran berhasil! Silakan login.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                              
                              if (mounted) {
                                setState(() => _isLoading = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : Text(
                            isLogin ? 'Masuk' : 'Daftar',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // --- TOGGLE LOGIN/DAFTAR ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin ? 'Belum memiliki akun?' : 'Sudah memiliki akun?',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : () {
                          setState(() {
                            isLogin = !isLogin;
                            error = '';
                          });
                        },
                        child: Text(
                          isLogin ? 'Daftar disini' : 'Masuk',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                  
                  // --- PESAN ERROR ---
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red, fontSize: 14.0),
                        textAlign: TextAlign.center,
                      ),
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

// kode akses awal