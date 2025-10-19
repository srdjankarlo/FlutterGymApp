import 'dart:io';
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
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // === Muscles Table ===
    await db.execute('''
      CREATE TABLE muscles (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        image TEXT
      );
    ''');

    // === Exercises Table ===
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        muscle_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        image TEXT,
        FOREIGN KEY (muscle_id) REFERENCES muscles (id)
      );
    ''');

    // === Sets Table ===
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
        FOREIGN KEY (exercise_id) REFERENCES exercises (id)
      );
    ''');

    // === Pre-fill muscle groups ===
    final muscles = [
      MuscleModel(id: 1, name: 'Back', description: 'ToDo', image: 'assets/images/back.png'),
      MuscleModel(id: 2, name: 'Chest', description: 'ToDo', image: 'assets/images/chest.png'),
      MuscleModel(id: 3, name: 'Shoulders', description: 'ToDo', image: 'assets/images/shoulders.png'),
      MuscleModel(id: 4, name: 'Biceps', description: 'ToDo', image: 'assets/images/biceps.png'),
      MuscleModel(id: 5, name: 'Triceps', description: 'ToDo', image: 'assets/images/triceps.png'),
      MuscleModel(id: 6, name: 'Abdomen', description: 'ToDo', image: 'assets/images/abdomen.png'),
      MuscleModel(id: 7, name: 'Glutes', description: 'ToDo', image: 'assets/images/glutes.png'),
      MuscleModel(id: 8, name: 'Quadriceps', description: 'ToDo', image: 'assets/images/quadriceps.png'),
      MuscleModel(id: 9, name: 'Hamstrings', description: 'ToDo', image: 'assets/images/hamstrings.png'),
      MuscleModel(id: 10, name: 'Calves', description: 'ToDo', image: 'assets/images/calves.png'),
    ];

    for (final muscle in muscles) {
      await db.insert('muscles', muscle.toMap());
    }

    // === Pre-fill exercises (each uses its muscle image) ===
    final exercises = [
      // Back
      ExerciseModel(muscleId: 1, name: 'Pull-up', image: 'assets/images/back.png'),
      ExerciseModel(muscleId: 1, name: 'Bent-over Row', image: 'assets/images/back.png'),
      ExerciseModel(muscleId: 1, name: 'Lat Pulldown', image: 'assets/images/back.png'),

      // Chest
      ExerciseModel(muscleId: 2, name: 'Bench Press', image: 'assets/images/chest.png'),
      ExerciseModel(muscleId: 2, name: 'Incline Dumbbell Press', image: 'assets/images/chest.png'),
      ExerciseModel(muscleId: 2, name: 'Chest Fly', image: 'assets/images/chest.png'),

      // Shoulders
      ExerciseModel(muscleId: 3, name: 'Overhead Press', image: 'assets/images/shoulders.png'),
      ExerciseModel(muscleId: 3, name: 'Lateral Raise', image: 'assets/images/shoulders.png'),
      ExerciseModel(muscleId: 3, name: 'Front Raise', image: 'assets/images/shoulders.png'),

      // Biceps
      ExerciseModel(muscleId: 4, name: 'Barbell Curl', image: 'assets/images/biceps.png'),
      ExerciseModel(muscleId: 4, name: 'Hammer Curl', image: 'assets/images/biceps.png'),
      ExerciseModel(muscleId: 4, name: 'Concentration Curl', image: 'assets/images/biceps.png'),

      // Triceps
      ExerciseModel(muscleId: 5, name: 'Tricep Pushdown', image: 'assets/images/triceps.png'),
      ExerciseModel(muscleId: 5, name: 'Overhead Tricep Extension', image: 'assets/images/triceps.png'),
      ExerciseModel(muscleId: 5, name: 'Dips', image: 'assets/images/triceps.png'),

      // Abdomen
      ExerciseModel(muscleId: 6, name: 'Crunch', image: 'assets/images/abdomen.png'),
      ExerciseModel(muscleId: 6, name: 'Leg Raise', image: 'assets/images/abdomen.png'),
      ExerciseModel(muscleId: 6, name: 'Plank', image: 'assets/images/abdomen.png'),

      // Glutes
      ExerciseModel(muscleId: 7, name: 'Hip Thrust', image: 'assets/images/glutes.png'),
      ExerciseModel(muscleId: 7, name: 'Glute Kickback', image: 'assets/images/glutes.png'),
      ExerciseModel(muscleId: 7, name: 'Squat', image: 'assets/images/glutes.png'),

      // Quadriceps
      ExerciseModel(muscleId: 8, name: 'Squat', image: 'assets/images/quadriceps.png'),
      ExerciseModel(muscleId: 8, name: 'Leg Extension', image: 'assets/images/quadriceps.png'),
      ExerciseModel(muscleId: 8, name: 'Lunge', image: 'assets/images/quadriceps.png'),

      // Hamstrings
      ExerciseModel(muscleId: 9, name: 'Romanian Deadlift', image: 'assets/images/hamstrings.png'),
      ExerciseModel(muscleId: 9, name: 'Leg Curl', image: 'assets/images/hamstrings.png'),
      ExerciseModel(muscleId: 9, name: 'Good Morning', image: 'assets/images/hamstrings.png'),

      // Calves
      ExerciseModel(muscleId: 10, name: 'Standing Calf Raise', image: 'assets/images/calves.png'),
      ExerciseModel(muscleId: 10, name: 'Seated Calf Raise', image: 'assets/images/calves.png'),
      ExerciseModel(muscleId: 10, name: 'Donkey Calf Raise', image: 'assets/images/calves.png'),
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
      orderBy: 'timestamp DESC', // most recent first
    );
    return result.map((e) => SetModel.fromMap(e)).toList();
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
  Future<List<Map<String, dynamic>>> getMusclesWithExerciseCount() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT m.*, COUNT(e.id) AS exercise_count
      FROM muscles m
      LEFT JOIN exercises e ON m.id = e.muscle_id
      GROUP BY m.id
      ORDER BY m.id;
    ''');
  }

  // ====== EXERCISES ======
  Future<List<ExerciseModel>> getExercisesByMuscle(int muscleId) async {
    final db = await instance.database;
    final maps = await db.query(
      'exercises',
      where: 'muscle_id = ?',
      whereArgs: [muscleId],
    );
    return maps.map((e) => ExerciseModel.fromMap(e)).toList();
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
    return await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ====== CLOSE DATABASE ======
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }
}
