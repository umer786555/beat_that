import 'package:beat_that/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/content_report_cubit.dart';
import '../cubit/content_report_state.dart';
import '../models/report_reason.dart';
import '../models/report_target.dart';

class ContentReportBottomSheet extends StatelessWidget {
  const ContentReportBottomSheet({super.key, required this.target});

  final ReportTarget target;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ContentReportCubit, ContentReportState>(
      builder: (context, state) {
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
                      'Report ${target.type.label}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Why are you reporting this ${target.type.label.toLowerCase()}?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.grey : AppColors.greyDark,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: RadioGroup<ReportReason>(
                  groupValue: state.selectedReason,
                  onChanged: state.isSubmitting
                      ? (_) {}
                      : (value) {
                          if (value != null) {
                            context.read<ContentReportCubit>().selectReason(
                              value,
                            );
                          }
                        },
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: ReportReason.values.length,
                    itemBuilder: (context, index) {
                      final reason = ReportReason.values[index];
                      final isSelected = state.selectedReason == reason;

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
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          subtitle: Text(
                            reason.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.grey
                                  : AppColors.greyDark,
                            ),
                          ),
                          trailing: Radio<ReportReason>(value: reason),
                          onTap: state.isSubmitting
                              ? null
                              : () {
                                  context
                                      .read<ContentReportCubit>()
                                      .selectReason(reason);
                                },
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (state.errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    state.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          foregroundColor: isDark
                              ? AppColors.white
                              : AppColors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: state.isSubmitting
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
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
                        onPressed:
                            state.selectedReason == null || state.isSubmitting
                            ? null
                            : () async {
                                final message = await context
                                    .read<ContentReportCubit>()
                                    .submit();
                                if (!context.mounted || message == null) {
                                  return;
                                }

                                Navigator.of(context).pop(message);
                              },
                        child: state.isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
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
      },
    );
  }
}
