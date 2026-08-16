import 'package:flutter/material.dart';
import 'package:beat_that/constants/app_colors.dart';

// Report reason categories
enum ReportReason {
  harassment('Harassment or Bullying', 'Violence, threats, hateful behavior'),
  hateSpeech('Hate Speech', 'Content promoting discrimination'),
  selfHarm('Self-Harm or Suicide', 'Concerning content about self-injury'),
  misinformation('Misinformation', 'False or misleading information'),
  spam('Spam or Scam', 'Deceptive or repetitive content'),
  sexual('Sexual Content', 'Inappropriate sexual material'),
  violence('Violent Content', 'Gore, weapons, dangerous acts'),
  copyright('Copyright Violation', 'Unauthorized use of intellectual property'),
  underage('Underage Safety', 'Child exploitation or endangerment'),
  eating('Eating Disorders', 'Content promoting eating disorders'),
  other('Other', 'Something else');

  const ReportReason(this.label, this.description);

  final String label;
  final String description;
}

class HomeVideoFeedReportBottomSheet extends StatefulWidget {
  const HomeVideoFeedReportBottomSheet({
    super.key,
    required this.onReportSubmitted,
    required this.onCancel,
  });

  final Function(ReportReason) onReportSubmitted;
  final VoidCallback onCancel;

  @override
  State<HomeVideoFeedReportBottomSheet> createState() =>
      _HomeVideoFeedReportBottomSheetState();
}

class _HomeVideoFeedReportBottomSheetState
    extends State<HomeVideoFeedReportBottomSheet> {
  ReportReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'Report Video',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Why are you reporting this video?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.grey : AppColors.greyDark,
                      ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ReportReason.values.length,
              itemBuilder: (context, index) {
                final reason = ReportReason.values[index];
                final isSelected = _selectedReason == reason;

                return Container(
                  color: isSelected
                      ? (isDark ? Colors.grey[900] : Colors.grey[100])
                      : Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      reason.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    subtitle: Text(
                      reason.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.grey : AppColors.greyDark,
                      ),
                    ),
                    trailing: Radio<ReportReason>(
                      value: reason,
                      groupValue: _selectedReason,
                      onChanged: (ReportReason? value) {
                        if (value != null) {
                          setState(() {
                            _selectedReason = value;
                          });
                        }
                      },
                    ),
                    onTap: () {
                      setState(() {
                        _selectedReason = reason;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      foregroundColor: isDark ? AppColors.white : AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: widget.onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electricMagenta,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _selectedReason != null
                        ? () => widget.onReportSubmitted(_selectedReason!)
                        : null,
                    child: const Text(
                      'Submit Report',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
