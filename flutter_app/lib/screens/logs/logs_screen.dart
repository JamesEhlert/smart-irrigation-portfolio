// lib/screens/logs/logs_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _getLogsStream(String deviceId) {
    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('devices')
        .doc(deviceId)
        .collection('executionLogs')
        .where('actionTaken', isEqualTo: 'skipped')
        .orderBy('timestamp', descending: true)
        .limit(100)
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

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat('dd/MM/yyyy \'às\' HH:mm', 'pt_BR').format(dateTime);
  }
  
  void _showLogDetailsDialog(Map<String, dynamic> logData) {
    final reason = logData['reason'] ?? 'Motivo não especificado.';
    final timestamp = logData['timestamp'] as Timestamp?;
    final scheduledTime = logData['scheduledTime'] ?? 'N/A';
    
    final formattedDate = timestamp != null
        ? DateFormat('EEEE, dd \'de\' MMMM \'de\' yyyy', 'pt_BR').format(timestamp.toDate())
        : 'Data indisponível';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalhes do Agendamento'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Um agendamento programado para as $scheduledTime foi ignorado.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Motivo:'),
            Text(
              reason,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            const Text('Data da Ocorrência:'),
            Text(formattedDate),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A linha 'Intl.defaultLocale = 'pt_BR';' foi removida daqui,
    // pois a inicialização agora é global no main.dart.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Ações Ignoradas'),
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

          return StreamBuilder<QuerySnapshot>(
            stream: _getLogsStream(deviceId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Ocorreu um erro: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Nenhum agendamento foi ignorado ainda.'));
              }

              final logs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final logDoc = logs[index];
                  final data = logDoc.data() as Map<String, dynamic>;
                  
                  final reason = data['reason'] ?? 'Motivo não especificado.';
                  final timestamp = data['timestamp'] as Timestamp?;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _showLogDetailsDialog(data),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.blueGrey,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reason,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timestamp != null 
                                      ? _formatTimestamp(timestamp)
                                      : 'Horário indisponível',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}