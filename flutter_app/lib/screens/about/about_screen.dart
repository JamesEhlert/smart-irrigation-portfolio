// lib/screens/about/about_screen.dart

import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Widget auxiliar para criar os cards de informação
  Widget _buildInfoCard(BuildContext context, {required IconData icon, required String title, required String content}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o Aplicativo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildInfoCard(
            context,
            icon: Icons.water_drop_outlined,
            title: 'Irrigação Inteligente',
            content: 'Este aplicativo é o centro de controle para um sistema de irrigação inteligente ponta a ponta, projetado para otimizar o uso da água e garantir a saúde das plantas.\n\nDesenvolvido em 2025 como um projeto de estudo e aplicação de tecnologias de ponta em IoT, Cloud e Desenvolvimento Mobile.',
          ),
          _buildInfoCard(
            context,
            icon: Icons.person_outline,
            title: 'Desenvolvedor',
            content: 'James Rafael Ehlert Reinard',
          ),
          _buildInfoCard(
            context,
            icon: Icons.code,
            title: 'Tecnologias Utilizadas',
            content: '• Hardware: ESP32-C3\n'
                     '• Nuvem (Backend): AWS (IoT Core, Lambda, DynamoDB) e Google Cloud (Firebase Authentication, Firestore)\n'
                     '• Aplicativo: Flutter com a linguagem Dart.',
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        child: const SizedBox(
          height: 50,
          child: Center(
            child: Text(
              'Versão 2.0',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}