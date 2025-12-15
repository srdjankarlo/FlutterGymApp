import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../models/set_model.dart';

class PlotsPage extends StatefulWidget {
  final int exerciseId;
  final String exerciseName;
  final String isMetric; // "kg" or "lbs"

  const PlotsPage({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.isMetric,
  });

  @override
  State<PlotsPage> createState() => _PlotsPageState();
}

class _PlotsPageState extends State<PlotsPage> {
  static const int maxVisiblePoints = 20;

  late Future<List<SetModel>> _setsFuture;

  final ScrollController _topCtrl = ScrollController();
  final ScrollController _bottomCtrl = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _setsFuture = AppDatabase.instance.getSetsByExercise(widget.exerciseId);

    _topCtrl.addListener(() => _syncScroll(_topCtrl, _bottomCtrl));
    _bottomCtrl.addListener(() => _syncScroll(_bottomCtrl, _topCtrl));
  }

  void _syncScroll(ScrollController from, ScrollController to) {
    if (_syncing) return;
    _syncing = true;
    if (to.hasClients) {
      to.jumpTo(from.offset);
    }
    _syncing = false;
  }

  // ---------- HELPERS ----------

  double _toDisplayWeight(double kg) =>
      widget.isMetric == "kg" ? kg : kg * 2.20462;

  String _weightUnit() => widget.isMetric;

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
                  _buildWeightRepsChart,
                  legendItems: [LegendItem('Weight', Colors.red), LegendItem('Reps', Colors.green)],
                ),
              ),
              Expanded(
                child: _buildChartBlock(
                  context,
                  data,
                  _bottomCtrl,
                  _buildWorkRestChart,
                  legendItems: [LegendItem('Work', Colors.red), LegendItem('Rest', Colors.green)],
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

  // ---------- Y AXIS ----------
  Widget _buildYAxis(List<SetModel> data, bool isWeight) {
    final values = isWeight
        ? data.map((e) => _toDisplayWeight(e.weight)).toList()
        : [
      ...data.map((e) => e.workTime.toDouble()),
      ...data.map((e) => e.restTime.toDouble()),
    ];

    final maxY = values.reduce(max) * 1.25;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        final v = maxY * (1 - i / 4);
        return Text(
          isWeight
              ? v.toStringAsFixed(0)
              : '${v.toStringAsFixed(0)}s',
          style: const TextStyle(fontSize: 10),
        );
      }),
    );
  }

  // ---------- CHARTS ----------

  Widget _buildWeightRepsChart(List<SetModel> data) {
    final reps = data.map((e) => e.reps.toDouble()).toList();
    final weights =
    data.map((e) => _toDisplayWeight(e.weight)).toList();

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

  Widget _lineChart(
      List<SetModel> data,
      List<_Series> series,
      ) {
    final allValues =
    series.expand((s) => s.values).toList();

    final maxY = allValues.reduce(max) * 1.25;
    final labelIndices = _firstSetIndexPerDay(data);

    return LineChart(
      LineChartData(
        minX: -1.5,
        maxX: data.length + 0.5,
        minY: 0,
        maxY: maxY,
        clipData: FlClipData.none(),
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
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const SizedBox(width: 56),
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