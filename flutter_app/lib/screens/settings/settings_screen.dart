// lib/screens/settings/settings_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceNameController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _manualDurationController = TextEditingController();
  // --- NOVO CONTROLLER ADICIONADO ---
  final _refreshIntervalController = TextEditingController();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _deviceId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
  }

  Future<void> _loadDeviceData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final deviceQuery = await _firestore
          .collection('users').doc(user.uid).collection('devices').limit(1).get();

      if (!mounted) return;

      if (deviceQuery.docs.isNotEmpty) {
        final deviceDoc = deviceQuery.docs.first;
        final deviceData = deviceDoc.data();
        
        _deviceId = deviceDoc.id;
        _deviceNameController.text = deviceData['deviceName'] ?? '';
        _thresholdController.text = deviceData['maxMoistureThreshold']?.toString() ?? '';
        _manualDurationController.text = deviceData['manualIrrigationSeconds']?.toString() ?? '5';
        // --- CARREGA O NOVO VALOR (OU UM PADRÃO DE 5 SEGUNDOS) ---
        _refreshIntervalController.text = deviceData['dashboardRefreshSeconds']?.toString() ?? '5';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    final user = _auth.currentUser;
    if (user == null || _deviceId == null) return;
    
    setState(() { _isSaving = true; });

    try {
      // --- SALVA O NOVO CAMPO NO FIRESTORE ---
      final dataToUpdate = {
        'deviceName': _deviceNameController.text.trim(),
        'maxMoistureThreshold': int.parse(_thresholdController.text.trim()),
        'manualIrrigationSeconds': int.parse(_manualDurationController.text.trim()),
        'dashboardRefreshSeconds': int.parse(_refreshIntervalController.text.trim()),
      };

      await _firestore
          .collection('users').doc(user.uid).collection('devices').doc(_deviceId)
          .update(dataToUpdate);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _thresholdController.dispose();
    _manualDurationController.dispose();
    _refreshIntervalController.dispose(); // Limpa o novo controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes do Dispositivo'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _deviceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Dispositivo (ex: Jardim da Frente)',
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true) ? 'Por favor, insira um nome.' : null,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _thresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Umidade Máxima Desejada (%)',
                      hintText: 'Valor entre 0 e 100',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Insira um valor.';
                      final n = int.tryParse(value);
                      if (n == null || n < 0 || n > 100) return 'Insira um número entre 0 e 100.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _manualDurationController,
                    decoration: const InputDecoration(
                      labelText: 'Duração da Irrigação Manual (segundos)',
                      hintText: 'Ex: 5',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Insira um valor.';
                      final n = int.tryParse(value);
                      if (n == null || n <= 0) return 'Insira um valor maior que zero.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // --- NOVO CAMPO ADICIONADO À INTERFACE ---
                  TextFormField(
                    controller: _refreshIntervalController,
                    decoration: const InputDecoration(
                      labelText: 'Intervalo de Atualização do Dashboard (s)',
                      hintText: 'Mínimo: 3, Máximo: 3600',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Insira um valor.';
                      final n = int.tryParse(value);
                      if (n == null || n < 3 || n > 3600) return 'Insira um valor entre 3 e 3600.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveSettings,
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
              : const Text('Salvar Alterações'),
        ),
      ),
    );
  }
}