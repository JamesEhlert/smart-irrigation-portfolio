// lib/screens/schedules/schedule_edit_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ScheduleEditScreen extends StatefulWidget {
  final String deviceId;
  final DocumentSnapshot? scheduleDocument;

  const ScheduleEditScreen({
    super.key,
    required this.deviceId,
    this.scheduleDocument,
  });

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  TimeOfDay? _selectedTime;
  final _durationController = TextEditingController();
  final Map<String, String> _weekdays = {
    'monday': 'Segunda', 'tuesday': 'Terça', 'wednesday': 'Quarta',
    'thursday': 'Quinta', 'friday': 'Sexta', 'saturday': 'Sábado', 'sunday': 'Domingo',
  };
  final Map<String, bool> _selectedDays = {
    'monday': false, 'tuesday': false, 'wednesday': false, 'thursday': false,
    'friday': false, 'saturday': false, 'sunday': false,
  };
  bool _isEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.scheduleDocument != null) {
      final data = widget.scheduleDocument!.data() as Map<String, dynamic>;
      
      _durationController.text = data['durationMinutes']?.toString() ?? '';
      _isEnabled = data['isEnabled'] ?? true;

      final timeParts = (data['startTime'] as String).split(':');
      _selectedTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));

      final daysFromDb = List<String>.from(data['daysOfWeek'] ?? []);
      for (var dayKey in daysFromDb) {
        if (_selectedDays.containsKey(dayKey)) {
          _selectedDays[dayKey] = true;
        }
      }
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  Future<void> _deleteSchedule() async {
    if (widget.scheduleDocument == null) return;
    
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Você tem certeza que deseja apagar este agendamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    
    if (shouldDelete ?? false) {
      try {
        await _firestore
            .collection('users').doc(_auth.currentUser!.uid).collection('devices').doc(widget.deviceId)
            .collection('schedules').doc(widget.scheduleDocument!.id)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agendamento excluído com sucesso!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveSchedule() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma hora de início.')),
      );
      return;
    }

    final selectedDayKeys = _selectedDays.entries.where((e) => e.value).map((e) => e.key).toList();

    if (selectedDayKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione pelo menos um dia da semana.')),
      );
      return;
    }

    setState(() { _isSaving = true; });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final scheduleData = {
        'startTime': '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
        'durationMinutes': int.parse(_durationController.text.trim()),
        'daysOfWeek': selectedDayKeys,
        'isEnabled': _isEnabled,
      };

      final docRef = _firestore
          .collection('users').doc(user.uid).collection('devices').doc(widget.deviceId)
          .collection('schedules');
      
      if (widget.scheduleDocument != null) {
        await docRef.doc(widget.scheduleDocument!.id).update(scheduleData);
      } else {
        await docRef.add(scheduleData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agendamento salvo com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar agendamento: $e')),
        );
      }
    } 
    finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.scheduleDocument != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Editar Agendamento' : 'Novo Agendamento'),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    title: const Text('Agendamento Ativo'),
                    value: _isEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isEnabled = value;
                      });
                    },
                    secondary: const Icon(Icons.power_settings_new),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Hora de Início'),
                    subtitle: Text(_selectedTime?.format(context) ?? 'Não selecionada'),
                    onTap: () => _selectTime(context),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duração (minutos)',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    // --- ERRO CORRIGIDO AQUI ---
                    // Corrigido de 'TextInput.number' para 'TextInputType.number'
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty || int.tryParse(val.trim()) == null || int.parse(val.trim()) <= 0) {
                        return 'Insira uma duração válida em minutos.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Repetir nos dias:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ..._weekdays.entries.map((entry) {
                    return CheckboxListTile(
                      title: Text(entry.value),
                      value: _selectedDays[entry.key],
                      onChanged: (bool? value) {
                        setState(() {
                          _selectedDays[entry.key] = value!;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isEditMode)
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                  onPressed: _deleteSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (isEditMode) const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Salvar'),
                onPressed: _isSaving ? null : _saveSchedule,
              ),
            ),
          ],
        ),
      ),
    );
  }
}