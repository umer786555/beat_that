/// Model representing a sport subcategory from the database
class SportSubcategory {
  final int id;
  final String sportId;
  final String name;

  const SportSubcategory({
    required this.id,
    required this.sportId,
    required this.name,
  });

  /// Create a SportSubcategory from a database map
  factory SportSubcategory.fromJson(Map<String, dynamic> json) {
    return SportSubcategory(
      id: (json['id'] ?? 0) as int,
      sportId: (json['sport_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
    );
  }

  /// Convert SportSubcategory to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sport_id': sportId,
      'name': name,
    };
  }

  /// Create a copy of this subcategory with optional field overrides
  SportSubcategory copyWith({
    int? id,
    String? sportId,
    String? name,
  }) {
    return SportSubcategory(
      id: id ?? this.id,
      sportId: sportId ?? this.sportId,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'SportSubcategory(id: $id, sportId: $sportId, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SportSubcategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sportId == other.sportId &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ sportId.hashCode ^ name.hashCode;
}
