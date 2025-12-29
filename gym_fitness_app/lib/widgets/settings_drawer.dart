import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/unit_provider.dart';
import '../theme/color_schemes.dart';
import '../main.dart'; // for ThemeProvider

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final unitProvider = Provider.of<UnitProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          // --- Header ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // --- Language (placeholder) ---
          ListTile(
            title: const Text('Language'),
            onTap: () {},
          ),

          // --- Preferred Unit Selection ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Unit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('kg'),
                      selected: unitProvider.isMetric,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: unitProvider.isMetric
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (_) => unitProvider.setUnit('kg'),
                    ),
                    ChoiceChip(
                      label: const Text('lbs'),
                      selected: unitProvider.isImperial,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: unitProvider.isImperial
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      onSelected: (_) => unitProvider.setUnit('lbs'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- Color Scheme Selection ---
          ListTile(
            title: const Text('Color Scheme'),
            subtitle: Text('Current: ${themeProvider.schemeName}'),
            onTap: () => _showColorSchemeDialog(context, themeProvider),
          ),

          // --- Donate (placeholder) ---
          ListTile(
            title: const Text('Donate'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // --- Popup dialog to select color scheme ---
  void _showColorSchemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Color Scheme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: appColorSchemes.keys.map((schemeName) {
              final isSelected = themeProvider.schemeName == schemeName;
              return ListTile(
                title: Text(schemeName),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  themeProvider.changeScheme(schemeName);
                  Navigator.pop(context); // close dialog
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
