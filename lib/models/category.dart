import 'package:flutter/material.dart';
import 'package:beat_that/models/subcategory.dart';

/// Sport model representing a single sport with display properties and subcategories

class CategoryModel {
  final String id;
  final String name;
  final String displayName;
  final String? pathToImage;
  final List<Subcategorys> subcategories;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.pathToImage,
    required this.subcategories,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      pathToImage: json['path_to_image'] as String?,
      subcategories: (json['subcategories'] as List<dynamic>? ?? [])
          .map(
            (subcategory) =>
                Subcategorys.fromJson(subcategory as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'path_to_image': pathToImage,
      'subcategories': subcategories
          .map((subcategory) => subcategory.toJson())
          .toList(),
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? displayName,
    IconData? icon,
    String? pathToImage,
    List<Subcategorys>? subcategories,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      pathToImage: pathToImage ?? this.pathToImage,
      subcategories: subcategories ?? this.subcategories,
    );
  }

  @override
  String toString() {
    return 'Category('
        'id: $id, '
        'name: $name, '
        'displayName: $displayName, '
        'pathToImage: $pathToImage, '
        'subcategories: $subcategories'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CategoryModel &&
        other.id == id &&
        other.name == name &&
        other.displayName == displayName &&
        other.pathToImage == pathToImage &&
        _listEquals(other.subcategories, subcategories);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      displayName,
      pathToImage,
      Object.hashAll(subcategories),
    );
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}
