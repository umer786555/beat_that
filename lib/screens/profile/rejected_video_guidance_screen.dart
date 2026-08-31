import 'package:beat_that/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RejectedVideoGuidanceScreen extends StatelessWidget {
  const RejectedVideoGuidanceScreen({super.key, required this.videoTitle});

  final String videoTitle;

  static const List<String> _possibleIssues = [
    'The clip may not clearly show a real sports action, skill, or drill.',
    'The selected sport or subcategory may not match the actual content.',
    'The title, thumbnail, or video framing may be misleading, incomplete, or low quality.',
    'The upload may contain duplicate, heavily edited, or hard-to-review footage.',
    'The clip may include unsafe, explicit, abusive, or otherwise restricted content.',
  ];

  static const List<String> _guidelines = [
    'Upload a clear sports-focused video with stable framing and visible action.',
    'Use an accurate title, sport, and subcategory so moderation can review it quickly.',
    'Avoid copyrighted media, offensive language, and unsafe or harmful behavior.',
    'Make sure the thumbnail reflects the actual clip and is easy to understand at a glance.',
    'Trim or re-record the video if the main action is delayed, obscured, or too short.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.34)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.borderVeryLightGray;
    final mutedTextColor = isDark
        ? colorScheme.onSurfaceVariant
        : AppColors.greyDark;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Video Review',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  AppColors.redDark.withValues(alpha: 0.78),
                                  AppColors.black,
                                ]
                              : [
                                  const Color(0xFFFFF1F1),
                                  const Color(0xFFFFFBF7),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: AppColors.red.withValues(
                            alpha: isDark ? 0.24 : 0.18,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.gpp_bad_outlined,
                                  size: 18,
                                  color: AppColors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Rejected by review',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.redDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            videoTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'We do not currently show the exact moderation reason in-app. Review the common issues below before uploading an updated version.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: mutedTextColor,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _GuidanceSection(
                      title: 'Possible Issues',
                      icon: Icons.help_outline,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      items: _possibleIssues,
                    ),
                    const SizedBox(height: 16),
                    _GuidanceSection(
                      title: 'Upload Guidelines',
                      icon: Icons.rule_folder_outlined,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      items: _guidelines,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next steps',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Update the video, thumbnail, or metadata and upload a revised version once it matches the guidance above.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: mutedTextColor,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to profile'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.cyan
                        : AppColors.electricMagenta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceSection extends StatelessWidget {
  const _GuidanceSection({
    required this.title,
    required this.icon,
    required this.surfaceColor,
    required this.borderColor,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedTextColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.greyDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedTextColor,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
