class UserProfileSummary {
  final String id;
  final String username;
  final String? profileUrl;

  const UserProfileSummary({
    required this.id,
    required this.username,
    this.profileUrl,
  });

  factory UserProfileSummary.fromMap(Map<String, dynamic> map) {
    return UserProfileSummary(
      id: map['id'] as String,
      username: map['username'] as String? ?? 'Unknown User',
      profileUrl: map['profileUrl'] as String?,
    );
  }
}
