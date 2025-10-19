class MuscleModel {
  final int id;
  final String name;
  final String? description;
  final String? image;

  MuscleModel({
    required this.id,
    required this.name,
    this.description,
    this.image,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
    };
  }

  factory MuscleModel.fromMap(Map<String, dynamic> map) {
    return MuscleModel(
      id: map['id'] as int,
      name: map['name'],
      description: map['description'],
      image: map['image'],
    );
  }
}
