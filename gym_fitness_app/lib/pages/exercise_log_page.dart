import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/set_model.dart';
import '../providers/unit_provider.dart';
import '../widgets/edit_set_dialog.dart';

class ExerciseLogPage extends StatefulWidget {
  const ExerciseLogPage({super.key});

  @override
  State<ExerciseLogPage> createState() => _ExerciseLogPageState();
}

class _ExerciseLogPageState extends State<ExerciseLogPage> {
  late Future<List<Map<String, dynamic>>> _setsFuture;
  String get _unit => Provider.of<UnitProvider>(context).isMetric ? 'kg' : 'lbs';

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  void _loadSets() async {
    _setsFuture = _getSetsWithExerciseNames();
  }

  /// Fetch all sets and map each to its exercise name
  Future<List<Map<String, dynamic>>> _getSetsWithExerciseNames() async {
    final db = AppDatabase.instance;
    final sets = await db.getAllSets(); // same as before
    final exercises = await db.getAllExercises(); // you should already have this

    // Build a lookup for exerciseId -> exerciseName
    final Map<int, String> exerciseNames = {
      for (var e in exercises) e.id!: e.name,
    };

    // Merge exercise name into each set
    final setsWithNames = sets.map((set) {
      return {
        'set': set,
        'exerciseName': exerciseNames[set.exerciseId] ?? 'Unknown Exercise',
      };
    }).toList();

    return setsWithNames;
  }

  String formatSeconds(int seconds) {
    final Duration d = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(secs)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(secs)}';
    }
  }

  double _displayWeight(double weight) {
    if (_unit == 'lbs') return weight * 2.20462;
    return weight;
  }

  Widget _valueBox(String value, double vertical, double fontSize) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: EdgeInsets.symmetric(vertical: vertical),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Log')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _setsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No exercises logged yet.'));
          }

          final data = snapshot.data!;
          final sets = data.map((e) => e['set'] as SetModel).toList();
          final exerciseNameMap = {
            for (var e in data) (e['set'] as SetModel).exerciseId: e['exerciseName'] as String
          };

          // --- group by date ---
          final Map<String, List<SetModel>> groupedByDate = {};
          for (final set in sets) {
            final dateKey = DateFormat('yyyy-MM-dd').format(set.timestamp);
            groupedByDate.putIfAbsent(dateKey, () => []).add(set);
          }

          final sortedDates = groupedByDate.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.all(10),
            children: sortedDates.map((dateKey) {
              final dateSets = groupedByDate[dateKey]!;
              final displayDate =
              DateFormat('dd.MM.yyyy').format(DateTime.parse(dateKey));

              // total day times
              int totalWorkDay = dateSets.fold(0, (sum, s) => sum + s.workTime);
              int totalRestDay = dateSets.fold(0, (sum, s) => sum + s.restTime);

              // group by exerciseId
              final Map<int, List<SetModel>> groupedByExercise = {};
              for (final set in dateSets) {
                groupedByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
              }

              return Card(
                color: Theme.of(context).colorScheme.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 3,
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Column(
                    children: [
                      Text(
                        displayDate,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Work
                          Flexible(
                            flex: 1,
                            child: _valueBox('Work:\n${formatSeconds(totalWorkDay)}', 4, 13),
                          ),
                          // Rest
                          Flexible(
                            flex: 1,
                            child: _valueBox('Rest:\n${formatSeconds(totalRestDay)}', 4, 13),
                          ),
                          // Total
                          Flexible(
                            flex: 2,
                            child: _valueBox('Total:\n${formatSeconds(totalWorkDay + totalRestDay)}', 4, 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                  children: groupedByExercise.entries.map((entry) {
                    final exerciseId = entry.key;
                    final exerciseSets = entry.value;
                    final exerciseName =
                        (awaitNameLookup(exerciseId, exerciseNameMap)) ?? 'Exercise #$exerciseId';

                    // Stats for this exercise that day
                    int totalSets = exerciseSets.length;
                    int totalReps = exerciseSets.fold(0, (sum, s) => sum + s.reps);
                    double totalVolume = exerciseSets.fold(0.0, (sum, s) {
                      double weight = s.weight == 0 ? 1 : s.weight;
                      return sum + (weight * s.reps);
                    });
                    int totalWork = exerciseSets.fold(0, (sum, s) => sum + s.workTime);
                    int totalRest = exerciseSets.fold(0, (sum, s) => sum + s.restTime);

                    return Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: ExpansionTile(
                        title: Column(
                          children: [
                            Text(
                              exerciseName,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Flexible(
                                  flex: 1,
                                  child: Center(
                                    child: Text(
                                      'Sets: $totalSets',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  )
                                ),
                                Flexible(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      'Volume: ${totalVolume.toStringAsFixed(1)} $_unit',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  )
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Flexible(
                                  flex: 1,
                                  child: Center(
                                    child:
                                      Text(
                                        'Work: ${formatSeconds(totalWork)}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                  )
                                ),
                                Flexible(
                                  flex: 1,
                                  child: Center(
                                    child:
                                      Text(
                                        'Rest: ${formatSeconds(totalRest)}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                  )
                                ),
                                Flexible(
                                  flex: 1,
                                  child: Center(
                                    child:
                                      Text(
                                        'Total: ${formatSeconds(totalWork + totalRest)}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                  )
                                ),
                              ],
                            ),
                          ],
                        ),
                        children: exerciseSets.map((set) {
                          return Card(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            child: GestureDetector(
                              onTap: () async {
                                // Open edit dialog
                                final editedSet = await showDialog<SetModel>(
                                  context: context,
                                  builder: (_) => EditSetDialog(set: set, unit: _unit),
                                );

                                // Refresh sets
                                setState(() {
                                  _loadSets();
                                });

                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _valueBox('${set.setNumber}', 4, 13)),
                                        Expanded(child: _valueBox('${_displayWeight(set.weight).toStringAsFixed(1)} $_unit', 4, 13)),
                                        Expanded(child: _valueBox('${set.reps}', 4, 13)),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(child: _valueBox(DateFormat('HH:mm:ss').format(set.timestamp), 4, 13)),
                                        Expanded(child: _valueBox(formatSeconds(set.workTime), 4, 13)),
                                        Expanded(child: _valueBox(formatSeconds(set.restTime), 4, 13)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String? awaitNameLookup(int exerciseId, Map<int?, String> nameMap) {
    return nameMap[exerciseId];
  }

}
