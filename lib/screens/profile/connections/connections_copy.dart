import 'package:beat_that/screens/profile/connections/bloc/profile_connections_bloc.dart';

class ConnectionsCopy {
  const ConnectionsCopy({
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    required this.emptySearchMessage,
    required this.endOfListMessageText,
  });

  factory ConnectionsCopy.fromType(String connectionType) {
    final isFollowers = connectionType == ProfileConnectionsType.followers;
    return ConnectionsCopy(
      title: isFollowers ? 'Followers' : 'Following',
      searchHint: isFollowers ? 'Search followers' : 'Search following',
      emptyMessage: isFollowers ? 'No followers yet' : 'Not following anyone yet',
      emptySearchMessage: isFollowers
          ? 'No followers match your search'
          : 'No following users match your search',
      endOfListMessageText: isFollowers
          ? 'You have reached the end of your followers list'
          : 'You have reached the end of your following list',
    );
  }

  final String title;
  final String searchHint;
  final String emptyMessage;
  final String emptySearchMessage;
  final String endOfListMessageText;

  String emptyStateMessage(bool hasSearchQuery) {
    return hasSearchQuery ? emptySearchMessage : emptyMessage;
  }

  String endOfListMessage(bool hasSearchQuery) {
    return hasSearchQuery
        ? 'You have reached the end of your search results'
        : endOfListMessageText;
  }
}
