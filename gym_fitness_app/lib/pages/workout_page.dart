import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/muscle_model.dart';
import '../models/exercise_model.dart';
import '../models/set_model.dart';
import '../providers/unit_provider.dart';
import '../widgets/sets_settings_drawer.dart';
import '../widgets/edit_set_dialog.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  MuscleModel? _selectedMuscle;
  ExerciseModel? _selectedExercise;

  final TextEditingController _setController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  int _workSeconds = 0;
  int _restSeconds = 0;
  Timer? _workTimer;
  Timer? _restTimer;
  bool _isWorkTimerRunning = false;
  bool _isRestTimerRunning = false;

  late Future<List<MuscleModel>> _musclesFuture;
  Future<List<ExerciseModel>>? _exercisesFuture;
  Future<List<SetModel>>? _setsFuture;

  @override
  void initState() {
    super.initState();
    _musclesFuture = AppDatabase.instance.getAllMuscles();
  }

  void _loadExercises(int muscleId) {
    setState(() {
      _selectedExercise = null;
      _exercisesFuture = AppDatabase.instance.getExercisesByMuscle(muscleId);
    });
  }

  void _loadSets(int exerciseId) {
    setState(() {
      _setsFuture = AppDatabase.instance.getSetsByExercise(exerciseId);
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
    if (_selectedExercise == null) return;

    final setText = _setController.text.trim();
    final repsText = _repsController.text.trim();
    final weightText = _weightController.text.trim();

    if (setText.isEmpty || repsText.isEmpty) {
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
      exerciseId: _selectedExercise!.id!,
      setNumber: setNum,
      weight: weightToStore,
      reps: reps,
      workTime: workTimeToStore,
      restTime: restTimeToStore,
      timestamp: DateTime.now(),
    );

    await AppDatabase.instance.insertSet(newSet);
    _loadSets(_selectedExercise!.id!);

    _setController.clear();
    _weightController.clear();
    _repsController.clear();
  }

  String formatSeconds(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final twoDigits = (int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitProvider = Provider.of<UnitProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = scheme.primaryContainer;
    final surfaceColor = scheme.surface;
    final _unit = unitProvider.isMetric ? 'kg' : 'lbs';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
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
            // ===== Muscle + Exercise Row =====
            Card(
              color: primaryColor,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: FutureBuilder<List<MuscleModel>>(
                        future: _musclesFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final muscles = snapshot.data!;
                          return DropdownButtonFormField<MuscleModel>(
                            isExpanded: true,
                            dropdownColor: scheme.surface,
                            initialValue: _selectedMuscle,
                            decoration: InputDecoration(
                              labelText: 'Muscle',
                              filled: true,
                              fillColor: surfaceColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: muscles
                                .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.name),
                            ))
                                .toList(),
                            onChanged: (m) {
                              setState(() {
                                _selectedMuscle = m;
                                _selectedExercise = null;
                                _loadExercises(m!.id);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FutureBuilder<List<ExerciseModel>>(
                        future: _exercisesFuture,
                        builder: (context, snapshot) {
                          if (_selectedMuscle == null) {
                            return const Text('Select muscle');
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text('No exercises');
                          }
                          final exercises = snapshot.data!;
                          return DropdownButtonFormField<ExerciseModel>(
                            isExpanded: true,
                            dropdownColor: scheme.surface,
                            initialValue: _selectedExercise,
                            decoration: InputDecoration(
                              labelText: 'Exercise',
                              filled: true,
                              fillColor: surfaceColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: exercises
                                .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.name),
                            ))
                                .toList(),
                            onChanged: (e) {
                              setState(() {
                                _selectedExercise = e;
                                _loadSets(e!.id!);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===== Input Section =====
            if (_selectedExercise != null)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                color: surfaceColor,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      // === Workout Timer Row ===
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _toggleTimer(isWork: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                _isWorkTimerRunning ? Colors.red : Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 25),
                              ),
                              child: Text(
                                _isWorkTimerRunning ? 'Stop Workout' : 'Start Workout',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _valueBox(formatSeconds(_workSeconds), 10, 25),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: () => _resetTimer(isWork: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.secondaryContainer,
                              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                            ),
                            child: const Text('Reset', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // === Input Fields ===
                      Row(
                        children: [
                          Flexible(
                            flex: 2,
                            child: TextField(
                              controller: _setController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 20),
                              decoration: const InputDecoration(
                                hintText: 'Set',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 3,
                            child: TextField(
                              controller: _weightController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 20),
                              decoration: InputDecoration(
                                hintText: 'Weight ($_unit)',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 3,
                            child: TextField(
                              controller: _repsController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 20),
                              decoration: const InputDecoration(
                                hintText: 'Reps',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // === Rest Timer Row ===
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _toggleTimer(isWork: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                _isRestTimerRunning ? Colors.red : Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                              ),
                              child: Text(
                                _isRestTimerRunning ? 'Stop Rest' : 'Start Rest',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _valueBox(formatSeconds(_restSeconds), 10, 20),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: () => _resetTimer(isWork: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.secondaryContainer,
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                            ),
                            child: const Text('Reset', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _inputSetData(unitProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Input Set Data', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_selectedExercise != null)
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
                          Flexible(flex: 1, child: Center(child: Text('Weight'))),
                          Flexible(flex: 1, child: Center(child: Text('Reps'))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: const [
                          Flexible(flex: 1, child: Center(child: Text('Date'))),
                          Flexible(flex: 1, child: Center(child: Text('Workout'))),
                          Flexible(flex: 1, child: Center(child: Text('Rest'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            // ===== Sets List =====
            if (_setsFuture != null)
              FutureBuilder<List<SetModel>>(
                // future: AppDatabase.instance.getSetsByExercise(_selectedExercise!.id!), // adjust as needed
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

                  // Group sets by date
                  final Map<String, List<SetModel>> grouped = {};
                  for (final set in sets) {
                    final dateKey = DateFormat('yyyy-MM-dd').format(set.timestamp);
                    grouped.putIfAbsent(dateKey, () => []).add(set);
                  }

                  // Sort descending (newest date first)
                  final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                  // Helper to format seconds as mm:ss
                  String formatSeconds(int seconds) {
                    final m = (seconds ~/ 60).toString().padLeft(2, '0');
                    final s = (seconds % 60).toString().padLeft(2, '0');
                    return '$m:$s';
                  }

                  double _displayWeight(double w) => w == 0 ? 1 : w; // bodyweight fix

                  Widget _valueBox(String value, double pad, double size) {
                    return Container(
                      padding: EdgeInsets.all(pad),
                      alignment: Alignment.center,
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: size,
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: sortedDates.map((dateKey) {
                      final dateSets = grouped[dateKey]!;
                      final displayDate = DateFormat('dd.MM.yyyy').format(DateTime.parse(dateKey));

                      int totalSets = dateSets.length;
                      int totalReps = dateSets.fold(0, (sum, s) => sum + s.reps);
                      double totalVolume = dateSets.fold(0.0, (sum, s) => sum + (_displayWeight(s.weight) * s.reps));
                      int totalWork = dateSets.fold(0, (sum, s) => sum + s.workTime);
                      int totalRest = dateSets.fold(0, (sum, s) => sum + s.restTime);

                      return Card(
                        color: scheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 3,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Center(
                                  child: Text(
                                    displayDate,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Summary Row 1
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Sets: $totalSets',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Volume: ${totalVolume.toStringAsFixed(1)} $_unit',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Reps: $totalReps',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 2),

                                // Summary Row 2
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Work: ${formatSeconds(totalWork)}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Rest: ${formatSeconds(totalRest)}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Total: ${formatSeconds(totalWork + totalRest)}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            children: dateSets.map((set) {
                              return GestureDetector(
                                onTap: () async {
                                  final updatedSet = await showDialog<SetModel>(
                                    context: context,
                                    builder: (_) => EditSetDialog(set: set, unit: _unit),
                                  );
                                  if (updatedSet == null) {
                                    setState(() {}); // refresh view
                                  } else {
                                    setState(() {});
                                  }
                                },
                                child: Card(
                                  color: primaryColor,
                                  margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(flex: 1, child: _valueBox('${set.setNumber}', 4, 13)),
                                            Flexible(flex: 1, child: _valueBox('${_displayWeight(set.weight).toStringAsFixed(1)} $_unit', 4, 13)),
                                            Flexible(flex: 1, child: _valueBox('${set.reps}', 4, 13)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Flexible(flex: 1, child: _valueBox(DateFormat('HH:mm:ss').format(set.timestamp), 4, 13)),
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
  }

  Widget _valueBox(String value, double verticalPad, double fontSize) {
    return Container(
      constraints: const BoxConstraints(minWidth: 50),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: EdgeInsets.symmetric(vertical: verticalPad, horizontal: 4),
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
        ),
      ),
    );
  }

}
