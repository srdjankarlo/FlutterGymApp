class ExerciseModel {
  final int? id;
  final List<int> primaryMuscleIDs;   // <-- changed to list
  final String name;
  final String? image;
  final List<int>? secondaryMuscleIDs; // <-- changed to list

  ExerciseModel({
    this.id,
    required this.primaryMuscleIDs,
    required this.name,
    this.image,
    this.secondaryMuscleIDs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'primary_muscle_ids': primaryMuscleIDs.join(','), // store as CSV
      'name': name,
      'image': image,
      'secondary_muscle_ids':
      secondaryMuscleIDs != null ? secondaryMuscleIDs!.join(',') : null,
    };
  }

  factory ExerciseModel.fromMap(Map<String, dynamic> map) {
    final primaryString = map['primary_muscle_ids'] as String?;
    final secondaryString = map['secondary_muscle_ids'] as String?;

    return ExerciseModel(
      id: map['id'] as int?,
      primaryMuscleIDs: primaryString != null && primaryString.isNotEmpty
          ? primaryString.split(',').map((e) => int.parse(e)).toList()
          : [], // default to empty list if null
      name: map['name'] as String,
      image: map['image'] as String?,
      secondaryMuscleIDs: secondaryString != null && secondaryString.isNotEmpty
          ? secondaryString.split(',').map((e) => int.parse(e)).toList()
          : null,
    );
  }
}
