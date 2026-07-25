import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized theme configuration for the Beat That application
// /// Defines light and dark themes with consistent styling across the app
// class AppThemes {
//   // Light Theme
//   static ThemeData lightTheme = ThemeData(
//     useMaterial3: true,
//     brightness: Brightness.light,
//     colorScheme: ColorScheme.fromSeed(
//       seedColor: AppColors.electricMagenta,
//       brightness: Brightness.light,
//     ),
//     scaffoldBackgroundColor: AppColors.white,
//     appBarTheme: AppBarTheme(
//       backgroundColor: AppColors.white,
//       foregroundColor: AppColors.black,
//       elevation: 2,
//       centerTitle: true,
//     ),
//     cardTheme: CardThemeData(
//       color: AppColors.greyLight,
//       elevation: 3,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//     ),
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: AppColors.electricMagenta,
//         foregroundColor: AppColors.white,
//         padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//       ),
//     ),
//     textTheme: TextTheme(
//       displayLarge: TextStyle(
//         color: AppColors.black,
//         fontWeight: FontWeight.bold,
//       ),
//       displayMedium: TextStyle(
//         color: AppColors.black,
//         fontWeight: FontWeight.bold,
//       ),
//       bodyLarge: TextStyle(
//         color: AppColors.black,
//       ),
//       bodyMedium: TextStyle(
//         color: AppColors.black,
//       ),
//     ),
//     inputDecorationTheme: InputDecorationTheme(
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: AppColors.borderVeryLightGray),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: AppColors.electricMagenta, width: 2),
//       ),
//     ),
//   );

//   // Dark Theme
//   static ThemeData darkTheme = ThemeData(
//     useMaterial3: true,
//     brightness: Brightness.dark,
//     colorScheme: ColorScheme.fromSeed(
//       seedColor: AppColors.electricPurple,
//       brightness: Brightness.dark,
//     ),
//     scaffoldBackgroundColor: AppColors.black,
//     appBarTheme: AppBarTheme(
//       backgroundColor: AppColors.black,
//       foregroundColor: AppColors.white,
//       elevation: 1,
//       centerTitle: true,
//     ),
//     cardTheme: CardThemeData(
//       color: AppColors.black,
//       elevation: 1,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(8),
//         side: BorderSide(color: AppColors.electricPurple.withValues(alpha: 0.3), width: 1),
//       ),
//     ),
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: AppColors.electricMagenta,
//         foregroundColor: AppColors.white,
//         padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//       ),
//     ),
//     textTheme: TextTheme(
//       displayLarge: TextStyle(
//         color: AppColors.white,
//         fontWeight: FontWeight.bold,
//       ),
//       displayMedium: TextStyle(
//         color: AppColors.white,
//         fontWeight: FontWeight.bold,
//       ),
//       bodyLarge: TextStyle(
//         color: AppColors.white,
//       ),
//       bodyMedium: TextStyle(
//         color: AppColors.white,
//       ),
//     ),
//     inputDecorationTheme: InputDecorationTheme(
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: AppColors.electricPurple.withValues(alpha: 0.5)),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide(color: AppColors.cyan, width: 2),
//       ),
//     ),
//   );
// }

/// Centralized theme configuration for the Beat That application
class AppThemes {
  /// Light Theme
  static ThemeData lightTheme({Color? textFieldFillColor}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.electricMagenta,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 1,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.greyLight,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricMagenta,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: AppColors.black),
        bodyMedium: TextStyle(color: AppColors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,

        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),

        hintStyle: const TextStyle(color: AppColors.grey, fontSize: 14),

        labelStyle: const TextStyle(
          color: AppColors.black,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),

        floatingLabelBehavior: FloatingLabelBehavior.auto,

        prefixIconColor: AppColors.electricMagenta,

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderVeryLightGray),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.electricMagenta,
            width: 2,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
      ),
    );
  }

  /// Dark Theme
  static ThemeData darkTheme({Color? textFieldFillColor}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.cyan,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 1,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.black,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: AppColors.white,
            width: 0.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricMagenta,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: AppColors.white),
        bodyMedium: TextStyle(color: AppColors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.black,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),

        hintStyle: TextStyle(color: AppColors.white, fontSize: 14),

        labelStyle: TextStyle(
          color: AppColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),

        floatingLabelBehavior: FloatingLabelBehavior.auto,

        prefixIconColor: AppColors.cyan,

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.cyan.withValues(alpha: 0.5)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.cyan, width: 2),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
      ),
    );
  }
}
