import 'package:flutter/material.dart';
import '../models/set_model.dart';
import '../database/app_database.dart';

class EditSetDialog extends StatefulWidget {
  final SetModel set;
  final String unit; // 'kg' or 'lbs'

  const EditSetDialog({super.key, required this.set, required this.unit});

  @override
  State<EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<EditSetDialog> {
  late TextEditingController _setController;
  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _setController = TextEditingController(text: widget.set.setNumber.toString());
    _weightController = TextEditingController(
      text: widget.unit == 'lbs'
          ? (widget.set.weight * 2.20462).toStringAsFixed(1)
          : widget.set.weight.toString(),
    );
    _repsController = TextEditingController(text: widget.set.reps.toString());
  }

  Future<void> _saveSet() async {
    final setNum = int.tryParse(_setController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());

    if (setNum == null || weight == null || reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final weightToStore = widget.unit == 'lbs' ? weight / 2.20462 : weight;

    final updatedSet = SetModel(
      id: widget.set.id,
      exerciseId: widget.set.exerciseId,
      setNumber: setNum,
      weight: weightToStore,
      reps: reps,
      workTime: widget.set.workTime,
      restTime: widget.set.restTime,
      timestamp: widget.set.timestamp,
    );

    await AppDatabase.instance.updateSet(updatedSet);
    Navigator.pop(context, true); // return true to reload sets
  }

  Future<void> _deleteSet() async {
    await AppDatabase.instance.deleteSet(widget.set.id!);
    Navigator.pop(context, true); // return true to reload sets
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Set'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _setController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Set Number'),
            ),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Weight (${widget.unit})'),
            ),
            TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleteSet,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
        ElevatedButton(
          onPressed: _saveSet,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
