class MuscleModel {
  final int id;
  final String name;
  final String? image;

  MuscleModel({
    required this.id,
    required this.name,
    this.image,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image': image,
    };
  }

  factory MuscleModel.fromMap(Map<String, dynamic> map) {
    return MuscleModel(
      id: map['id'] as int,
      name: map['name'],
      image: map['image'],
    );
  }
}
