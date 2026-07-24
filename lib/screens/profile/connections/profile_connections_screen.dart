import 'dart:async';

import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/user_profile_summary.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/profile/connections/bloc/profile_connections_bloc.dart';
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
  Timer? _debounce;

  String get _title {
    return widget.connectionType == ProfileConnectionsType.followers
        ? 'Followers'
        : 'Following';
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final triggerDistance =
        _scrollController.position.maxScrollExtent - _scrollTriggerDistance;
    if (_scrollController.position.pixels >= triggerDistance) {
      context.read<ProfileConnectionsBloc>().add(
        const LoadMoreProfileConnectionsEvent(),
      );
    }
  }

  void _onQueryChanged(String value) {
    if (mounted) {
      setState(() {});
    }

    _debounce?.cancel();

    if (value.trim().isEmpty) {
      context.read<ProfileConnectionsBloc>().add(
        const SearchProfileConnectionsEvent(query: ''),
      );
      return;
    }

    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }

      context.read<ProfileConnectionsBloc>().add(
        SearchProfileConnectionsEvent(query: value),
      );
    });
  }

  void _clearSearch() {
    HapticFeedback.lightImpact();
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    context.read<ProfileConnectionsBloc>().add(
      const SearchProfileConnectionsEvent(query: ''),
    );
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<ProfileConnectionsBloc>();
    final refreshCompletion = bloc.stream.firstWhere(
      (state) =>
          state is ProfileConnectionsLoaded || state is ProfileConnectionsError,
    );

    bloc.add(const LoadProfileConnectionsEvent(forceRefresh: true));
    await refreshCompletion;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) =>
          ProfileConnectionsBloc(connectionType: widget.connectionType)
            ..add(const LoadProfileConnectionsEvent()),
      child: Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText:
                      widget.connectionType == ProfileConnectionsType.followers
                      ? 'Search followers'
                      : 'Search following',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<ProfileConnectionsBloc, ProfileConnectionsState>(
                builder: (context, state) {
                  if (state is ProfileConnectionsLoading ||
                      state is ProfileConnectionsInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is ProfileConnectionsError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 56,
                              color: isDark
                                  ? AppColors.cyan
                                  : AppColors.electricMagenta,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                context.read<ProfileConnectionsBloc>().add(
                                  const LoadProfileConnectionsEvent(
                                    forceRefresh: true,
                                  ),
                                );
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final loadedState = state as ProfileConnectionsLoaded;
                  if (loadedState.users.isEmpty) {
                    final hasSearchQuery = loadedState.searchQuery.isNotEmpty;
                    return Center(
                      child: Text(
                        hasSearchQuery
                            ? widget.connectionType ==
                                      ProfileConnectionsType.followers
                                  ? 'No followers match your search'
                                  : 'No following users match your search'
                            : widget.connectionType ==
                                  ProfileConnectionsType.followers
                            ? 'No followers yet'
                            : 'Not following anyone yet',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final showLoadingFooter = loadedState.isLoadingMore;
                  final showEndFooter =
                      !loadedState.hasMoreContent && !loadedState.isLoadingMore;
                  final hasSearchQuery = loadedState.searchQuery.isNotEmpty;

                  return RefreshIndicator(
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
                          if (showLoadingFooter) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                hasSearchQuery
                                    ? 'You have reached the end of your search results'
                                    : widget.connectionType ==
                                          ProfileConnectionsType.followers
                                    ? 'You have reached the end of your followers list'
                                    : 'You have reached the end of your following list',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final user = loadedState.users[index];
                        return _ConnectionListTile(user: user, isDark: isDark);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionListTile extends StatelessWidget {
  const _ConnectionListTile({required this.user, required this.isDark});

  final UserProfileSummary user;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.pushNamed(
          'creator-profile',
          extra: CreatorProfileExtra(userId: user.id),
        );
      },
      leading: CircleAvatar(
        backgroundColor: isDark
            ? AppColors.cyan.withValues(alpha: 0.14)
            : AppColors.electricMagenta.withValues(alpha: 0.12),
        backgroundImage: user.profileUrl != null && user.profileUrl!.isNotEmpty
            ? NetworkImage(user.profileUrl!)
            : null,
        child: user.profileUrl == null || user.profileUrl!.isEmpty
            ? Icon(
                Icons.person,
                color: isDark ? AppColors.cyan : AppColors.electricMagenta,
              )
            : null,
      ),
      title: Text(
        user.username,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
