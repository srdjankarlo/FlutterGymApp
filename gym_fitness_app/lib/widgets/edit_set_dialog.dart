import 'package:flutter/material.dart';
import '../models/set_model.dart';
import 'package:provider/provider.dart';
import '../providers/unit_provider.dart';
import '../database/app_database.dart';

class EditSetDialog extends StatefulWidget {
  final SetModel set;
  final String unit;

  const EditSetDialog({super.key, required this.set, required this.unit});

  @override
  State<EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<EditSetDialog> {
  late TextEditingController _setController;
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late TextEditingController _workController;
  late TextEditingController _restController;

  @override
  void initState() {
    super.initState();
    _setController =
        TextEditingController(text: widget.set.setNumber.toString());
    _weightController = TextEditingController(
        text: widget.unit == 'lbs'
            ? (widget.set.weight * 2.20462).toStringAsFixed(1)
            : widget.set.weight.toStringAsFixed(1));
    _repsController = TextEditingController(text: widget.set.reps.toString());
    _workController =
        TextEditingController(text: _formatSeconds(widget.set.workTime));
    _restController =
        TextEditingController(text: _formatSeconds(widget.set.restTime));
  }

  @override
  void dispose() {
    _setController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _workController.dispose();
    _restController.dispose();
    super.dispose();
  }

  String _formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _parseTime(String mmss) {
    final parts = mmss.split(':');
    if (parts.length != 2) return 0;
    final minutes = int.tryParse(parts[0].trim()) ?? 0;
    final seconds = int.tryParse(parts[1].trim()) ?? 0;
    return minutes * 60 + seconds;
  }

  Future<void> _saveSet(UnitProvider unitProvider) async {
    final setNum = int.tryParse(_setController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    final workTime = _parseTime(_workController.text.trim());
    final restTime = _parseTime(_restController.text.trim());

    if (setNum == null ||
        weight == null ||
        reps == null ||
        workTime < 0 ||
        restTime < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly')),
      );
      return;
    }

    double weightToStore =
    unitProvider.isMetric ? weight : weight / 2.20462;

    final updatedSet = SetModel(
      id: widget.set.id,
      exerciseId: widget.set.exerciseId,
      setNumber: setNum,
      weight: weightToStore,
      reps: reps,
      workTime: workTime,
      restTime: restTime,
      timestamp: widget.set.timestamp,
    );

    await AppDatabase.instance.updateSet(updatedSet);
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteSet() async {
    await AppDatabase.instance.deleteSet(widget.set.id!);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final unitProvider = Provider.of<UnitProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: scheme.surface, // 👈 Matches your app surface color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        'Edit Set',
        style: TextStyle(
          color: scheme.onSurface, // makes title visible on dark/light themes
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _setController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Set Number',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Weight (${widget.unit})',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Reps',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            TextField(
              controller: _workController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Work Time (mm:ss)',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            TextField(
              controller: _restController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Rest Time (mm:ss)',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleteSet,
          child: Text(
            'Delete',
            style: TextStyle(color: scheme.error),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          ),
          onPressed: () => _saveSet(unitProvider),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
