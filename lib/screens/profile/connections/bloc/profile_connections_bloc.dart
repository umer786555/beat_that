import 'package:beat_that/models/user_profile_summary.dart';
import 'package:beat_that/service_locator.dart';
import 'package:beat_that/services/supabase_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'profile_connections_event.dart';
part 'profile_connections_state.dart';

class ProfileConnectionsBloc
    extends Bloc<ProfileConnectionsEvent, ProfileConnectionsState> {
  ProfileConnectionsBloc({required this.connectionType})
    : _supabaseService = locator<SupabaseService>(),
      super(const ProfileConnectionsInitial()) {
    on<LoadProfileConnectionsEvent>(_onLoadProfileConnections);
  }

  final String connectionType;
  final SupabaseService _supabaseService;

  Future<void> _onLoadProfileConnections(
    LoadProfileConnectionsEvent event,
    Emitter<ProfileConnectionsState> emit,
  ) async {
    emit(const ProfileConnectionsLoading());

    try {
      final rawUsers = connectionType == ProfileConnectionsType.followers
          ? await _supabaseService.getFollowers()
          : await _supabaseService.getFollowing();

      final users = rawUsers
          .map((user) => UserProfileSummary.fromMap(user))
          .toList();

      emit(ProfileConnectionsLoaded(users: users));
    } catch (e) {
      emit(
        ProfileConnectionsError(message: 'Failed to load $connectionType: $e'),
      );
    }
  }
}

abstract class ProfileConnectionsType {
  static const String followers = 'followers';
  static const String following = 'following';
}
