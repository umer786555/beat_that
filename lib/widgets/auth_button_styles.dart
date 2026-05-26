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
    backgroundColor: AppColors.cyan,
    disabledBackgroundColor: AppColors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 4,
  );
}

/// Returns a consistent loading spinner for authentication screens
/// Sized at 20x20 with cyan color for contrast on white buttons
Widget getAuthLoadingSpinner() {
  return const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyan),
    ),
  );
}
