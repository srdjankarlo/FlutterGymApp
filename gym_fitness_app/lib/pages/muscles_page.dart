import 'package:flutter/material.dart';
import '../database/app_database.dart';
import 'exercises_page.dart';

class MusclesPage extends StatefulWidget {
  const MusclesPage({super.key});

  @override
  State<MusclesPage> createState() => _MusclesPageState();
}

class _MusclesPageState extends State<MusclesPage> {
  List<Map<String, dynamic>> _muscles = [];

  @override
  void initState() {
    super.initState();
    _loadMuscles();
  }

  Future<void> _loadMuscles() async {
    final data = await AppDatabase.instance.getMusclesWithExerciseCount();
    setState(() => _muscles = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Muscles')),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _muscles.length,
        itemBuilder: (context, index) {
          final muscle = _muscles[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExercisesPage(
                      muscleId: muscle['id'],
                      muscleName: muscle['name'],
                    ),
                  ),
                ).then((_) => _loadMuscles());
              },
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    // Big image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        muscle['image'],
                        width: 170,
                        height: 120,
                        fit: BoxFit.contain, // shows full image
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Text info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            muscle['name'],
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${muscle['exercise_count']} exercises',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
