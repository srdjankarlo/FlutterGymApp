import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/exercise_model.dart';
import 'exercises_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

class MusclesPage extends StatefulWidget {
  const MusclesPage({super.key});

  @override
  State<MusclesPage> createState() => _MusclesPageState();
}

class _MusclesPageState extends State<MusclesPage> {
  List<Map<String, dynamic>> _muscles = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMuscles();
  }

  Future<void> _loadMuscles() async {
    final data = await AppDatabase.instance.getMusclesWithExerciseCount();
    setState(() => _muscles = data);
  }

  Future<String?> _pickAndResizeImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'exercise_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = '${dir.path}/$fileName';

    return filePath;
  }

  Future<void> _addExercise() async {
    final nameController = TextEditingController();
    String? selectedImage;

    // Initialize muscle selection (optional: preselect tapped muscle if you want)
    List<int> selectedPrimary = [];
    List<int> selectedSecondary = [];

    // Load all muscles from database
    final musclesData = await AppDatabase.instance.getMusclesWithExerciseCount();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Add Exercise'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name field
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Exercise name'),
                  ),
                  const SizedBox(height: 10),
                  // Image picker
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final imagePath = await _pickAndResizeImage();
                          if (imagePath != null) {
                            setStateDialog(() => selectedImage = imagePath);
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('Select Image'),
                      ),
                      const SizedBox(width: 10),
                      if (selectedImage != null)
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: Image.file(
                            File(selectedImage!),
                            width: 60,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Primary muscle selector
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text('Primary Muscles:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Wrap(
                    spacing: 8,
                    children: musclesData.map<Widget>((muscle) {
                      final id = muscle['id'] as int;
                      final name = muscle['name'] as String;
                      return FilterChip(
                        label: Text(name),
                        selected: selectedPrimary.contains(id),
                        onSelected: (selected) {
                          setStateDialog(() {
                            if (selected) {
                              selectedPrimary.add(id);
                              selectedSecondary.remove(id); // prevent duplicates
                            } else {
                              selectedPrimary.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // Secondary muscle selector
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text('Secondary Muscles:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Wrap(
                    spacing: 8,
                    children: musclesData.map<Widget>((muscle) {
                      final id = muscle['id'] as int;
                      final name = muscle['name'] as String;
                      return FilterChip(
                        label: Text(name),
                        selected: selectedSecondary.contains(id),
                        onSelected: (selected) {
                          setStateDialog(() {
                            if (selected) {
                              selectedSecondary.add(id);
                              selectedPrimary.remove(id); // prevent duplicates
                            } else {
                              selectedSecondary.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty || selectedPrimary.isEmpty) return;

                  final newExercise = ExerciseModel(
                    primaryMuscleIDs: selectedPrimary,
                    secondaryMuscleIDs: selectedSecondary.isEmpty ? null : selectedSecondary,
                    name: name,
                    image: selectedImage,
                  );

                  await AppDatabase.instance.insertExercise(newExercise);

                  if (mounted) {
                    Navigator.pop(context);
                    _loadMuscles();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Muscles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Exercise',
            onPressed: () => _addExercise(),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: _muscles.length,
        itemBuilder: (context, index) {
          final muscle = _muscles[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        muscle['image'],
                        width: 170,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            muscle['name'],
                            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Primary: ${muscle['primary_count']}\nSecondary: ${muscle['secondary_count']}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
