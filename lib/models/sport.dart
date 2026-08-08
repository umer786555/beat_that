import 'package:flutter/material.dart';
import 'package:beat_that/models/sport_subcategory.dart';

/// Sport model representing a single sport with display properties and subcategories
class Sport {
  final String id;
  final String name;
  final String displayName;
  final IconData icon;
  final String? imageAssetPath;
  final List<SportSubcategory> subcategories;

  const Sport({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    this.imageAssetPath,
    required this.subcategories,
  });
}
