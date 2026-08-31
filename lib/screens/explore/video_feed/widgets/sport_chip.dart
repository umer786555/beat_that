import 'package:beat_that/constants/app_colors.dart';
import 'package:flutter/material.dart';

class SportChip extends StatelessWidget {
  const SportChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
    this.unselectedBackgroundColor,
    this.unselectedBorderColor,
    this.selectedLabelColor = Colors.white,
    this.unselectedLabelColor,
    this.checkmarkColor = Colors.white,
    this.borderRadius = 12,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? selectedColor;
  final Color? unselectedBackgroundColor;
  final Color? unselectedBorderColor;
  final Color selectedLabelColor;
  final Color? unselectedLabelColor;
  final Color checkmarkColor;
  final double borderRadius;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultSelectedColor = isDark
        ? AppColors.cyan.withValues(alpha: 0.88)
        : AppColors.electricMagenta.withValues(alpha: 0.88);

    final defaultUnselectedBgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final defaultUnselectedBorderColor = isDark
        ? Colors.white24
        : Colors.black12;

    final defaultUnselectedLabelColor = isDark
        ? Colors.white70
        : Colors.black87;

    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: selectedColor ?? defaultSelectedColor,
      checkmarkColor: checkmarkColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      labelStyle: TextStyle(
        color: selected
            ? selectedLabelColor
            : (unselectedLabelColor ?? defaultUnselectedLabelColor),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: unselectedBackgroundColor ?? defaultUnselectedBgColor,
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : (unselectedBorderColor ?? defaultUnselectedBorderColor),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
