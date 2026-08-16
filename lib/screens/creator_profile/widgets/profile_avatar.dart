import 'package:beat_that/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profileUrl,
    required this.isDark,
    this.size = 80,
  });

  final String? profileUrl;
  final bool isDark;
  final double size;

  Color get _accentColor =>
      isDark ? AppColors.cyan : AppColors.electricMagenta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _accentColor,
          width: 2,
        ),
      ),
      child: profileUrl != null && profileUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                profileUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.error_outline,
                    size: size * 0.5,
                    color: _accentColor,
                  );
                },
              ),
            )
          : Icon(
              Icons.person,
              size: size * 0.5,
              color: _accentColor,
            ),
    );
  }
}
