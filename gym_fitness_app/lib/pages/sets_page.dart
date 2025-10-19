import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/set_model.dart';
import '../providers/unit_provider.dart';
import '../widgets/sets_settings_drawer.dart';
import 'package:intl/intl.dart';
import '../widgets/edit_set_dialog.dart';

class SetsPage extends StatefulWidget {
  final int exerciseId;
  final String exerciseName;
  final String unitSetting; // "kg" or "lbs"

  const SetsPage({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.unitSetting,
  });

  @override
  State<SetsPage> createState() => _SetsPageState();
}

class _SetsPageState extends State<SetsPage> {
  final TextEditingController _setController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  int _workSeconds = 0;
  int _restSeconds = 0;
  Timer? _workTimer;
  Timer? _restTimer;
  bool _isWorkTimerRunning = false;
  bool _isRestTimerRunning = false;

  late Future<List<SetModel>> _setsFuture;
  String get _unit => Provider.of<UnitProvider>(context).isMetric ? 'kg' : 'lbs';

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  void _loadSets() {
    setState(() {
      _setsFuture = AppDatabase.instance.getSetsByExercise(widget.exerciseId);
    });
  }

  void _toggleTimer({required bool isWork}) {
    if (isWork) {
      if (_isWorkTimerRunning) {
        _workTimer?.cancel();
        setState(() => _isWorkTimerRunning = false);
      } else {
        _startTimer(isWork: true);
      }
    } else {
      if (_isRestTimerRunning) {
        _restTimer?.cancel();
        setState(() => _isRestTimerRunning = false);
      } else {
        _startTimer(isWork: false);
      }
    }
  }

  void _startTimer({required bool isWork}) {
    if (isWork) {
      _workTimer?.cancel();
      _workTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _workSeconds++;
          _isWorkTimerRunning = true;
        });
      });
    } else {
      _restTimer?.cancel();
      _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _restSeconds++;
          _isRestTimerRunning = true;
        });
      });
    }
  }

  void _resetTimer({required bool isWork}) {
    if (isWork) {
      _workTimer?.cancel();
      setState(() {
        _workSeconds = 0;
        _isWorkTimerRunning = false;
      });
    } else {
      _restTimer?.cancel();
      setState(() {
        _restSeconds = 0;
        _isRestTimerRunning = false;
      });
    }
  }

  Future<void> _inputSetData(UnitProvider unitProvider) async {
    final setNum = int.tryParse(_setController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());

    if (setNum == null || weight == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill set, weight and reps')),
      );
      return;
    }

    final workTimeToStore = _workSeconds;
    final restTimeToStore = _restSeconds;

    _workTimer?.cancel();
    _restTimer?.cancel();

    setState(() {
      _workSeconds = 0;
      _restSeconds = 0;
      _isWorkTimerRunning = false;
      _isRestTimerRunning = false;
    });

    double weightToStore = unitProvider.isMetric ? weight : weight / 2.20462;

    final newSet = SetModel(
      id: null,
      exerciseId: widget.exerciseId,
      setNumber: setNum,
      weight: weightToStore,
      reps: reps,
      workTime: workTimeToStore,
      restTime: restTimeToStore,
      timestamp: DateTime.now(),
    );

    await AppDatabase.instance.insertSet(newSet);

    setState(() {
      _setController.clear();
      _weightController.clear();
      _repsController.clear();
      _loadSets();
    });
  }

  double _displayWeight(double weightInKg) {
    if (_unit == 'lbs') return weightInKg * 2.20462;
    return weightInKg;
  }

  String formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Consumer<UnitProvider>(
        builder: (context, unitProvider, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text('${widget.exerciseName}: Input Set'),
              actions: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
              ],
            ),
            endDrawer: const SetsSettingsDrawer(),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // ===== Input Section =====
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // Workout Timer Row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _toggleTimer(isWork: true),
                                  style: ElevatedButton.styleFrom(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    _isWorkTimerRunning
                                        ? 'Stop Workout'
                                        : 'Start Workout',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$_workSeconds s',
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _resetTimer(isWork: true),
                                  style: ElevatedButton.styleFrom(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child:
                                  const Text('Reset', textAlign: TextAlign.center),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Input Fields
                          Row(
                            children: [
                              Flexible(
                                flex: 2,
                                child: TextField(
                                  controller: _setController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Set'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 5,
                                child: TextField(
                                  controller: _weightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: 'Weight ($_unit)'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 3,
                                child: TextField(
                                  controller: _repsController,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                  const InputDecoration(labelText: 'Reps'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Rest Timer Row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _toggleTimer(isWork: false),
                                  style: ElevatedButton.styleFrom(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    _isRestTimerRunning ? 'Stop Rest' : 'Start Rest',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$_restSeconds s',
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _resetTimer(isWork: false),
                                  style: ElevatedButton.styleFrom(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child:
                                  const Text('Reset', textAlign: TextAlign.center),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Input Set Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _inputSetData(unitProvider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Input Set Data'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ===== Blueprint Row with App Color Scheme =====
                  Card(
                    color: primaryColor.withOpacity(0.2),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              Expanded(child: Center(child: Text('Set'))),
                              Expanded(child: Center(child: Text('Weight'))),
                              Expanded(child: Center(child: Text('Reps'))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              Expanded(child: Center(child: Text('Date'))),
                              Expanded(child: Center(child: Text('Workout'))),
                              Expanded(child: Center(child: Text('Rest'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ===== Set Cards =====
                  FutureBuilder<List<SetModel>>(
                    future: _setsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('No sets yet.');
                      }

                      final sets = snapshot.data!;
                      return Column(
                        children: sets.map((set) {
                          return GestureDetector(
                            onTap: () async {
                              final result = await showDialog(
                                context: context,
                                builder: (_) =>
                                    EditSetDialog(set: set, unit: _unit),
                              );

                              if (result == true) {
                                _loadSets();
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    // Row 1: Set, Weight, Reps
                                    Row(
                                      children: [
                                        _valueBox('Set: ${set.setNumber}'),
                                        _valueBox(
                                            '${_displayWeight(set.weight).toStringAsFixed(1)} $_unit'),
                                        _valueBox('${set.reps} Reps'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Row 2: Date+Time, Workout, Rest
                                    Row(
                                      children: [
                                        _valueBox(
                                            '${DateFormat('dd.MM.yyyy').format(set.timestamp)}\n${DateFormat('HH:mm').format(set.timestamp)}'),
                                        _valueBox('Work ${formatSeconds(set.workTime)}'),
                                        _valueBox('Rest ${formatSeconds(set.restTime)}'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget _valueBox(String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey),
        ),
        child: Center(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            )),
      ),
    );
  }
}
