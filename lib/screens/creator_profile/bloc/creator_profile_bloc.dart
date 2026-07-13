import 'package:beat_that/models/user_personal_profile.dart';
import 'package:beat_that/models/video_thumbnail_model.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'creator_profile_event.dart';
part 'creator_profile_state.dart';

class CreatorProfileBloc
    extends Bloc<CreatorProfileEvent, CreatorProfileState> {
  CreatorProfileBloc({required this.userId})
    : _supabaseService = locator<SupabaseService>(),
      super(const CreatorProfileInitial()) {
    on<LoadCreatorProfileEvent>(_onLoadCreatorProfile);
  }

  final String userId;
  final SupabaseService _supabaseService;

  Future<void> _onLoadCreatorProfile(
    LoadCreatorProfileEvent event,
    Emitter<CreatorProfileState> emit,
  ) async {
    emit(const CreatorProfileLoading());

    try {
      final result = await _supabaseService.fetchUserProfileWithUploadedVideos(
        userId,
      );

      if (result['success'] != true) {
        emit(
          CreatorProfileError(
            message:
                result['error'] as String? ?? 'Failed to load creator profile.',
          ),
        );
        return;
      }

      final profile = result['profile'] as UserPersonalProfile;
      final videos = result['videos'] as List<VideoThumbnailModel>;

      emit(CreatorProfileLoaded(profile: profile, videos: videos));
    } catch (e) {
      emit(CreatorProfileError(message: 'Failed to load creator profile: $e'));
    }
  }
}
