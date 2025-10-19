import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../database/app_database.dart';
import '../models/exercise_model.dart';
import 'sets_page.dart';
import '../providers/unit_provider.dart';
import 'package:provider/provider.dart';

class ExercisesPage extends StatefulWidget {
  final int muscleId;
  final String muscleName;

  const ExercisesPage({
    super.key,
    required this.muscleId,
    required this.muscleName,
  });

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  late Future<List<ExerciseModel>> _exercisesFuture;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  void _loadExercises() {
    _exercisesFuture = AppDatabase.instance.getExercisesByMuscle(widget.muscleId);
  }

  Future<String?> _pickAndResizeImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final resized = img.copyResize(image, width: 512);

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'exercise_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath)..writeAsBytesSync(img.encodeJpg(resized, quality: 85));

    return filePath;
  }

  Future<void> _addOrEditExercise({ExerciseModel? exercise}) async {
    final nameController = TextEditingController(text: exercise?.name ?? '');
    String? selectedImage = exercise?.image;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text(exercise == null ? 'Add Exercise' : 'Edit Exercise'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Exercise name'),
                ),
                const SizedBox(height: 10),
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
                        child: _buildExerciseImage(selectedImage!, 'assets/images/${widget.muscleName.toLowerCase()}.png'),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final newExercise = ExerciseModel(
                    id: exercise?.id,
                    muscleId: widget.muscleId,
                    name: name,
                    image: selectedImage,
                  );

                  if (exercise == null) {
                    await AppDatabase.instance.insertExercise(newExercise);
                  } else {
                    await AppDatabase.instance.updateExercise(newExercise);
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() => _loadExercises());
                  }
                },
                child: Text(exercise == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteExercise(int id, String exerciseName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete: $exerciseName'),
        content: const Text('Are you sure you want to delete this exercise?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.instance.deleteExercise(id);
      setState(() => _loadExercises());
    }
  }

  /// Helper function to decide which image to show
  Widget _buildExerciseImage(String? exerciseImage, String muscleImage) {
    if (exerciseImage != null && exerciseImage.startsWith('assets/') ||
        (exerciseImage != null && File(exerciseImage).existsSync())) {
      // If exercise has an image, show it
      return exerciseImage.startsWith('assets/')
          ? Image.asset(exerciseImage, width: 170, height: 120, fit: BoxFit.contain)
          : Image.file(File(exerciseImage), width: 170, height: 170, fit: BoxFit.contain);
    } else {
      // Otherwise, show the muscle group image
      return Image.asset(muscleImage, width: 170, height: 120, fit: BoxFit.contain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.muscleName} Exercises'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Exercise',
              onPressed: () => _addOrEditExercise(),
            ),
          ],
      ),
      body: FutureBuilder<List<ExerciseModel>>(
        future: _exercisesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final exercises = snapshot.data ?? [];

          if (exercises.isEmpty) {
            return const Center(child: Text('No exercises yet.'));
          }

          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return InkWell(
                onTap: () {
                  final unitProvider = Provider.of<UnitProvider>(context, listen: false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SetsPage(
                        exerciseId: exercise.id!,
                        exerciseName: exercise.name,
                        unitSetting: unitProvider.isMetric ? 'kg' : 'lbs'
                      ),
                    ),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Exercise image (or muscle image if none)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildExerciseImage(
                            exercise.image, // can be null
                            'assets/images/${widget.muscleName.toLowerCase()}.png',
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Exercise name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.name,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Edit and Delete buttons
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _addOrEditExercise(exercise: exercise),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteExercise(exercise.id!, exercise.name),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
