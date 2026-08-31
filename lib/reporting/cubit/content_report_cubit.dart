import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/report_reason.dart';
import '../models/report_target.dart';
import 'content_report_state.dart';

class ContentReportCubit extends Cubit<ContentReportState> {
  ContentReportCubit({required this.target})
    : _supabaseService = locator<SupabaseService>(),
      super(const ContentReportState());

  final ReportTarget target;
  final SupabaseService _supabaseService;

  void selectReason(ReportReason reason) {
    if (state.isSubmitting) {
      return;
    }

    emit(state.copyWith(selectedReason: reason, clearErrorMessage: true));
  }

  Future<String?> submit() async {
    if (target.id.trim().isEmpty) {
      emit(state.copyWith(errorMessage: '${target.type.label} not available'));
      return null;
    }

    final reason = state.selectedReason;
    if (reason == null) {
      emit(state.copyWith(errorMessage: 'Select a reason to continue.'));
      return null;
    }

    emit(state.copyWith(isSubmitting: true, clearErrorMessage: true));

    final result = switch (target.type) {
      ReportTargetType.video => await _supabaseService.submitVideoReport(
        videoId: target.id,
        reason: reason.name,
      ),
    };

    if (result['success'] == true) {
      emit(state.copyWith(isSubmitting: false, clearErrorMessage: true));
      return result['message'] as String? ?? 'Thank you for your report.';
    }

    emit(
      state.copyWith(
        isSubmitting: false,
        errorMessage:
            result['error'] as String? ??
            'Failed to submit report. Please try again.',
      ),
    );
    return null;
  }
}
