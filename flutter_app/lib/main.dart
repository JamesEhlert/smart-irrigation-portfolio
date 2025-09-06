// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:irrigation_app_v2/auth_wrapper.dart';
import 'package:irrigation_app_v2/theme/app_theme.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart'; // 1. Importa a biblioteca de inicialização

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa os dados de formatação para o nosso local (português do Brasil)
  await initializeDateFormatting('pt_BR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Irrigação',
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}