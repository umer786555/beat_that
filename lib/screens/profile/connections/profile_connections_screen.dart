import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/models/user_profile_summary.dart';
import 'package:beat_that/routes/app_router.dart';
import 'package:beat_that/screens/profile/connections/bloc/profile_connections_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ProfileConnectionsScreen extends StatelessWidget {
  const ProfileConnectionsScreen({super.key, required this.connectionType});

  final String connectionType;

  String get _title {
    return connectionType == ProfileConnectionsType.followers
        ? 'Followers'
        : 'Following';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) =>
          ProfileConnectionsBloc(connectionType: connectionType)
            ..add(const LoadProfileConnectionsEvent()),
      child: Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: BlocBuilder<ProfileConnectionsBloc, ProfileConnectionsState>(
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
                            const LoadProfileConnectionsEvent(),
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
              return Center(
                child: Text(
                  connectionType == ProfileConnectionsType.followers
                      ? 'No followers yet'
                      : 'Not following anyone yet',
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.separated(
              itemCount: loadedState.users.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = loadedState.users[index];
                return _ConnectionListTile(user: user, isDark: isDark);
              },
            );
          },
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
