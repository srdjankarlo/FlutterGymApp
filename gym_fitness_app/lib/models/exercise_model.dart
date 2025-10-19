class ExerciseModel {
  final int? id;
  final int muscleId;
  final String name;
  final String? image;

  ExerciseModel({
    this.id,
    required this.muscleId,
    required this.name,
    this.image,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'muscle_id': muscleId,
      'name': name,
      'image': image,
    };
  }

  factory ExerciseModel.fromMap(Map<String, dynamic> map) {
    return ExerciseModel(
      id: map['id'] as int?,
      muscleId: map['muscle_id'] as int,
      name: map['name'] as String,
      image: map['image'] as String?,
    );
  }
}
