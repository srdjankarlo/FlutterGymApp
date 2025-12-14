import 'package:flutter/material.dart';

import '../pages/plots_page.dart';

class SetsSettingsDrawer extends StatefulWidget {
  final int exerciseId;
  final dynamic exerciseName;
  final dynamic isMetric;

  const SetsSettingsDrawer({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.isMetric,
  });

  @override
  State<SetsSettingsDrawer> createState() => _SetsSettingsDrawerState();
}

class _SetsSettingsDrawerState extends State<SetsSettingsDrawer> {
  // --- Settings states ---
  bool _soundEnabled = true;
  String _startTimeMode = 'Stopwatch';
  String _restTimeMode = 'Stopwatch';

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          // --- Header ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: const Text(
              'Exercise Settings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),

          const Divider(),

          // --- Start Time Section ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Start Time:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Stopwatch'),
                      selected: _startTimeMode == 'Stopwatch',
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _startTimeMode == 'Stopwatch'
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (_) =>
                          setState(() => _startTimeMode = 'Stopwatch'),
                    ),
                    ChoiceChip(
                      label: const Text('Timer'),
                      selected: _startTimeMode == 'Timer',
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _startTimeMode == 'Timer'
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (_) =>
                          setState(() => _startTimeMode = 'Timer'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- Rest Time Section ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rest Time:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Stopwatch'),
                      selected: _restTimeMode == 'Stopwatch',
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _restTimeMode == 'Stopwatch'
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (_) =>
                          setState(() => _restTimeMode = 'Stopwatch'),
                    ),
                    ChoiceChip(
                      label: const Text('Timer'),
                      selected: _restTimeMode == 'Timer',
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _restTimeMode == 'Timer'
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (_) =>
                          setState(() => _restTimeMode = 'Timer'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- Sound Checkbox ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                Checkbox(
                  value: _soundEnabled,
                  onChanged: (value) =>
                      setState(() => _soundEnabled = value ?? true),
                ),
                const Text('3sec countdown sound'),
              ],
            ),
          ),

          const Divider(),

          // --- Navigation Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Navigation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            title: const Text('Input Set (current)'),
            leading: const Icon(Icons.edit),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            title: const Text('Plots'),
            leading: const Icon(Icons.bar_chart),
            onTap: () {
              // TODO: navigate to plots page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlotsPage(exerciseId: widget.exerciseId, exerciseName: widget.exerciseName, isMetric: widget.isMetric,),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Information'),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              // TODO: navigate to info page
            },
          ),
        ],
      ),
    );
  }
}
