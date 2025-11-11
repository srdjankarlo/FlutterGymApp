import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../models/muscle_model.dart';
import '../models/exercise_model.dart';
import '../models/set_model.dart';

class PersonalRecordsPage extends StatefulWidget {
  const PersonalRecordsPage({super.key});

  @override
  State<PersonalRecordsPage> createState() => _PersonalRecordsPageState();
}

class _PersonalRecordsPageState extends State<PersonalRecordsPage> {
  final AppDatabase db = AppDatabase.instance;

  List<MuscleModel> muscles = [];
  List<ExerciseModel> exercises = [];
  List<SetModel> sets = [];

  MuscleModel? selectedMuscle;
  ExerciseModel? selectedExercise;

  // scroll controllers for charts
  final ScrollController _weightScrollController = ScrollController();
  final ScrollController _repsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMuscles();
  }

  @override
  void dispose() {
    _weightScrollController.dispose();
    _repsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMuscles() async {
    final data = await db.getAllMuscles();
    setState(() => muscles = data);
  }

  Future<void> _loadExercises(int muscleId) async {
    final data = await db.getExercisesByMuscle(muscleId);
    setState(() {
      exercises = data;
      selectedExercise = null;
      sets = [];
    });
  }

  Future<void> _loadSets(int exerciseId) async {
    // ensure typed list
    final List<SetModel> data = await db.getSetsByExercise(exerciseId);
    setState(() => sets = data);
  }

  // ----------------------------
  // Filtering logic (per-day)
  // ----------------------------

  // returns per-day max weight (with reps) included only when:
  // - first day (defines floor)
  // - weight >= firstWeight
  // - weight > prevMaxWeight OR (weight == some recorded weight AND reps > recorded best reps for that weight)
  List<SetModel> _filterMaxWeightPerDayWithRules(List<SetModel> allSets) {
    if (allSets.isEmpty) return [];

    final sorted = List<SetModel>.from(allSets)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // group by day -> pick that day's max weight (if multiple with same max weight take the one with more reps)
    final Map<String, SetModel> dayBest = {};
    for (final s in sorted) {
      final day = DateFormat('yyyy-MM-dd').format(s.timestamp);
      final current = dayBest[day];
      if (current == null) {
        dayBest[day] = s;
      } else {
        if (s.weight > current.weight) {
          dayBest[day] = s;
        } else if (s.weight == current.weight && s.reps > current.reps) {
          dayBest[day] = s;
        }
      }
    }

    final days = dayBest.keys.toList()..sort();
    if (days.isEmpty) return [];

    final List<SetModel> result = [];

    // floor = first day's max weight
    final firstDay = days.first;
    final firstBest = dayBest[firstDay]!;
    final double floorWeight = firstBest.weight;
    // track best reps seen so far per weight (for same weight improvements)
    final Map<double, int> bestRepsForWeight = {};

    double prevMaxWeight = firstBest.weight;
    // init with first
    bestRepsForWeight[prevMaxWeight] = firstBest.reps;
    result.add(firstBest);

    // iterate days in chronological order, skipping the first (already added)
    for (var i = 1; i < days.length; i++) {
      final day = days[i];
      final s = dayBest[day]!;
      // ignore if below floorWeight
      if (s.weight < floorWeight) continue;

      // if weight greater than prev overall max -> include and update prevMaxWeight
      if (s.weight > prevMaxWeight) {
        prevMaxWeight = s.weight;
        bestRepsForWeight[s.weight] = s.reps;
        result.add(s);
        continue;
      }

      // if same weight as some already recorded weight and reps improved -> include & update best reps
      final recordedReps = bestRepsForWeight[s.weight];
      if (recordedReps == null) {
        // weight is <= prevMaxWeight but not recorded before: do nothing (we only track improvements for recorded weights)
        continue;
      } else {
        if (s.reps > recordedReps) {
          bestRepsForWeight[s.weight] = s.reps;
          result.add(s);
          // if this weight equals prevMaxWeight and reps improved, prevMaxWeight remains the same but its recorded reps improved
          continue;
        }
      }
      // otherwise ignore (no improvement, and not above prev max)
    }

    return result;
  }

  // reps version: per-day max reps -> include only if >= firstDay reps floor,
  // include if reps > prevMaxReps OR (reps == recorded reps and weight > recorded best weight)
  List<SetModel> _filterMaxRepsPerDayWithRules(List<SetModel> allSets) {
    if (allSets.isEmpty) return [];

    final sorted = List<SetModel>.from(allSets)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // group by day -> pick that day's max reps (if multiple with same reps take the one with bigger weight)
    final Map<String, SetModel> dayBest = {};
    for (final s in sorted) {
      final day = DateFormat('yyyy-MM-dd').format(s.timestamp);
      final current = dayBest[day];
      if (current == null) {
        dayBest[day] = s;
      } else {
        if (s.reps > current.reps) {
          dayBest[day] = s;
        } else if (s.reps == current.reps && s.weight > current.weight) {
          dayBest[day] = s;
        }
      }
    }

    final days = dayBest.keys.toList()..sort();
    if (days.isEmpty) return [];

    final List<SetModel> result = [];

    final firstDay = days.first;
    final firstBest = dayBest[firstDay]!;
    final int floorReps = firstBest.reps;

    int prevMaxReps = firstBest.reps;
    final Map<int, double> bestWeightForReps = {};
    bestWeightForReps[prevMaxReps] = firstBest.weight;
    result.add(firstBest);

    for (var i = 1; i < days.length; i++) {
      final day = days[i];
      final s = dayBest[day]!;
      if (s.reps < floorReps) continue;

      if (s.reps > prevMaxReps) {
        prevMaxReps = s.reps;
        bestWeightForReps[s.reps] = s.weight;
        result.add(s);
        continue;
      }

      final recordedWeight = bestWeightForReps[s.reps];
      if (recordedWeight == null) {
        // reps <= prevMaxReps but not recorded before -> ignore
        continue;
      } else {
        if (s.weight > recordedWeight) {
          bestWeightForReps[s.reps] = s.weight;
          result.add(s);
          continue;
        }
      }
    }

    return result;
  }

  // ----------------------------
  // Chart builder (scrolls, last 3 visible, padding, labels)
  // ----------------------------

  Widget _buildScrollableChartWidget({
    required List<SetModel> filteredData,
    required bool isWeightChart,
    required ScrollController controller,
  }) {
    if (filteredData.isEmpty) return const SizedBox.shrink();

    // compute Y range with a small padding (avoid min==max)
    final yVals = filteredData.map((s) => isWeightChart ? s.weight : s.reps.toDouble()).toList();
    double minY = yVals.reduce((a, b) => a < b ? a : b);
    double maxY = yVals.reduce((a, b) => a > b ? a : b);
    // add absolute padding so small ranges don't flatten
    final pad = isWeightChart ? (maxY - minY) * 0.1 : (maxY - minY) * 0.15;
    final fudge = pad == 0 ? (isWeightChart ? 5.0 : 1.0) : pad;
    minY = (minY - fudge);
    maxY = (maxY + fudge);

    final int pointCount = filteredData.length;
    const double pointSpacing = 120.0; // px per point
    final double chartWidth = (pointCount) * pointSpacing;
    const double chartHeight = 300.0;
    const double labelHeight = 36.0;
    const double horizontalPaddingSteps = 0.5; // left/right half-step

    // After build, auto-scroll to show last 3 points (rightmost end)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      final viewportWidth = MediaQuery.of(context).size.width - 24; // account for page padding (12+12)
      // target to show last 3 points => scroll so that rightmost point is visible with some padding
      final targetScroll = (chartWidth - viewportWidth).clamp(0.0, chartWidth);
      if (targetScroll > 0) controller.jumpTo(targetScroll);
    });

    return SizedBox(
      height: chartHeight,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: chartWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LineChart(
                LineChartData(
                  minX: -horizontalPaddingSteps,
                  maxX: (pointCount - 1) + horizontalPaddingSteps,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (val, meta) {
                          final i = val.toInt();

                          // only show labels for actual integer indices that correspond to data points
                          final bool isDataPoint = (i >= 0 && i < filteredData.length && val == i.toDouble());
                          if (!isDataPoint) return const SizedBox();

                          final dt = filteredData[i].timestamp;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(dt),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: filteredData.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), (isWeightChart ? e.value.weight : e.value.reps.toDouble()));
                      }).toList(),
                      isCurved: false,
                      color: isWeightChart ? Colors.blueAccent : Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),

              // Floating labels placed above each point, clamped inside chart height
              ...filteredData.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final yValue = isWeightChart ? s.weight : s.reps.toDouble();
                final label = isWeightChart ? '${s.weight}kg\n${s.reps}x' : '${s.reps}x\n${s.weight}kg';

                // compute vertical position relative to data value
                final normalized = (yValue - minY) / (maxY - minY); // 0..1
                // clamp to avoid NaN
                final double clampedNorm = normalized.isFinite ? normalized.clamp(0.0, 1.0) : 0.0;
                final double yPxFromTop = (1.0 - clampedNorm) * chartHeight;

                double topPos = yPxFromTop - labelHeight - 6; // label above point with small gap
                topPos = topPos.clamp(0.0, chartHeight - labelHeight); // clamp inside chart

                final leftPos = idx * pointSpacing; // align horizontally per point

                return Positioned(
                  left: leftPos,
                  top: topPos,
                  child: SizedBox(
                    width: pointSpacing,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------
  // Build
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    final List<SetModel> maxWeightSets =
    selectedExercise == null ? [] : _filterMaxWeightPerDayWithRules(sets);
    final List<SetModel> maxRepsSets =
    selectedExercise == null ? [] : _filterMaxRepsPerDayWithRules(sets);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Records')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Muscle dropdown
              DropdownButton<MuscleModel>(
                isExpanded: true,
                value: selectedMuscle,
                hint: const Text('Select muscle'),
                items: muscles.map((m) => DropdownMenuItem(value: m, child: Text(m.name))).toList(),
                onChanged: (m) {
                  if (m != null) {
                    _loadExercises(m.id);
                    setState(() => selectedMuscle = m);
                  }
                },
              ),
              const SizedBox(height: 10),

              // Exercise dropdown
              DropdownButton<ExerciseModel>(
                isExpanded: true,
                value: selectedExercise,
                hint: const Text('Select exercise'),
                items: exercises.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                onChanged: (e) {
                  if (e != null) {
                    _loadSets(e.id!);
                    setState(() => selectedExercise = e);
                  }
                },
              ),
              const SizedBox(height: 20),

              if (sets.isEmpty)
                const Text('No data for selected exercise.')
              else ...[
                const Text('Max Weight Over Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildScrollableChartWidget(filteredData: maxWeightSets, isWeightChart: true, controller: _weightScrollController),
                const SizedBox(height: 30),
                const Text('Max Reps Over Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildScrollableChartWidget(filteredData: maxRepsSets, isWeightChart: false, controller: _repsScrollController),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
