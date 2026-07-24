import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/widgets/interactive_button.dart';
import 'package:flutter/material.dart';

typedef SubmitVideoRating = Future<bool> Function(int rating);

class VideoRatingBottomSheet extends StatefulWidget {
  const VideoRatingBottomSheet({
    super.key,
    required this.initialRating,
    required this.isSubmittingRating,
    required this.onSubmitRating,
  });

  final int? initialRating;
  final bool isSubmittingRating;
  final SubmitVideoRating onSubmitRating;

  @override
  State<VideoRatingBottomSheet> createState() => _VideoRatingBottomSheetState();
}

class _VideoRatingBottomSheetState extends State<VideoRatingBottomSheet> {
  int? _selectedRating;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF161616), Color(0xFF0C0C0C)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 30,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Rate this video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.initialRating == null
                      ? 'Pick a score from 1 to 10. 10 means it absolutely delivers.'
                      : 'Update your score any time. 10 means it absolutely delivers.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber.shade300,
                        size: 34,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedRating == null
                            ? 'Choose your score'
                            : '$_selectedRating/10',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedRating == null
                            ? 'No rating selected yet'
                            : _ratingLabel(_selectedRating!),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(10, (index) {
                    final value = index + 1;
                    final isSelected = _selectedRating == value;
                    return InteractiveButton(
                      onTap: () => setState(() => _selectedRating = value),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        width: 58,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [AppColors.orange, AppColors.yellow],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isSelected
                              ? null
                              : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$value',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _selectedRating == null || widget.isSubmittingRating
                        ? null
                        : () async {
                            final selectedRating = _selectedRating;
                            if (selectedRating == null) {
                              return;
                            }

                            await widget.onSubmitRating(selectedRating);
                            if (!context.mounted) {
                              return;
                            }

                            Navigator.of(context).pop();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: widget.isSubmittingRating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : Text(
                            widget.initialRating == null
                                ? 'Submit rating'
                                : 'Update rating',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    if (rating >= 9) {
      return 'Elite pick';
    }
    if (rating >= 7) {
      return 'Strong watch';
    }
    if (rating >= 5) {
      return 'Solid';
    }
    if (rating >= 3) {
      return 'Needs work';
    }
    return 'Not for me';
  }
}
