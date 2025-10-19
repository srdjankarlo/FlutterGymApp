class SetModel {
  final int? id;
  final int exerciseId;
  final int setNumber;
  final double weight;
  final int reps;
  final int workTime;
  final int restTime;
  final DateTime timestamp;

  SetModel({
    this.id,
    required this.exerciseId,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.workTime,
    required this.restTime,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
      'work_time': workTime,
      'rest_time': restTime,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SetModel.fromMap(Map<String, dynamic> map) {
    return SetModel(
      id: map['id'],
      exerciseId: map['exercise_id'],
      setNumber: map['set_number'],
      weight: map['weight'],
      reps: map['reps'],
      workTime: map['work_time'] ?? 0,
      restTime: map['rest_time'] ?? 0,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
