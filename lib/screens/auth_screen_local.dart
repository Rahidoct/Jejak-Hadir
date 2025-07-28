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

  Widget _buildInputField(
    String label,
    Function(String) onChanged, {
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // --- [PERUBAHAN TEMA] ---
          // Mengganti gradient dari hijau ke biru.
          gradient: LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)], // Dari biru tua ke biru muda
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 20),
                  Text(
                    isLogin ? 'Jejak Hadir Login' : 'Jejak Hadir Daftar',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildInputField(
                            'Email',
                            (val) => setState(() => email = val),
                            validator: (val) => val!.isEmpty ? 'Masukkan email' : null,
                          ),
                          _buildInputField(
                            'Password',
                            (val) => setState(() => password = val),
                            isPassword: true,
                            validator: (val) => val!.length < 6 ? 'Password min. 6 karakter' : null,
                          ),
                          if (!isLogin)
                            _buildInputField(
                              'Nama Lengkap',
                              (val) => setState(() => name = val),
                              validator: (val) => val!.isEmpty ? 'Masukkan nama Anda' : null,
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
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
                                          }
                                        }
                                        if (mounted) {
                                          setState(() => _isLoading = false);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                // --- [PERUBAHAN TEMA] ---
                                // Mengganti warna tombol dari hijau ke biru.
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 5,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      isLogin ? 'LOGIN' : 'DAFTAR',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      isLogin = !isLogin;
                                      error = '';
                                    });
                                  },
                            child: Text(
                              isLogin ? 'Belum punya akun? Daftar sekarang' : 'Sudah punya akun? Login di sini',
                              style: TextStyle(
                                color: _isLoading ? Colors.grey : Colors.grey[700], 
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (error.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              error,
                              style: const TextStyle(color: Colors.red, fontSize: 14.0),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
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