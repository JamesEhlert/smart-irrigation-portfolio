// lib/screens/history/history_screen.dart

import 'package:flutter/material.dart';
import 'package:irrigation_app_v2/services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  
  final List<Map<String, dynamic>> _readings = [];
  bool _isLoading = true;
  bool _hasMoreData = true;
  String? _exclusiveStartKey;

  @override
  void initState() {
    super.initState();
    _fetchReadings();
  }

  Future<void> _fetchReadings() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await _apiService.getReadingsHistory(
        limit: 100,
        exclusiveStartKey: _exclusiveStartKey,
      );
      
      final newItems = (response['items'] as List).cast<Map<String, dynamic>>();
      
      if(mounted) {
        setState(() {
          _readings.addAll(newItems);
          _exclusiveStartKey = response['exclusiveStartKey'];
          _hasMoreData = _exclusiveStartKey != null;
        });
      }

    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar histórico: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Leituras'),
      ),
      body: _isLoading && _readings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(8), // Adiciona um espaçamento geral
              itemCount: _readings.length + (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _readings.length) {
                  return _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : TextButton(
                          onPressed: _fetchReadings,
                          child: const Text('Carregar Mais'),
                        );
                }

                final reading = _readings[index];
                final temperature = reading['readings']['temperature'];
                final dateTimeString = reading['datetime_br'] ?? 'Data indisponível';

                // --- LAYOUT COM CARD ADOTADO AQUI ---
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.thermostat_auto, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$temperature %',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateTimeString,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}