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

  // Stopwatch state
  DateTime? _workStartTime;
  DateTime? _restStartTime;
  Duration _elapsedWork = Duration.zero;
  Duration _elapsedRest = Duration.zero;
  Timer? _uiTimer; // updates the screen every second

  bool get _isWorkRunning => _workStartTime != null;
  bool get _isRestRunning => _restStartTime != null;

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

  void _toggleStopwatch({required bool isWork}) {
    if (isWork) {
      if (_isWorkRunning) {
        _pauseStopwatch(isWork: true);
      } else {
        _startStopwatch(isWork: true);
      }
    } else {
      if (_isRestRunning) {
        _pauseStopwatch(isWork: false);
      } else {
        _startStopwatch(isWork: false);
      }
    }
  }

  void _startStopwatch({required bool isWork}) {
    if (isWork) {
      _workStartTime = DateTime.now();
    } else {
      _restStartTime = DateTime.now();
    }

    _uiTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  void _pauseStopwatch({required bool isWork}) {
    final now = DateTime.now();
    if (isWork && _workStartTime != null) {
      _elapsedWork += now.difference(_workStartTime!);
      _workStartTime = null;
    } else if (!isWork && _restStartTime != null) {
      _elapsedRest += now.difference(_restStartTime!);
      _restStartTime = null;
    }

    // stop UI timer if both are paused
    if (!_isWorkRunning && !_isRestRunning) {
      _uiTimer?.cancel();
      _uiTimer = null;
    }

    setState(() {});
  }

  void _resetStopwatch({required bool isWork}) {
    if (isWork) {
      _workStartTime = null;
      _elapsedWork = Duration.zero;
    } else {
      _restStartTime = null;
      _elapsedRest = Duration.zero;
    }

    if (!_isWorkRunning && !_isRestRunning) {
      _uiTimer?.cancel();
      _uiTimer = null;
    }

    setState(() {});
  }

  Duration get _currentWorkTime {
    if (_isWorkRunning) {
      return _elapsedWork + DateTime.now().difference(_workStartTime!);
    }
    return _elapsedWork;
  }

  Duration get _currentRestTime {
    if (_isRestRunning) {
      return _elapsedRest + DateTime.now().difference(_restStartTime!);
    }
    return _elapsedRest;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
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

    final workTimeToStore = _currentWorkTime.inSeconds;
    final restTimeToStore = _currentRestTime.inSeconds;

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

    _resetStopwatch(isWork: true);
    _resetStopwatch(isWork: false);

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
              // padding: const EdgeInsets.all(8),
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
                                  onPressed: () => _toggleStopwatch(isWork: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isWorkRunning
                                        ? Colors.red   // Stop = red
                                        : Colors.green, // Start = green
                                    padding: const EdgeInsets.symmetric(vertical: 30),
                                  ),
                                  child: Text(
                                    _isWorkRunning ? 'Stop Workout' : 'Start Workout',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _valueBox(_formatDuration(_currentWorkTime), 10, 30),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                onPressed: () => _resetStopwatch(isWork: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                                ),
                                child: const Text(
                                  'Reset',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 22),
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
                                  style: const TextStyle(fontSize: 30),
                                  decoration: const InputDecoration(
                                    hintText: 'Set', // this text disappears when typing
                                    hintStyle: TextStyle(fontSize: 30),
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
                                  style: const TextStyle(fontSize: 30),
                                  decoration: InputDecoration(
                                    hintText: 'Weight ($_unit)', // dynamic placeholder
                                    hintStyle: TextStyle(fontSize: 30),
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
                                  style: const TextStyle(fontSize: 30),
                                  decoration: const InputDecoration(
                                    hintText: 'Reps',
                                    hintStyle: TextStyle(fontSize: 30),
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
                                  onPressed: () => _toggleStopwatch(isWork: false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isRestRunning
                                        ? Colors.red   // Stop = red
                                        : Colors.green, // Start = green
                                    padding: const EdgeInsets.symmetric(vertical: 30),
                                  ),
                                  child: Text(
                                    _isRestRunning ? 'Stop Rest' : 'Start Rest',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _valueBox(_formatDuration(_currentRestTime), 10, 30),
                              const SizedBox(width: 4),
                              ElevatedButton(
                                onPressed: () => _resetStopwatch(isWork: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                                ),
                                child: const Text(
                                  'Reset',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 22),
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
                                padding: const EdgeInsets.symmetric(vertical: 20),
                              ),
                              child: const Text('Input Set Data',
                                style: TextStyle(fontSize: 22),
                              ),
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

                          // Calculate total sets, reps, and volume for this date
                          int totalSets = dateSets.length;
                          int totalReps = dateSets.fold(0, (sum, set) => sum + set.reps);
                          double totalVolume = dateSets.fold(0.0, (sum, set) {
                            double weight = set.weight;
                            if (weight == 0) weight = 1; // treat bodyweight as 1 for now
                            return sum + (weight * set.reps);
                          });

                          // Calculate total work and rest time (in seconds)
                          int totalWork = dateSets.fold(0, (sum, set) => sum + set.workTime);
                          int totalRest = dateSets.fold(0, (sum, set) => sum + set.restTime);

                          return Card(
                            color: scheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 3,
                            child: Theme(
                              // Make the tile background match color scheme
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true, // expand by default (optional)
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // DATE centered
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

                                    // ROW 1: Sets / Volume / Reps
                                    Row(
                                      children: [
                                        Flexible(
                                          flex: 1,
                                          child: Center(child:
                                          Text(
                                            'Sets: $totalSets',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: scheme.primary,
                                            ),
                                          ),
                                          )
                                        ),
                                        Flexible(
                                          flex: 2,
                                          child: Center(child:
                                          Text(
                                            'Volume: ${totalVolume.toStringAsFixed(1)} $_unit',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: scheme.primary,
                                            ),
                                          ),
                                          )
                                        ),
                                        Flexible(
                                          flex: 1,
                                          child: Center(
                                            child: Text(
                                                'Reps: $totalReps',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: scheme.primary,
                                                ),
                                            ),
                                          )
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),

                                    // ROW 2: Work / Rest / Total
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Work: ${_formatDuration(Duration(seconds: totalWork))}',
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
                                            'Rest: ${_formatDuration(Duration(seconds: totalRest))}',
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
                                            'Total: ${_formatDuration(Duration(seconds: (totalWork + totalRest)))}',
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
                                        _loadSets(); // refresh the list
                                      } else {
                                        // Set was updated
                                        _loadSets();
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
                                            // Row 1: Set, Weight, Reps
                                            Row(
                                              children: [
                                                Flexible(flex: 1, child: _valueBox('${set.setNumber}', 4, 13)),
                                                Flexible(flex: 1, child: _valueBox('${_displayWeight(set.weight).toStringAsFixed(1)} $_unit', 4, 13)),
                                                Flexible(flex: 1, child: _valueBox('${set.reps}', 4, 13)),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            // Row 2: Time, Work, Rest
                                            Row(
                                              children: [
                                                Flexible(flex: 1, child: _valueBox(DateFormat('HH:mm:ss').format(set.timestamp), 4, 13)),
                                                Flexible(flex: 1, child: _valueBox(_formatDuration(Duration(seconds: set.workTime)), 4, 13)),
                                                Flexible(flex: 1, child: _valueBox(_formatDuration(Duration(seconds: set.restTime)), 4, 13)),
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
      constraints: const BoxConstraints(minWidth: 50), // ensure width doesn't shrink too much
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: EdgeInsets.symmetric(vertical: verticalPad, horizontal: 4), // extra horizontal padding
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
