// lib/screens/schedules/schedules_list_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:irrigation_app_v2/screens/schedules/schedule_edit_screen.dart';

class SchedulesListScreen extends StatefulWidget {
  const SchedulesListScreen({super.key});

  @override
  State<SchedulesListScreen> createState() => _SchedulesListScreenState();
}

class _SchedulesListScreenState extends State<SchedulesListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Função para ativar/desativar o agendamento
  Future<void> _toggleSchedule(String deviceId, String scheduleId, bool currentState) async {
    try {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('devices')
          .doc(deviceId)
          .collection('schedules')
          .doc(scheduleId)
          .update({'isEnabled': !currentState});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar o status: $e')),
      );
    }
  }

  // Função para formatar os dias da semana de forma amigável
  String _formatDays(List<dynamic> days) {
    if (days.length == 7) return 'Todos os dias';
    if (days.isEmpty) return 'Não programado';

    // Mapeia as chaves para abreviações em português
    const dayMap = {
      'monday': 'Seg', 'tuesday': 'Ter', 'wednesday': 'Qua',
      'thursday': 'Qui', 'friday': 'Sex', 'saturday': 'Sáb', 'sunday': 'Dom',
    };
    return days.map((day) => dayMap[day] ?? '').join(', ');
  }

  Stream<QuerySnapshot> _getSchedulesStream(String deviceId) {
    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('devices')
        .doc(deviceId)
        .collection('schedules')
        .orderBy('startTime')
        .snapshots();
  }

  Future<String?> _getDeviceId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final deviceQuery = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .limit(1)
        .get();

    if (deviceQuery.docs.isNotEmpty) {
      return deviceQuery.docs.first.id;
    }
    return null;
  }

  void _navigateToEditScreen(String deviceId, {DocumentSnapshot? scheduleDoc}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScheduleEditScreen(
          deviceId: deviceId,
          scheduleDocument: scheduleDoc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendamentos'),
      ),
      body: FutureBuilder<String?>(
        future: _getDeviceId(),
        builder: (context, deviceSnapshot) {
          if (deviceSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (deviceSnapshot.hasError || !deviceSnapshot.hasData || deviceSnapshot.data == null) {
            return const Center(child: Text('Não foi possível encontrar o dispositivo.'));
          }

          final deviceId = deviceSnapshot.data!;

          return Scaffold(
            body: StreamBuilder<QuerySnapshot>(
              stream: _getSchedulesStream(deviceId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ocorreu um erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhum agendamento criado ainda.'));
                }

                final schedules = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8), // Adiciona um espaçamento geral
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final scheduleDoc = schedules[index];
                    final data = scheduleDoc.data() as Map<String, dynamic>;
                    
                    final days = _formatDays(data['daysOfWeek'] as List);
                    final isEnabled = data['isEnabled'] ?? true;
                    final time = data['startTime'] ?? '00:00';

                    // Usa um Card para criar o "bloco" visual
                    return Card(
                      // Muda a cor do card se estiver ativo
                      color: isEnabled ? Theme.of(context).colorScheme.surfaceContainer : Theme.of(context).colorScheme.surface,
                      clipBehavior: Clip.antiAlias, // Garante que o InkWell não vaze para fora do card
                      child: InkWell(
                        onTap: () => _navigateToEditScreen(deviceId, scheduleDoc: scheduleDoc),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Coluna para o texto e a hora
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    days,
                                    style: TextStyle(
                                      color: isEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: isEnabled ? Colors.black : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              // Switch para ativar/desativar
                              Switch(
                                value: isEnabled,
                                onChanged: (value) {
                                  _toggleSchedule(deviceId, scheduleDoc.id, isEnabled);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _navigateToEditScreen(deviceId),
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
      // --- RODAPÉ (FOOTER) ADICIONADO AQUI ---
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primary,
        child: const SizedBox(
          height: 50,
          child: Center(
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