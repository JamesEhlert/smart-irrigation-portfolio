// lib/screens/manual/manual_screen.dart

import 'package:flutter/material.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  // Widget auxiliar para criar as seções do manual
  Widget _buildSection(BuildContext context, {required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(thickness: 1.5),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual do Aplicativo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            context,
            title: 'Dashboard (Tela Inicial)',
            content: 'A tela principal exibe a leitura de umidade mais recente do seu sensor, atualizada automaticamente a cada 5 segundos. A partir daqui, você pode acessar todas as funcionalidades do aplicativo através do painel de ações.',
          ),
          _buildSection(
            context,
            title: 'Irrigação Manual',
            content: 'O botão "Irrigar" aciona a válvula de irrigação imediatamente. A duração padrão desta irrigação pode ser configurada na tela de "Ajustes".',
          ),
          _buildSection(
            context,
            title: 'Agendamentos',
            content: 'Crie, edite e apague agendamentos de irrigação. Cada agendamento é executado de forma inteligente: o sistema só liga a válvula se a umidade do solo estiver abaixo do limite que você definiu nos "Ajustes".',
          ),
          _buildSection(
            context,
            title: 'Histórico e Relatórios',
            content: 'A tela de "Histórico" mostra todas as leituras de umidade já registradas. A tela de "Relatório" exibe uma lista de todos os agendamentos que foram ignorados e o motivo, garantindo total transparência sobre as ações do sistema.',
          ),
          _buildSection(
            context,
            title: 'Ajustes',
            content: 'Nesta tela você pode personalizar o funcionamento do sistema. Defina um nome para o seu dispositivo, ajuste o limite máximo de umidade desejada e configure a duração da irrigação manual.',
          ),
        ],
      ),
    );
  }
}