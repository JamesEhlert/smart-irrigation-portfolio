// lib/auth_wrapper.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// CAMINHOS CORRIGIDOS AQUI:
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // O StreamBuilder ouve em tempo real as mudanças no estado de autenticação
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Se estiver aguardando a verificação, mostra um loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Se o snapshot tiver um usuário, mostra a HomeScreen
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        
        // Se não, mostra a LoginScreen
        return const LoginScreen();
      },
    );
  }
}