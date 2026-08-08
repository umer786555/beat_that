import 'dart:async';

import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/profile/connections/bloc/profile_connections_bloc.dart';
import 'package:beat_that/screens/profile/connections/connection_list_tile.dart';
import 'package:beat_that/screens/profile/connections/connections_list_footer.dart';
import 'package:beat_that/screens/profile/connections/connections_search_field.dart';
import 'package:beat_that/screens/profile/connections/empty_connections_widget.dart';
import 'package:beat_that/widgets/error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProfileConnectionsScreen extends StatefulWidget {
  const ProfileConnectionsScreen({super.key, required this.connectionType});

  final String connectionType;

  @override
  State<ProfileConnectionsScreen> createState() =>
      _ProfileConnectionsScreenState();
}

class _ProfileConnectionsScreenState extends State<ProfileConnectionsScreen> {
  static const Duration _searchDebounce = Duration(milliseconds: 350);
  static const double _scrollTriggerDistance = 200;
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  late final ProfileConnectionsBloc _bloc;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _bloc = ProfileConnectionsBloc(connectionType: widget.connectionType)
      ..add(const LoadProfileConnectionsEvent());
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _bloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final triggerDistance =
        _scrollController.position.maxScrollExtent - _scrollTriggerDistance;
    if (_scrollController.position.pixels >= triggerDistance) {
      _bloc.add(const LoadMoreProfileConnectionsEvent());
    }
  }

  void _onQueryChanged(String value) {
    if (mounted) {
      setState(() {});
    }

    _debounce?.cancel();

    if (value.trim().isEmpty) {
      _bloc.add(const SearchProfileConnectionsEvent(query: ''));
      return;
    }

    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }

      _bloc.add(SearchProfileConnectionsEvent(query: value));
    });
  }

  void _clearSearch() {
    HapticFeedback.lightImpact();
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    _bloc.add(const SearchProfileConnectionsEvent(query: ''));
  }

  Future<void> _onRefresh() async {
    final refreshCompletion = _bloc.stream.firstWhere(
      (state) =>
          state is ProfileConnectionsLoaded || state is ProfileConnectionsError,
    );

    _bloc.add(const LoadProfileConnectionsEvent(forceRefresh: true));
    await refreshCompletion;
  }

  @override
  Widget build(BuildContext context) {
    final isFollowers =
        widget.connectionType == ProfileConnectionsType.followers;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isFollowers ? 'Followers' : 'Following';
    final searchHint = isFollowers ? 'Search followers' : 'Search following';
    final emptyTitle = isFollowers
        ? 'No followers yet'
        : 'Not following anyone';
    final emptyDescription = isFollowers
        ? 'When people follow you, they will appear here.'
        : 'When you follow people, they will appear here.';
    final emptyIcon = isFollowers
        ? Icons.group_outlined
        : Icons.person_add_alt_1_outlined;
    final emptyAccent = isFollowers
        ? (isDark ? AppColors.cyan : AppColors.blue)
        : (isDark ? AppColors.greenLight : AppColors.green);
    final noResultsAccent = isDark ? AppColors.orangeLight : AppColors.orange;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: BlocBuilder<ProfileConnectionsBloc, ProfileConnectionsState>(
          builder: (context, state) {
            if (state is ProfileConnectionsLoading ||
                state is ProfileConnectionsInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProfileConnectionsError) {
              return ErrorScreen(
                message: state.message,
                primaryButtonText: 'Retry',
                primaryButtonCallback: () {
                  _bloc.add(
                    const LoadProfileConnectionsEvent(forceRefresh: true),
                  );
                },
              );
            }

            final loadedState = state as ProfileConnectionsLoaded;
            final hasSearchQuery = loadedState.searchQuery.isNotEmpty;
            final isInitialEmptyState =
                loadedState.users.isEmpty && !hasSearchQuery;

            if (isInitialEmptyState) {
              return EmptyConnectionsWidget(
                title: emptyTitle,
                description: emptyDescription,
                icon: emptyIcon,
                accentColor: emptyAccent,
              );
            }

            if (loadedState.users.isEmpty) {
              return Column(
                children: [
                  ConnectionsSearchField(
                    controller: _searchController,
                    hintText: searchHint,
                    onChanged: _onQueryChanged,
                    onClear: _clearSearch,
                  ),
                  Expanded(
                    child: EmptyConnectionsWidget(
                      title: 'No matches found',
                      description: isFollowers
                          ? 'No followers match your search. Try a different name or username.'
                          : 'No following users match your search. Try a different name or username.',
                      icon: Icons.search_off_rounded,
                      accentColor: noResultsAccent,
                    ),
                  ),
                ],
              );
            }

            final showLoadingFooter = loadedState.isLoadingMore;
            final showEndFooter =
                !loadedState.hasMoreContent && !loadedState.isLoadingMore;

            return Column(
              children: [
                ConnectionsSearchField(
                  controller: _searchController,
                  hintText: searchHint,
                  onChanged: _onQueryChanged,
                  onClear: _clearSearch,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount:
                          loadedState.users.length +
                          (showLoadingFooter || showEndFooter ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index >= loadedState.users.length) {
                          return ConnectionsListFooter(
                            isLoading: showLoadingFooter,
                            message: hasSearchQuery
                                ? 'You have reached the end of your search results'
                                : isFollowers
                                ? 'You have reached the end of your followers list'
                                : 'You have reached the end of your following list',
                          );
                        }

                        final user = loadedState.users[index];
                        return ConnectionListTile(
                          user: user,
                          onTap: () {
                            context.pushNamed(
                              'creator-profile',
                              extra: CreatorProfileExtra(userId: user.id),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
