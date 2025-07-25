import 'package:flutter/material.dart';
import 'package:jejak_hadir_app/models/user_local.dart';
import 'package:jejak_hadir_app/screens/auth_screen_local.dart';
import 'package:jejak_hadir_app/screens/home_screen_local.dart';
import 'package:jejak_hadir_app/services/auth_service_local.dart';

class AuthWrapperLocal extends StatefulWidget {
  const AuthWrapperLocal({super.key});

  @override
  State<AuthWrapperLocal> createState() => _AuthWrapperLocalState();
}

class _AuthWrapperLocalState extends State<AuthWrapperLocal> {
  final AuthServiceLocal _auth = AuthServiceLocal();

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LocalUser?>(
      stream: _auth.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData && snapshot.data != null) {
          return HomeScreenLocal(user: snapshot.data!);
        } else {
          return const AuthScreenLocal();
        }
      },
    );
  }
}