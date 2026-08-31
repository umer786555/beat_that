class UserBlock {
	const UserBlock({
		required this.id,
		required this.blockerId,
		required this.blockedId,
		this.createdAt,
		this.blockedUsername = 'Unknown User',
		this.blockedProfileUrl,
	});

	final String id;
	final String blockerId;
	final String blockedId;
	final DateTime? createdAt;
	final String blockedUsername;
	final String? blockedProfileUrl;

	factory UserBlock.fromJson(Map<String, dynamic> json) {
		return UserBlock(
			id: json['id'] as String,
			blockerId: json['blocker_id'] as String,
			blockedId: json['blocked_id'] as String,
			createdAt: _parseDateTime(json['created_at']),
			blockedUsername:
					json['blocked_username'] as String? ??
					json['username'] as String? ??
					'Unknown User',
			blockedProfileUrl:
					json['blocked_profile_url'] as String? ??
					json['profileUrl'] as String?,
		);
	}

	Map<String, dynamic> toJson() {
		return {
			'id': id,
			'blocker_id': blockerId,
			'blocked_id': blockedId,
			'created_at': createdAt?.toIso8601String(),
			'blocked_username': blockedUsername,
			'blocked_profile_url': blockedProfileUrl,
		};
	}

	UserBlock copyWith({
		String? id,
		String? blockerId,
		String? blockedId,
		DateTime? createdAt,
		String? blockedUsername,
		String? blockedProfileUrl,
	}) {
		return UserBlock(
			id: id ?? this.id,
			blockerId: blockerId ?? this.blockerId,
			blockedId: blockedId ?? this.blockedId,
			createdAt: createdAt ?? this.createdAt,
			blockedUsername: blockedUsername ?? this.blockedUsername,
			blockedProfileUrl: blockedProfileUrl ?? this.blockedProfileUrl,
		);
	}

	static DateTime? _parseDateTime(dynamic value) {
		if (value is String && value.isNotEmpty) {
			return DateTime.tryParse(value);
		}

		return null;
	}
}
