import 'package:flutter/material.dart';
import 'package:gym_fitness_app/pages/muscles_page.dart';
import '../widgets/settings_drawer.dart';

class StartingPage extends StatelessWidget {
  const StartingPage({super.key});

  final List<String> menuItems = const [
    'Muscles',
    'Workout',
    'Training Plans',
    'Exercise Log',
    'Personal Records',
    'Food',
    'Diet Plans',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Fitness App'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          )
        ],
      ),
      endDrawer: const SettingsDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: menuItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ElevatedButton(
                onPressed: () {
                  if (item == 'Muscles') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MusclesPage()),
                    );
                  } else {
                    // Placeholder for other pages
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$item page not implemented yet')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(item, style: const TextStyle(fontSize: 25)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
