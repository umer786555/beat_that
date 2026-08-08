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
    on<LoadMoreProfileConnectionsEvent>(_onLoadMoreProfileConnections);
    on<SearchProfileConnectionsEvent>(_onSearchProfileConnections);
  }

  static const int _pageSize = 20;

  final String connectionType;
  final SupabaseService _supabaseService;
  final List<UserProfileSummary> _users = <UserProfileSummary>[];
  final Set<String> _seenUserIds = <String>{};
  int _currentOffset = 0;
  bool _hasMoreContent = true;
  bool _isPaginationRequestInFlight = false;
  String _currentSearchQuery = '';
  int _latestSearchRequestId = 0;

  Future<void> _onLoadProfileConnections(
    LoadProfileConnectionsEvent event,
    Emitter<ProfileConnectionsState> emit,
  ) async {
    final existingUsers = List<UserProfileSummary>.from(_users);

    if (event.forceRefresh) {
      _resetPagination();
    }

    if (_users.isEmpty && existingUsers.isEmpty) {
      emit(const ProfileConnectionsLoading());
    } else if (!event.forceRefresh) {
      emit(
        ProfileConnectionsLoaded(
          users: List<UserProfileSummary>.from(_users),
          hasMoreContent: _hasMoreContent,
          isLoadingMore: true,
          searchQuery: _currentSearchQuery,
        ),
      );
    } else if (existingUsers.isNotEmpty) {
      emit(
        ProfileConnectionsLoaded(
          users: existingUsers,
          hasMoreContent: _hasMoreContent,
          isLoadingMore: true,
          searchQuery: _currentSearchQuery,
        ),
      );
    }

    try {
      final rawUsers = await _fetchConnections(
        limit: _pageSize,
        offset: 0,
        query: _currentSearchQuery,
      );

      final users = _mapUniqueUsers(rawUsers);

      _users
        ..clear()
        ..addAll(users);
      _seenUserIds
        ..clear()
        ..addAll(users.map((user) => user.id));
      _currentOffset = rawUsers.length;
      _hasMoreContent = rawUsers.length >= _pageSize && users.isNotEmpty;

      emit(
        ProfileConnectionsLoaded(
          users: List<UserProfileSummary>.from(_users),
          hasMoreContent: _hasMoreContent,
          searchQuery: _currentSearchQuery,
        ),
      );
    } catch (e) {
      emit(
        ProfileConnectionsError(message: 'Failed to load $connectionType: $e'),
      );
    }
  }

  Future<void> _onSearchProfileConnections(
    SearchProfileConnectionsEvent event,
    Emitter<ProfileConnectionsState> emit,
  ) async {
    final normalizedQuery = event.query.trim();
    final existingUsers = List<UserProfileSummary>.from(_users);
    final requestId = ++_latestSearchRequestId;

    _currentSearchQuery = normalizedQuery;
    _resetPagination();

    if (existingUsers.isEmpty) {
      emit(const ProfileConnectionsLoading());
    } else {
      emit(
        ProfileConnectionsLoaded(
          users: existingUsers,
          hasMoreContent: true,
          isLoadingMore: true,
          searchQuery: _currentSearchQuery,
        ),
      );
    }

    try {
      final rawUsers = await _fetchConnections(
        limit: _pageSize,
        offset: 0,
        query: _currentSearchQuery,
      );

      if (requestId != _latestSearchRequestId) {
        return;
      }

      final users = _mapUniqueUsers(rawUsers);

      _users
        ..clear()
        ..addAll(users);
      _seenUserIds
        ..clear()
        ..addAll(users.map((user) => user.id));
      _currentOffset = rawUsers.length;
      _hasMoreContent = rawUsers.length >= _pageSize && users.isNotEmpty;

      emit(
        ProfileConnectionsLoaded(
          users: List<UserProfileSummary>.from(_users),
          hasMoreContent: _hasMoreContent,
          searchQuery: _currentSearchQuery,
        ),
      );
    } catch (e) {
      if (requestId != _latestSearchRequestId) {
        return;
      }

      emit(
        ProfileConnectionsError(message: 'Failed to load $connectionType: $e'),
      );
    }
  }

  Future<void> _onLoadMoreProfileConnections(
    LoadMoreProfileConnectionsEvent event,
    Emitter<ProfileConnectionsState> emit,
  ) async {
    if (_isPaginationRequestInFlight || !_hasMoreContent || _users.isEmpty) {
      return;
    }

    _isPaginationRequestInFlight = true;
    emit(
      ProfileConnectionsLoaded(
        users: List<UserProfileSummary>.from(_users),
        hasMoreContent: _hasMoreContent,
        isLoadingMore: true,
        searchQuery: _currentSearchQuery,
      ),
    );

    try {
      final rawUsers = await _fetchConnections(
        limit: _pageSize,
        offset: _currentOffset,
        query: _currentSearchQuery,
      );

      final users = _mapUniqueUsers(rawUsers);

      _users.addAll(users);
      _seenUserIds.addAll(users.map((user) => user.id));
      _currentOffset += rawUsers.length;
      _hasMoreContent = rawUsers.length >= _pageSize && users.isNotEmpty;

      emit(
        ProfileConnectionsLoaded(
          users: List<UserProfileSummary>.from(_users),
          hasMoreContent: _hasMoreContent,
          searchQuery: _currentSearchQuery,
        ),
      );
    } catch (_) {
      emit(
        ProfileConnectionsLoaded(
          users: List<UserProfileSummary>.from(_users),
          hasMoreContent: _hasMoreContent,
          searchQuery: _currentSearchQuery,
        ),
      );
    } finally {
      _isPaginationRequestInFlight = false;
    }
  }

  Future<List<UserProfileSummary>> _fetchConnections({
    required int limit,
    required int offset,
    required String query,
  }) {
    if (query.isEmpty) {
      return connectionType == ProfileConnectionsType.followers
          ? _supabaseService.getFollowers(limit: limit, offset: offset)
          : _supabaseService.getFollowing(limit: limit, offset: offset);
    }

    return connectionType == ProfileConnectionsType.followers
        ? _supabaseService.searchFollowersUsers(
            query: query,
            limit: limit,
            offset: offset,
          )
        : _supabaseService.searchFollowingUsers(
            query: query,
            limit: limit,
            offset: offset,
          );
  }

  List<UserProfileSummary> _mapUniqueUsers(List<UserProfileSummary> rawUsers) {
    return rawUsers.where((user) => !_seenUserIds.contains(user.id)).toList();
  }

  void _resetPagination() {
    _users.clear();
    _seenUserIds.clear();
    _currentOffset = 0;
    _hasMoreContent = true;
    _isPaginationRequestInFlight = false;
  }
}

abstract class ProfileConnectionsType {
  static const String followers = 'followers';
  static const String following = 'following';
}
