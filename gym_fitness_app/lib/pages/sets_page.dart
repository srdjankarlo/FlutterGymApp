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
    final setText = _setController.text.trim();
    final repsText = _repsController.text.trim();
    final weightText = _weightController.text.trim();

    bool hasError = false;

    if (setText.isEmpty) {
      hasError = true;
    }
    if (repsText.isEmpty) {
      hasError = true;
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in Set and Reps')),
      );
      return;
    }

    final setNum = int.tryParse(setText);
    final reps = int.tryParse(repsText);
    double weight = double.tryParse(weightText) ?? 0;
    if (weight == 0) weight = 1;

    if (setNum! < 1 || reps! < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid input. Set and Reps must be at least 1')),
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
    final primaryColor = Theme.of(context).colorScheme.secondary;
    final surfaceColor = Theme.of(context).colorScheme.surface;
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
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // ===== Input Section =====
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: surfaceColor,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          // Workout Timer Row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _toggleTimer(isWork: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isWorkTimerRunning
                                        ? Colors.red   // Stop = red
                                        : Colors.green, // Start = green
                                    padding: const EdgeInsets.symmetric(vertical: 25),
                                  ),
                                  child: Text(
                                    _isWorkTimerRunning ? 'Stop Workout' : 'Start Workout',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _valueBox(formatSeconds(_workSeconds), 10, 25),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _resetTimer(isWork: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                    padding: const EdgeInsets.symmetric(vertical: 25),
                                  ),
                                  child: const Text(
                                    'Reset',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          // Input Fields
                          Row(
                            children: [
                              Flexible(
                                flex: 2,
                                child: TextField(
                                  controller: _setController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 25),
                                  decoration: const InputDecoration(
                                    hintText: 'Set', // this text disappears when typing
                                    hintStyle: TextStyle(fontSize: 25),
                                    border: OutlineInputBorder(),
                                    isDense: true, // compact spacing
                                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                flex: 5,
                                child: TextField(
                                  controller: _weightController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 25),
                                  decoration: InputDecoration(
                                    hintText: 'Weight ($_unit)', // dynamic placeholder
                                    hintStyle: TextStyle(fontSize: 25),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                flex: 3,
                                child: TextField(
                                  controller: _repsController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 25),
                                  decoration: const InputDecoration(
                                    hintText: 'Reps',
                                    hintStyle: TextStyle(fontSize: 25),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          // Rest Timer Row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _toggleTimer(isWork: false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isRestTimerRunning
                                        ? Colors.red   // Stop = red
                                        : Colors.green, // Start = green
                                    padding: const EdgeInsets.symmetric(vertical: 25),
                                  ),
                                  child: Text(
                                    _isRestTimerRunning ? 'Stop Rest' : 'Start Rest',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _valueBox(formatSeconds(_restSeconds), 10, 25),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _resetTimer(isWork: false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                    padding: const EdgeInsets.symmetric(vertical: 25),
                                  ),
                                  child: const Text(
                                    'Reset',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
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
                  // ===== Blueprint Row =====
                  Card(
                    color: primaryColor,
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              Flexible(flex: 1, child: Center(child: Text('Set'))),
                              Flexible(flex: 2, child: Center(child: Text('Weight'))),
                              Flexible(flex: 2, child: Center(child: Text('Reps'))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              Flexible(flex: 2, child: Center(child: Text('Date'))),
                              Flexible(flex: 1, child: Center(child: Text('Workout'))),
                              Flexible(flex: 1, child: Center(child: Text('Rest'))),
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
                      final scheme = Theme.of(context).colorScheme;
                      final primaryColor = scheme.primaryContainer;

                      // Group sets by date (yyyy-MM-dd)
                      final Map<String, List<SetModel>> grouped = {};
                      for (final set in sets) {
                        final dateKey = DateFormat('yyyy-MM-dd').format(set.timestamp);
                        grouped.putIfAbsent(dateKey, () => []).add(set);
                      }

                      // Sort the groups by date (descending)
                      final sortedDates = grouped.keys.toList()
                        ..sort((a, b) => b.compareTo(a));

                      // Build collapsible grouped list
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: sortedDates.map((dateKey) {
                          final dateSets = grouped[dateKey]!;
                          final displayDate =
                          DateFormat('dd.MM.yyyy').format(DateTime.parse(dateKey));

                          // Calculate total sets, reps, volume for this date
                          int totalSets = dateSets.length;
                          int totalReps = dateSets.fold(0, (sum, set) => sum + set.reps);
                          double totalVolume = dateSets.fold(0.0, (sum, set) {
                            double weight = set.weight;
                            if (weight == 0) weight = 1; // treat bodyweight as 1 for now
                            return sum + (weight * set.reps);
                          });

                          return Card(
                            color: scheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 3,
                            child: Theme(
                              // 👇 Make the tile background match color scheme
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true, // 👈 expand by default (optional)
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayDate,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Sets: $totalSets  Volume: ${totalVolume.toStringAsFixed(1)} $_unit  Reps: $totalReps',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                children: dateSets.map((set) {
                                  return GestureDetector(
                                    onTap: () async {
                                      final result = await showDialog(
                                        context: context,
                                        builder: (_) => EditSetDialog(set: set, unit: _unit),
                                      );
                                      if (result == true) {
                                        _loadSets();
                                      }
                                    },
                                    child: Card(
                                      color: primaryColor,
                                      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Column(
                                          children: [
                                            // Row 1: Set, Weight, Reps
                                            Row(
                                              children: [
                                                Flexible(flex: 1, child: _valueBox('${set.setNumber}', 4, 13)),
                                                Flexible(flex: 2, child: _valueBox(
                                                    '${_displayWeight(set.weight).toStringAsFixed(1)} $_unit', 4, 13)),
                                                Flexible(flex: 2, child: _valueBox('${set.reps}', 4, 13)),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            // Row 2: Time, Work, Rest
                                            Row(
                                              children: [
                                                Flexible(flex: 2, child: _valueBox(
                                                    DateFormat('HH:mm:ss').format(set.timestamp), 4, 13)),
                                                Flexible(flex: 1, child: _valueBox(formatSeconds(set.workTime), 4, 13)),
                                                Flexible(flex: 1, child: _valueBox(formatSeconds(set.restTime), 4, 13)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
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

  Widget _valueBox(String value, double verticalPad, double fontSize) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      padding: EdgeInsets.symmetric(vertical: verticalPad),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey),
      ),
      child: Center(
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: fontSize),
          )),
    );
  }
}
