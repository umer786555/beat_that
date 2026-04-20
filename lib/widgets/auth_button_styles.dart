import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// Returns the common TextFormField text style for authentication screens
TextStyle getAuthTextFormFieldStyle() {
  return const TextStyle(
    color: AppColors.white,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );
}

/// Returns the common ElevatedButton styling for authentication screens
ButtonStyle getAuthElevatedButtonStyle() {
  return ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12),
    backgroundColor: AppColors.blue,
    disabledBackgroundColor: AppColors.greyMedium,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 4,
  );
}
