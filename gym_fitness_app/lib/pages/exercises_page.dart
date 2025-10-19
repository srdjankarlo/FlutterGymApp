import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../database/app_database.dart';
import '../models/exercise_model.dart';
import '../models/muscle_model.dart';
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
  List<MuscleModel> _allMuscles = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _loadAllMuscles();
  }

  void _loadExercises() {
    _exercisesFuture =
        AppDatabase.instance.getExercisesByMuscle(widget.muscleId);
  }

  void _loadAllMuscles() async {
    final maps = await AppDatabase.instance.getMusclesWithExerciseCount();
    _allMuscles = maps.map((m) => MuscleModel.fromMap(m)).toList();
    setState(() {}); // trigger rebuild so dropdowns work
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
    final file =
    File(filePath)..writeAsBytesSync(img.encodeJpg(resized, quality: 85));

    return filePath;
  }

  Future<void> _editExercise(ExerciseModel exercise) async {
    final nameController = TextEditingController(text: exercise.name);
    String? selectedImage = exercise.image;

    // Initialize muscle selection
    List<int> selectedPrimary = exercise.primaryMuscleIDs;
    List<int> selectedSecondary = exercise.secondaryMuscleIDs ?? [];

    // Load all muscles
    final muscleMaps = await AppDatabase.instance.getMusclesWithExerciseCount();
    final allMuscles = muscleMaps.map((m) => MuscleModel.fromMap(m)).toList();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Edit Exercise'),
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
                          child: _buildExerciseImage(
                            selectedImage,
                            'assets/images/${widget.muscleName.toLowerCase()}.png',
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
                    children: allMuscles.map((muscle) {
                      final isSelected = selectedPrimary.contains(muscle.id);
                      final isDisabled = selectedSecondary.contains(muscle.id);
                      return FilterChip(
                        label: Text(muscle.name),
                        selected: isSelected,
                        onSelected: isDisabled
                            ? null
                            : (selected) {
                          setStateDialog(() {
                            if (selected) {
                              selectedPrimary.add(muscle.id);
                            } else {
                              selectedPrimary.remove(muscle.id);
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
                    children: allMuscles.map((muscle) {
                      final isSelected = selectedSecondary.contains(muscle.id);
                      final isDisabled = selectedPrimary.contains(muscle.id);
                      return FilterChip(
                        label: Text(muscle.name),
                        selected: isSelected,
                        onSelected: isDisabled
                            ? null
                            : (selected) {
                          setStateDialog(() {
                            if (selected) {
                              selectedSecondary.add(muscle.id);
                            } else {
                              selectedSecondary.remove(muscle.id);
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

                  final updatedExercise = ExerciseModel(
                    id: exercise.id,
                    name: name,
                    primaryMuscleIDs: selectedPrimary,
                    secondaryMuscleIDs: selectedSecondary.isEmpty ? null : selectedSecondary,
                    image: selectedImage,
                  );

                  await AppDatabase.instance.updateExercise(updatedExercise);

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() => _loadExercises());
                  }
                },
                child: const Text('Save'),
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

  Widget _buildExerciseImage(String? exerciseImage, String muscleImage) {
    if (exerciseImage != null &&
        (exerciseImage.startsWith('assets/') ||
            File(exerciseImage).existsSync())) {
      return exerciseImage.startsWith('assets/')
          ? Image.asset(exerciseImage, width: 170, height: 120, fit: BoxFit.contain)
          : Image.file(File(exerciseImage), width: 170, height: 170, fit: BoxFit.contain);
    } else {
      return Image.asset(muscleImage, width: 170, height: 120, fit: BoxFit.contain);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.muscleName} Exercises'),
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
                  final unitProvider =
                  Provider.of<UnitProvider>(context, listen: false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SetsPage(
                        exerciseId: exercise.id!,
                        exerciseName: exercise.name,
                        unitSetting: unitProvider.isMetric ? 'kg' : 'lbs',
                      ),
                    ),
                  );
                },
                child: Card(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildExerciseImage(
                            exercise.image,
                            'assets/images/${widget.muscleName.toLowerCase()}.png',
                          ),
                        ),
                        const SizedBox(width: 20),
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
                              const SizedBox(height: 5),
                              // Primary muscles
                              if (exercise.primaryMuscleIDs.isNotEmpty)
                                Text(
                                  'Primary: ${_allMuscles
                                          .where((m) => exercise.primaryMuscleIDs.contains(m.id))
                                          .map((m) => m.name)
                                          .join(', ')}',
                                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                                ),
                              // Secondary muscles
                              if (exercise.secondaryMuscleIDs != null && exercise.secondaryMuscleIDs!.isNotEmpty)
                                Text(
                                  'Secondary: ${_allMuscles
                                          .where((m) => exercise.secondaryMuscleIDs!.contains(m.id))
                                          .map((m) => m.name)
                                          .join(', ')}',
                                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _editExercise(exercise),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  _deleteExercise(exercise.id!, exercise.name),
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
