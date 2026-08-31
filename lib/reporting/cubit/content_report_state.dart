import 'package:equatable/equatable.dart';

import '../models/report_reason.dart';

class ContentReportState extends Equatable {
  static const Object _sentinel = Object();

  const ContentReportState({
    this.selectedReason,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final ReportReason? selectedReason;
  final bool isSubmitting;
  final String? errorMessage;

  ContentReportState copyWith({
    Object? selectedReason = _sentinel,
    bool? isSubmitting,
    Object? errorMessage = _sentinel,
    bool clearErrorMessage = false,
  }) {
    return ContentReportState(
      selectedReason: identical(selectedReason, _sentinel)
          ? this.selectedReason
          : selectedReason as ReportReason?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [selectedReason, isSubmitting, errorMessage];
}
