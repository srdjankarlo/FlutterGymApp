import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/exercise_model.dart';
import '../models/set_model.dart';
import '../providers/unit_provider.dart';
import '../widgets/edit_set_dialog.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';

class ExerciseLogPage extends StatefulWidget {
  const ExerciseLogPage({super.key});

  @override
  State<ExerciseLogPage> createState() => _ExerciseLogPageState();
}

class _ExerciseLogPageState extends State<ExerciseLogPage> {
  late Future<List<Map<String, dynamic>>> _setsFuture;
  bool _expandPrimary = true;
  bool _expandSecondary = true;

  String _s(dynamic v) => (v ?? "").toString().trim();
  int _i(dynamic v) => int.tryParse(_s(v)) ?? 0;
  double _d(dynamic v) => double.tryParse(_s(v)) ?? 0;

  DateTime _dt(dynamic v) {
    final s = _s(v);
    return s.isEmpty ? DateTime.now() : (DateTime.tryParse(s) ?? DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  void _loadSets() async {
    setState(() {
      _setsFuture = _getSetsWithExerciseNames();
    });
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

  double _displayWeight(double weight, String unit) {
    return unit == 'lbs' ? weight * 2.20462 : weight;
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
    final unitProvider = Provider.of<UnitProvider>(context); // safe inside build
    final unit = unitProvider.isMetric ? 'kg' : 'lbs';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Log'),
        actions: [
          IconButton(
            tooltip: _expandPrimary ? 'Collapse all days' : 'Expand all days',
            icon: Icon(_expandPrimary ? Icons.unfold_less : Icons.unfold_more),
            onPressed: () {
              setState(() {
                _expandPrimary = !_expandPrimary;
                if (!_expandPrimary) _expandSecondary = false; // collapse inner if main collapsed
              });
            },
          ),
          IconButton(
            tooltip: _expandSecondary ? 'Collapse all exercises' : 'Expand all exercises',
            icon: Icon(_expandSecondary ? Icons.expand_less : Icons.expand_more),
            onPressed: _expandPrimary
                ? () {
              setState(() {
                _expandSecondary = !_expandSecondary;
              });
            }
                : null, // disabled if main cards collapsed
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'pdf') {
                await _makePdfReport();
              } else if (value == 'export') {
                await _exportDataToCsv();
              } else if (value == 'import') {
                await _importDataFromCsv();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text('Make PDF report')),
              const PopupMenuItem(value: 'export', child: Text('Export data')),
              const PopupMenuItem(value: 'import', child: Text('Import data')),
            ],
          ),
        ],
      ),
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
                  key: ValueKey('$dateKey-$_expandPrimary'),
                  initiallyExpanded: _expandPrimary,
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
                        key: ValueKey('$dateKey-$exerciseId-$_expandSecondary'),
                        initiallyExpanded: _expandSecondary && _expandPrimary,
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
                                      'Volume: ${totalVolume.toStringAsFixed(1)} $unit',
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
                                await showDialog(
                                  context: context,
                                  builder: (_) => EditSetDialog(set: set, unit: unit),
                                );
                                _loadSets();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _valueBox('${set.setNumber}', 4, 13)),
                                        Expanded(child: _valueBox('${_displayWeight(set.weight, unit).toStringAsFixed(1)} $unit', 4, 13)),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _makePdfReport() async {
    final pdf = pw.Document();
    final setsData = await _getSetsWithExerciseNames();
    final unit = Provider.of<UnitProvider>(context, listen: false).isMetric ? 'kg' : 'lbs';

    final baseFont = pw.Font.courier(); // Simple built-in font

    // Group sets by date
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (final map in setsData) {
      final dateKey = DateFormat('yyyy-MM-dd').format((map['set'] as SetModel).timestamp);
      groupedByDate.putIfAbsent(dateKey, () => []).add(map);
    }

    final sortedDates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          List<pw.Widget> widgets = [];

          for (final dateKey in sortedDates) {
            final dateSets = groupedByDate[dateKey]!;
            final displayDate = DateFormat('dd.MM.yyyy').format(DateTime.parse(dateKey));

            // Date header
            widgets.add(
              pw.Text(displayDate,
                  style: pw.TextStyle(font: baseFont, fontSize: 20, fontWeight: pw.FontWeight.bold)),
            );
            widgets.add(pw.SizedBox(height: 8));

            // Group by exerciseId within this date
            final Map<int, List<Map<String, dynamic>>> exercisesGrouped = {};
            for (final map in dateSets) {
              final set = map['set'] as SetModel;
              exercisesGrouped.putIfAbsent(set.exerciseId, () => []).add(map);
            }

            // Add each exercise under this date
            for (final entry in exercisesGrouped.entries) {
              final exerciseSets = entry.value;
              final exerciseName = exerciseSets.first['exerciseName'] as String;

              widgets.add(
                pw.Text(exerciseName,
                    style: pw.TextStyle(font: baseFont, fontSize: 18, fontWeight: pw.FontWeight.bold)),
              );
              widgets.add(pw.SizedBox(height: 4));

              final totalVolume = exerciseSets.fold<double>(0.0,
                      (sum, e) => sum + ((e['set'] as SetModel).weight * (e['set'] as SetModel).reps));
              final totalWork = exerciseSets.fold<int>(
                  0, (sum, e) => sum + (e['set'] as SetModel).workTime);
              final totalRest = exerciseSets.fold<int>(
                  0, (sum, e) => sum + (e['set'] as SetModel).restTime);

              widgets.add(
                pw.Text('Total Volume: ${totalVolume.toStringAsFixed(1)} $unit, '
                    'Work: ${formatSeconds(totalWork)}, Rest: ${formatSeconds(totalRest)}',
                    style: pw.TextStyle(font: baseFont, fontSize: 12)),
              );
              widgets.add(pw.SizedBox(height: 4));

              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: ['Set', 'Weight', 'Reps', 'Work', 'Rest'],
                  data: exerciseSets.map((e) {
                    final s = e['set'] as SetModel;
                    return [
                      s.setNumber.toString(),
                      _displayWeight(s.weight, unit).toStringAsFixed(1),
                      s.reps.toString(),
                      formatSeconds(s.workTime),
                      formatSeconds(s.restTime),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(font: baseFont, fontWeight: pw.FontWeight.bold),
                  cellStyle: pw.TextStyle(font: baseFont),
                ),
              );

              widgets.add(pw.SizedBox(height: 12)); // Space before next exercise
            }
          }
          return widgets;
        },
      ),
    );

    // Save PDF
    Directory? downloads;
    if (Platform.isAndroid) {
      downloads = Directory('/storage/emulated/0/Download');
    } else {
      downloads = await getApplicationDocumentsDirectory();
    }

    final timestamp = DateFormat('ddMMyyyyHHmmss').format(DateTime.now());
    final file = File('${downloads.path}/FitAppReport_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());

    _showMessage("PDF saved as FitAppReport_$timestamp.pdf in ${downloads.path}");
  }

  // CSV export
  Future<void> _exportDataToCsv() async {
    final db = AppDatabase.instance;
    final setsData = await _getSetsWithExerciseNames();
    final exercises = await db.getAllExercises();
    final timestamp = DateFormat('ddMMyyyyHHmmss').format(DateTime.now());

    final List<List<dynamic>> rows = [
      ['exercise_id','exercise_name','primary_muscle_ids','secondary_muscle_ids','set_number','weight','reps','work_time','rest_time','timestamp']
    ];

    for (final map in setsData) {
      final set = map['set'] as SetModel;
      final exercise = exercises.firstWhere((e) => e.id == set.exerciseId);
      rows.add([
        exercise.id,
        exercise.name,
        exercise.primaryMuscleIDs.join(','),
        exercise.secondaryMuscleIDs?.join(',') ?? '',
        set.setNumber,
        set.weight,
        set.reps,
        set.workTime,
        set.restTime,
        set.timestamp.toIso8601String(),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);

    Directory? downloads;
    if (Platform.isAndroid) {
      downloads = Directory('/storage/emulated/0/Download');
    } else {
      downloads = await getApplicationDocumentsDirectory();
    }

    final file = File('${downloads.path}/FitAppData_$timestamp.csv');
    await file.writeAsString(csvString);

    _showMessage("CSV exported as FitAppData_$timestamp.csv in ${downloads.path}");
  }

  // CSV import
  Future<void> _importDataFromCsv() async {
    final db = AppDatabase.instance;

    // Let user pick a CSV file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      if (mounted) _showMessage("CSV import cancelled");
      return;
    }

    final filePath = result.files.single.path!;
    final file = File(filePath);
    final csvString = await file.readAsString();

    final rows = const CsvToListConverter().convert(csvString, eol: '\n');
    if (rows.isEmpty) {
      if (mounted) _showMessage("CSV file is empty");
      return;
    }

    final headers = rows.first.map((e) => _s(e)).toList();
    final dataRows = rows.sublist(1);

    final allExercises = await db.getAllExercises();
    final Map<String, ExerciseModel> exerciseMap = {
      for (var e in allExercises) e.name: e
    };

    final List<SetModel> setsToInsert = [];

    for (final row in dataRows) {
      final rowMap = Map.fromIterables(headers, row);

      final exerciseName = _s(rowMap['exercise_name']);
      if (exerciseName.isEmpty) continue;

      ExerciseModel? exercise = exerciseMap[exerciseName];

      if (exercise == null) {
        final primary = _s(rowMap['primary_muscle_ids'])
            .split(',')
            .where((e) => e.isNotEmpty)
            .map((e) => int.tryParse(e) ?? 0)
            .toList();

        final secondaryString = _s(rowMap['secondary_muscle_ids']);
        final secondary = secondaryString.isNotEmpty
            ? secondaryString
            .split(',')
            .where((e) => e.isNotEmpty)
            .map((e) => int.tryParse(e) ?? 0)
            .toList()
            : null;

        exercise = ExerciseModel(
          name: exerciseName,
          primaryMuscleIDs: primary,
          secondaryMuscleIDs: secondary,
        );

        final newId = await db.insertExercise(exercise);
        exercise = ExerciseModel(
          id: newId,
          name: exerciseName,
          primaryMuscleIDs: primary,
          secondaryMuscleIDs: secondary,
        );

        exerciseMap[exerciseName] = exercise;
      }

      final set = SetModel(
        exerciseId: exercise.id!,
        setNumber: _i(rowMap['set_number']),
        weight: _d(rowMap['weight']),
        reps: _i(rowMap['reps']),
        workTime: _i(rowMap['work_time']),
        restTime: _i(rowMap['rest_time']),
        timestamp: _dt(rowMap['timestamp']),
      );

      setsToInsert.add(set);
    }

    // Batch insert all sets at once
    await db.insertSetsBatch(setsToInsert);

    // Refresh UI after import
    if (mounted) {
      _loadSets();
      _showMessage("CSV imported: $filePath (${setsToInsert.length} sets)");
    }
  }

}
