import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

/// Creates a consistent InputDecoration for form fields across the app
/// Following Flutter Material Design 3 best practices
InputDecoration buildFormFieldDecoration({
  required String hintText,
  required String labelText,
  required IconData prefixIconData,
  Widget? suffixIcon,
}) {
  const borderRadius = BorderRadius.all(Radius.circular(8));
  const gapPadding = 8.0; // Increased gapPadding for better label gap rendering
  const prefixIconSize = 20.0;
  
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AppColors.grey,
      fontSize: 14,
    ),
    labelText: labelText,
    labelStyle: const TextStyle(
      color: AppColors.grey,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 16, right: 12),
      child: Icon(
        prefixIconData,
        color: AppColors.electricMagenta,
        size: prefixIconSize,
      ),
    ),
    prefixIconConstraints: const BoxConstraints(
      minHeight: 32,
      minWidth: 32,
    ),
    suffixIcon: suffixIcon != null
        ? Padding(
            padding: const EdgeInsets.only(right: 12),
            child: suffixIcon,
          )
        : null,
    suffixIconConstraints: const BoxConstraints(
      minHeight: 32,
      minWidth: 32,
    ),
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AppColors.white,
        width: 1.0,
      ),
      gapPadding: gapPadding,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AppColors.white,
        width: 1.0,
      ),
      gapPadding: gapPadding,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(
        color: AppColors.cyan,
        width: 2.0,
      ),
      gapPadding: gapPadding,
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: AppColors.greyDark.withValues(alpha: 0.3),
        width: 1.0,
      ),
      gapPadding: gapPadding,
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(
        color: AppColors.red,
        width: 1.0,
      ),
      gapPadding: gapPadding,
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(
        color: AppColors.red,
        width: 2.0,
      ),
      gapPadding: gapPadding,
    ),
    filled: true,
    fillColor: AppColors.black.withValues(alpha: 0.5),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 18,
    ),
    isDense: true,
  );
}
