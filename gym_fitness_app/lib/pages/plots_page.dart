import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/app_database.dart';
import '../models/set_model.dart';
import '../providers/unit_provider.dart';

class PlotsPage extends StatefulWidget {
  final int exerciseId;
  final String exerciseName;

  const PlotsPage({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  @override
  State<PlotsPage> createState() => _PlotsPageState();
}

class _PlotsPageState extends State<PlotsPage> {
  static const int maxVisiblePoints = 20;

  late Future<List<SetModel>> _setsFuture;

  final _topCtrl = ScrollController();
  final _middleCtrl = ScrollController();
  final _bottomCtrl = ScrollController();
  late final List<ScrollController> _controllers;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _setsFuture = AppDatabase.instance.getSetsByExercise(widget.exerciseId);

    _controllers = [_topCtrl, _middleCtrl, _bottomCtrl];

    for (final ctrl in _controllers) {
      ctrl.addListener(() => _onScroll(ctrl));
    }
  }

  void _onScroll(ScrollController source) {
    if (_syncing || !source.hasClients) return;
    _syncing = true;

    for (final ctrl in _controllers) {
      if (ctrl == source || !ctrl.hasClients) continue;
      ctrl.jumpTo(source.offset);
    }

    _syncing = false;
  }


  // ---------- HELPERS ----------

  double _toDisplayWeight(double kg, bool isMetric) =>
      isMetric ? kg : kg * 2.20462;

  String _weightUnit(bool isMetric) => isMetric ? 'kg' : 'lbs';

  Set<int> _firstSetIndexPerDay(List<SetModel> data) {
    final seen = <String>{};
    final indices = <int>{};

    for (int i = 0; i < data.length; i++) {
      final day = DateFormat('yyyy-MM-dd').format(data[i].timestamp);
      if (seen.add(day)) indices.add(i);
    }
    return indices;
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final isMetric = context.watch<UnitProvider>().isMetric;

    return Scaffold(
      appBar: AppBar(title: Text(widget.exerciseName)),
      body: FutureBuilder<List<SetModel>>(
        future: _setsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.reversed.toList();
          if (data.isEmpty) {
            return const Center(child: Text('No data'));
          }

          return Column(
            children: [
              Expanded(
                child: _buildChartBlock(
                  context,
                  data,
                  _topCtrl,
                  (d) => _buildVolumeChart(d, isMetric),
                  legendItems: [LegendItem('Volume', Colors.red)],
                ),
              ),
              Expanded(
                child: _buildChartBlock(
                  context,
                  data,
                  _middleCtrl,
                      (d) => _buildWeightRepsChart(d, isMetric),
                  legendItems: [
                    LegendItem('Weight [${_weightUnit(isMetric)}]', Colors.red),
                    LegendItem('Reps', Colors.green),
                  ],
                ),
              ),
              Expanded(
                child: _buildChartBlock(
                  context,
                  data,
                  _bottomCtrl,
                  _buildWorkRestChart,
                  legendItems: [LegendItem('Work[s]', Colors.red), LegendItem('Rest[s]', Colors.green)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChartBlock(
      BuildContext context,
      List<SetModel> data,
      ScrollController controller,
      Widget Function(List<SetModel>) builder, {
      required List<LegendItem> legendItems,}
      ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final pointWidth = screenWidth / maxVisiblePoints;
    final chartWidth = max(data.length * pointWidth, screenWidth);

    return Column(
      children: [
        _buildLegend(legendItems),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: SizedBox(
              width: chartWidth,
              child: builder(data),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- CHARTS ----------
  Widget _buildVolumeChart(List<SetModel> data, bool isMetric) {
    final reps = data.map((e) => e.reps.toDouble()).toList();
    final weights =
    data.map((e) => _toDisplayWeight(e.weight, isMetric)).toList();

    final volume = List.generate(reps.length, (i) => reps[i] * weights[i]);

    return _lineChart(
      data,
      [_lineWithStats(volume, Colors.grey)]
    );
  }

  Widget _buildWeightRepsChart(List<SetModel> data, bool isMetric) {
    final reps = data.map((e) => e.reps.toDouble()).toList();
    final weights =
    data.map((e) => _toDisplayWeight(e.weight, isMetric)).toList();

    return _lineChart(
      data,
      [
        _lineWithStats(reps, Colors.green),
        _lineWithStats(weights, Colors.red),
      ],
    );
  }

  Widget _buildWorkRestChart(List<SetModel> data) {
    final work = data.map((e) => e.workTime.toDouble()).toList();
    final rest = data.map((e) => e.restTime.toDouble()).toList();

    return _lineChart(
      data,
      [
        _lineWithStats(work, Colors.green),
        _lineWithStats(rest, Colors.red),
      ],
    );
  }

  // ---------- CORE ----------

  Widget _lineChart(List<SetModel> data, List<_Series> series,) {
    final maxY = series.expand((s) => s.values).reduce(max) * 1.25;
    final labelIndices = _firstSetIndexPerDay(data);

    return LineChart(
      LineChartData(
        minX: -1.5,
        maxX: data.length + 0.5,
        minY: 0,
        maxY: maxY,
        clipData: FlClipData.none(),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipMargin: 8,
            tooltipRoundedRadius: 6,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final lineColor =
                    spot.bar.gradient?.colors.first ??
                        spot.bar.color ??
                        Colors.white;

                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  TextStyle(
                    color: lineColor, // SAME COLOR AS THE LINE
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (!labelIndices.contains(i)) {
                  return const SizedBox.shrink();
                }
                return Text(
                  DateFormat('dd/MM').format(data[i].timestamp),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles:
          AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: series.expand((s) => s.statLines).toList(),
        ),
        lineBarsData: series.map((s) => s.line).toList(),
      ),
    );
  }

  // ---------- SERIES ----------

  _Series _lineWithStats(List<double> values, Color base) {
    final maxV = values.reduce(max);
    final minV = values.reduce(min);
    final avg =
        values.reduce((a, b) => a + b) / values.length;

    return _Series(
      values: values,
      line: LineChartBarData(
        spots: List.generate(
          values.length,
              (i) => FlSpot(i.toDouble(), values[i]),
        ),
        color: base,
        barWidth: 2,
        isCurved: false,
        dotData: FlDotData(show: true),
      ),
      statLines: [
        HorizontalLine(
          y: maxV,
          color: base.withOpacity(0.9),
          strokeWidth: 1.5,
        ),
        HorizontalLine(
          y: minV,
          color: base.withOpacity(0.4),
          strokeWidth: 1.5,
        ),
        HorizontalLine(
          y: avg,
          color: base.withOpacity(0.6),
          dashArray: [6, 4],
          strokeWidth: 1,
        ),
      ],
    );
  }
}

// ---------- MODEL ----------

class _Series {
  final List<double> values;
  final LineChartBarData line;
  final List<HorizontalLine> statLines;

  _Series({
    required this.values,
    required this.line,
    required this.statLines,
  });
}

class LegendItem {
  final String label;
  final Color color;
  LegendItem(this.label, this.color);
}

Widget _buildLegend(List<LegendItem> items) {
  return Padding(
    padding: const EdgeInsets.only(left: 12),
    child: Row(
      children: [
        ...items.map((item) => Row(
          children: [
            Container(width: 12, height: 12, color: item.color),
            const SizedBox(width: 6),
            Text(item.label, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 12),
          ],
        )),
      ],
    ),
  );
}