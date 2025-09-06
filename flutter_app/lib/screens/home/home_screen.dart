// lib/screens/home/home_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:irrigation_app_v2/screens/about/about_screen.dart';
import 'package:irrigation_app_v2/screens/history/history_screen.dart';
import 'package:irrigation_app_v2/screens/logs/logs_screen.dart';
import 'package:irrigation_app_v2/screens/manual/manual_screen.dart';
import 'package:irrigation_app_v2/screens/schedules/schedules_list_screen.dart';
import 'package:irrigation_app_v2/screens/settings/settings_screen.dart';
import 'package:irrigation_app_v2/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Timer? _refreshTimer;
  Map<String, dynamic>? _latestReading;
  bool _isLoading = true;
  String? _error;
  bool _isSendingCommand = false;
  int _manualDurationSeconds = 5;
  int _dashboardRefreshSeconds = 5;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadDeviceSettingsAndStartTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadDeviceSettingsAndStartTimer() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final deviceQuery = await _firestore
          .collection('users').doc(user.uid).collection('devices').limit(1).get();
      if (deviceQuery.docs.isNotEmpty) {
        final deviceData = deviceQuery.docs.first.data();
        if (mounted) {
          setState(() {
            _manualDurationSeconds = deviceData['manualIrrigationSeconds'] ?? 5;
            _dashboardRefreshSeconds = deviceData['dashboardRefreshSeconds'] ?? 5;

            _refreshTimer?.cancel();
            _refreshTimer = Timer.periodic(Duration(seconds: _dashboardRefreshSeconds), (timer) {
              _fetchData(showLoading: false);
            });
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar configurações do dispositivo: $e");
    }
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() { _isLoading = true; _error = null; });
    }
    try {
      final reading = await _apiService.getLatestReading();
      if (mounted) {
        setState(() {
          _latestReading = reading;
          if (!showLoading) _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); });
      }
    } finally {
      if (mounted && showLoading) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _sendManualCommand() async {
    setState(() { _isSendingCommand = true; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enviando comando...')),
    );
    try {
      await _apiService.sendValveCommand(durationSeconds: _manualDurationSeconds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comando enviado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar comando: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if(mounted) {
        setState(() { _isSendingCommand = false; });
      }
    }
  }

  // --- NOVA FUNÇÃO DE FORMATAÇÃO ADICIONADA AQUI ---
  String _formatManualDuration(int seconds) {
    if (seconds >= 3600) {
      // Converte para horas, com uma casa decimal se não for um número inteiro
      double hours = seconds / 3600.0;
      return "${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)} h";
    }
    if (seconds >= 60) {
      // Converte para minutos, com uma casa decimal se não for um número inteiro
      double minutes = seconds / 60.0;
      return "${minutes.toStringAsFixed(minutes.truncateToDouble() == minutes ? 0 : 1)} min";
    }
    // Mantém em segundos
    return "$seconds s";
  }

  Widget _buildMoistureContent() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }
    if (_error != null && _latestReading == null) {
      return const Text('Erro ao carregar dados.\nVerifique a conexão.',
          style: TextStyle(color: Colors.red), textAlign: TextAlign.center);
    }
    if (_latestReading == null || _latestReading!.isEmpty) {
      return const Text('Nenhuma leitura encontrada.');
    }
    final temperature = _latestReading!['readings']['temperature'];
    final timestamp = _latestReading!['datetime_br'];
    return Column(
      children: [
        Text('$temperature %',
            style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        Text('Última atualização: $timestamp'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Tentando reconectar...',
                style: TextStyle(color: Colors.orange[800])),
          )
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ).copyWith(
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Umidade Atual',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _buildMoistureContent(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionButton(
                  icon: Icons.water_drop_outlined,
                  // --- TEXTO DO BOTÃO AGORA USA A FORMATAÇÃO ---
                  label: 'Irrigar (${_formatManualDuration(_manualDurationSeconds)})',
                  onPressed: _isSendingCommand ? (){} : _sendManualCommand,
                ),
                _buildActionButton(
                  icon: Icons.schedule,
                  label: 'Agendar',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SchedulesListScreen())),
                ),
                _buildActionButton(
                  icon: Icons.history,
                  label: 'Histórico',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const HistoryScreen())),
                ),
                _buildActionButton(
                  icon: Icons.receipt_long_outlined,
                  label: 'Relatório',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LogsScreen())),
                ),
                _buildActionButton(
                  icon: Icons.settings,
                  label: 'Ajustes',
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
                    _loadDeviceSettingsAndStartTimer();
                  },
                ),
                _buildActionButton(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Previsão',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Funcionalidade de previsão do tempo em breve!')),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.menu_book_outlined,
                  label: 'Manual',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ManualScreen())),
                ),
                _buildActionButton(
                  icon: Icons.info_outline,
                  label: 'Sobre',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AboutScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        child: SizedBox(
          height: 50,
          child: const Center(
            child: Text(
              '© 2025 Sistema de Irrigação Inteligente',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}