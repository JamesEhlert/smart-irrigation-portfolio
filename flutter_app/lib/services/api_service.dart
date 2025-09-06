// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String _baseUrl = 'https://5axwluvl53.execute-api.us-east-2.amazonaws.com/prod';
  final String _thingId = 'ESP32-C3-AHT10-Sensor';

  Future<Map<String, dynamic>> getLatestReading() async {
    final uri = Uri.parse('$_baseUrl/readings?thingId=$_thingId&limit=1');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items.isNotEmpty ? items.first : {};
      } else {
        throw Exception('Falha ao carregar dados da API: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  Future<void> sendValveCommand({required int durationSeconds}) async {
    final uri = Uri.parse('$_baseUrl/command');
    try {
      final body = json.encode({
        'command': 'open_valve',
        'duration_seconds': durationSeconds,
      });
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode != 200) {
        throw Exception('Falha ao enviar comando: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao enviar comando: $e');
    }
  }
  
  Future<Map<String, dynamic>> getReadingsHistory({
    // --- ALTERAÇÃO AQUI ---
    int limit = 100, // O valor padrão agora é 100
    String? exclusiveStartKey,
  }) async {
    try {
      final queryParameters = {
        'thingId': _thingId,
        'limit': limit.toString(),
        if (exclusiveStartKey != null) 'exclusiveStartKey': exclusiveStartKey,
      };

      final uri = Uri.parse('$_baseUrl/readings').replace(queryParameters: queryParameters);
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Falha ao carregar histórico: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro de conexão ao buscar histórico: $e');
    }
  }
}