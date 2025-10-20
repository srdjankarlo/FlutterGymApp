import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/muscle_model.dart';
import '../models/exercise_model.dart';
import '../models/set_model.dart';

class AppDatabase {
  // ====== SINGLETON PATTERN ======
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gym_fitness.db');
    return _database!;
  }

  // ====== INITIALIZATION ======
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Enable foreign keys for cascading deletes
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // === Muscles Table ===
    await db.execute('''
      CREATE TABLE muscles (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        image TEXT
      );
    ''');

    // === Exercises Table ===
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        primary_muscle_ids TEXT NOT NULL,
        name TEXT NOT NULL,
        image TEXT,
        secondary_muscle_ids TEXT
      );
    ''');

    // === Sets Table with CASCADE DELETE ===
    await db.execute('''
      CREATE TABLE sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        work_time INTEGER,
        rest_time INTEGER,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      );
    ''');

    // === Pre-fill muscle groups ===
    final muscles = [
      MuscleModel(id: 1, name: 'Back', image: 'assets/images/back.png'),
      MuscleModel(id: 2, name: 'Chest', image: 'assets/images/chest.png'),
      MuscleModel(id: 3, name: 'Shoulders', image: 'assets/images/shoulders.png'),
      MuscleModel(id: 4, name: 'Biceps', image: 'assets/images/biceps.png'),
      MuscleModel(id: 5, name: 'Triceps', image: 'assets/images/triceps.png'),
      MuscleModel(id: 6, name: 'Forearms', image: 'assets/images/forearms.png'),
      MuscleModel(id: 7, name: 'Abdomen', image: 'assets/images/abdomen.png'),
      MuscleModel(id: 8, name: 'Glutes', image: 'assets/images/glutes.png'),
      MuscleModel(id: 9, name: 'Quadriceps', image: 'assets/images/quadriceps.png'),
      MuscleModel(id: 10, name: 'Hamstrings', image: 'assets/images/hamstrings.png'),
      MuscleModel(id: 11, name: 'Calves', image: 'assets/images/calves.png'),
    ];

    for (final muscle in muscles) {
      await db.insert('muscles', muscle.toMap());
    }

    // === Pre-fill exercises ===
    final exercises = [
      // Back
      ExerciseModel(primaryMuscleIDs: [1], secondaryMuscleIDs: [4,5,6], name: 'Pull-Up', image: 'assets/images/back.png'),
      ExerciseModel(primaryMuscleIDs: [1,10,9], secondaryMuscleIDs: [4,5,6], name: 'Deadlifts', image: 'assets/images/back.png'),
      ExerciseModel(primaryMuscleIDs: [1], secondaryMuscleIDs: [4,5,6], name: 'Barbell Bent-over Row', image: 'assets/images/back.png'),
      ExerciseModel(primaryMuscleIDs: [1,3], secondaryMuscleIDs: [4,6], name: 'Dumbbell Shrugs', image: 'assets/images/back.png'),
      ExerciseModel(primaryMuscleIDs: [1,10], secondaryMuscleIDs: [], name: 'Back Extensions', image: 'assets/images/back.png'),
      ExerciseModel(primaryMuscleIDs: [1], secondaryMuscleIDs: [4,6], name: 'Scapular Pull-Ups', image: 'assets/images/back.png'),

      // Chest
      ExerciseModel(primaryMuscleIDs: [2,3], secondaryMuscleIDs: [5,6], name: 'Push-Ups', image: 'assets/images/chest.png'),
      ExerciseModel(primaryMuscleIDs: [2,3], secondaryMuscleIDs: [5,6], name: 'Bench Press', image: 'assets/images/chest.png'),
      ExerciseModel(primaryMuscleIDs: [2,3], secondaryMuscleIDs: [5,6], name: 'Incline Press', image: 'assets/images/chest.png'),
      ExerciseModel(primaryMuscleIDs: [2,3], secondaryMuscleIDs: [6], name: 'Peck Deck Fly', image: 'assets/images/chest.png'),

      // Shoulders
      ExerciseModel(primaryMuscleIDs: [3], secondaryMuscleIDs: [4,5,6], name: 'Lateral Raise', image: 'assets/images/shoulders.png'),
      ExerciseModel(primaryMuscleIDs: [3,1], secondaryMuscleIDs: [6], name: 'Bent-Over Lateral Raise', image: 'assets/images/shoulders.png'),
      ExerciseModel(primaryMuscleIDs: [3,2], secondaryMuscleIDs: [5,6], name: 'Standing Front Press', image: 'assets/images/shoulders.png'),
      ExerciseModel(primaryMuscleIDs: [3,2], secondaryMuscleIDs: [6], name: 'Cable Lateral Raise', image: 'assets/images/shoulders.png'),
      ExerciseModel(primaryMuscleIDs: [3,1], secondaryMuscleIDs: [6], name: 'Standing Face Pull', image: 'assets/images/shoulders.png'),

      // Biceps
      ExerciseModel(primaryMuscleIDs: [4], secondaryMuscleIDs: [1,6], name: 'Chin-Ups', image: 'assets/images/biceps.png'),
      ExerciseModel(primaryMuscleIDs: [4,6], secondaryMuscleIDs: [], name: 'Barbell Curl', image: 'assets/images/biceps.png'),
      ExerciseModel(primaryMuscleIDs: [4,6], secondaryMuscleIDs: [], name: 'Dumbbell Curl', image: 'assets/images/biceps.png'),

      // Triceps
      ExerciseModel(primaryMuscleIDs: [5], secondaryMuscleIDs: [2,3,6], name: 'Parallel Bar Dips', image: 'assets/images/triceps.png'),
      ExerciseModel(primaryMuscleIDs: [5], secondaryMuscleIDs: [2,3,6], name: 'Push-Down', image: 'assets/images/triceps.png'),
      ExerciseModel(primaryMuscleIDs: [5], secondaryMuscleIDs: [2,3,6], name: 'Rope Press Down', image: 'assets/images/triceps.png'),

      // Forearms
      ExerciseModel(primaryMuscleIDs: [6, 4], secondaryMuscleIDs: [], name: 'Hammer Curl', image: 'assets/images/forearms.png'),
      ExerciseModel(primaryMuscleIDs: [6, 4], secondaryMuscleIDs: [], name: 'Reverse Barbell Curl', image: 'assets/images/forearms.png'),

      // Abdomen
      ExerciseModel(primaryMuscleIDs: [7], secondaryMuscleIDs: [], name: 'Incline Bench Sit-Ups', image: 'assets/images/abdomen.png'),
      ExerciseModel(primaryMuscleIDs: [7], secondaryMuscleIDs: [], name: 'Sit-Ups', image: 'assets/images/abdomen.png'),
      ExerciseModel(primaryMuscleIDs: [7,9], secondaryMuscleIDs: [], name: 'Leg Raise', image: 'assets/images/abdomen.png'),
      ExerciseModel(primaryMuscleIDs: [7,9], secondaryMuscleIDs: [], name: 'Bar Leg Raise', image: 'assets/images/abdomen.png'),
      ExerciseModel(primaryMuscleIDs: [7], secondaryMuscleIDs: [], name: 'Plank', image: 'assets/images/abdomen.png'),

      // Glutes
      ExerciseModel(primaryMuscleIDs: [8,9], secondaryMuscleIDs: [10], name: 'Squat', image: 'assets/images/glutes.png'),
      ExerciseModel(primaryMuscleIDs: [8,9], secondaryMuscleIDs: [], name: 'Hip Thrust', image: 'assets/images/glutes.png'),
      ExerciseModel(primaryMuscleIDs: [8,10], secondaryMuscleIDs: [], name: 'Glute Kickback', image: 'assets/images/glutes.png'),

      // Quadriceps
      ExerciseModel(primaryMuscleIDs: [9,8], secondaryMuscleIDs: [10], name: 'Leg Extension', image: 'assets/images/quadriceps.png'),
      ExerciseModel(primaryMuscleIDs: [9,8], secondaryMuscleIDs: [10], name: 'Dumbbell Lunges', image: 'assets/images/quadriceps.png'),
      ExerciseModel(primaryMuscleIDs: [9,8], secondaryMuscleIDs: [], name: 'Hack Squat', image: 'assets/images/quadriceps.png'),

      // Hamstrings
      ExerciseModel(primaryMuscleIDs: [10,8], secondaryMuscleIDs: [9], name: 'Romanian Deadlift', image: 'assets/images/hamstrings.png'),
      ExerciseModel(primaryMuscleIDs: [10], secondaryMuscleIDs: [8], name: 'Leg Curl', image: 'assets/images/hamstrings.png'),
      ExerciseModel(primaryMuscleIDs: [10,8], secondaryMuscleIDs: [9], name: 'Good Morning', image: 'assets/images/hamstrings.png'),

      // Calves
      ExerciseModel(primaryMuscleIDs: [11], secondaryMuscleIDs: [9,10], name: 'Standing Calf Raise', image: 'assets/images/calves.png'),
      ExerciseModel(primaryMuscleIDs: [11], secondaryMuscleIDs: [9,10], name: 'Seated Calf Raise', image: 'assets/images/calves.png'),
    ];

    for (final exercise in exercises) {
      await db.insert('exercises', exercise.toMap());
    }
  }

  // ====== SETS CRUD ======
  Future<int> insertSet(SetModel set) async {
    final db = await instance.database;
    return await db.insert('sets', set.toMap());
  }

  Future<List<SetModel>> getSetsByExercise(int exerciseId) async {
    final db = await instance.database;
    final result = await db.query(
      'sets',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'timestamp DESC',
    );
    return result.map((e) => SetModel.fromMap(e)).toList();
  }

  Future<List<SetModel>> getAllSets() async {
    final db = await database;
    final maps = await db.query('sets');
    return maps.map((map) => SetModel.fromMap(map)).toList();
  }

  Future<int> updateSet(SetModel set) async {
    final db = await instance.database;
    return await db.update(
      'sets',
      set.toMap(),
      where: 'id = ?',
      whereArgs: [set.id],
    );
  }

  Future<int> deleteSet(int id) async {
    final db = await instance.database;
    return await db.delete(
      'sets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ====== MUSCLES ======
  List<int> parseMuscleIds(String? csv) {
    if (csv == null || csv.trim().isEmpty) return [];
    return csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMusclesWithExerciseCount() async {
    final db = await instance.database;

    final muscles = await db.query('muscles');
    final exercises = await db.query('exercises');

    final result = muscles.map((m) {
      final muscleId = m['id'] as int;

      int primaryCount = 0;
      int secondaryCount = 0;

      for (final e in exercises) {
        final primary = parseMuscleIds(e['primary_muscle_ids'] as String?);
        final secondary = parseMuscleIds(e['secondary_muscle_ids'] as String?);

        if (primary.contains(muscleId)) primaryCount++;
        if (secondary.contains(muscleId)) secondaryCount++;
      }

      return {
        ...m,
        'primary_count': primaryCount,
        'secondary_count': secondaryCount,
        'exercise_count': primaryCount + secondaryCount,
      };
    }).toList();

    return result;
  }

  // ====== EXERCISES ======
  Future<List<ExerciseModel>> getAllExercises() async {
    final db = await instance.database;
    final result = await db.query('exercises'); // assuming your table is named 'exercises'
    return result.map((map) => ExerciseModel.fromMap(map)).toList();
  }

  Future<int> insertExercise(ExerciseModel exercise) async {
    final db = await instance.database;
    return await db.insert('exercises', exercise.toMap());
  }

  Future<int> updateExercise(ExerciseModel exercise) async {
    final db = await instance.database;
    return await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> deleteExercise(int id) async {
    final db = await instance.database;
    // sets will be deleted automatically due to ON DELETE CASCADE
    return await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ====== CLOSE DATABASE ======
  Future<void> close() async {
    final db = _database;
    if (db != null) await db.close();
  }
}
