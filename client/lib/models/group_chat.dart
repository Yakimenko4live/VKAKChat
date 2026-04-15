class GroupChat {
  final String id;
  final String title;
  final String creatorId;
  final List<GroupParticipant> participants;
  final List<String> adminIds;
  final String? groupPublicKey;
  final DateTime createdAt;
  final int unreadCount;

  GroupChat({
    required this.id,
    required this.title,
    required this.creatorId,
    required this.participants,
    required this.adminIds,
    this.groupPublicKey,
    required this.createdAt,
    this.unreadCount = 0,
  });

  factory GroupChat.fromJson(Map<String, dynamic> json) {
    return GroupChat(
      id: json['id'].toString(),
      title: json['title'],
      creatorId: json['creator_id'].toString(),
      participants: (json['participants'] as List)
          .map((p) => GroupParticipant.fromJson(p))
          .toList(),
      adminIds: (json['admin_ids'] as List).map((id) => id.toString()).toList(),
      groupPublicKey: json['group_public_key'],
      createdAt: DateTime.parse(json['created_at']),
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

class GroupParticipant {
  final String userId;
  final String surname;
  final String name;
  final String? patronymic;
  final bool isAdmin;

  GroupParticipant({
    required this.userId,
    required this.surname,
    required this.name,
    this.patronymic,
    required this.isAdmin,
  });

  String get fullName =>
      patronymic != null ? '$surname $name $patronymic' : '$surname $name';

  factory GroupParticipant.fromJson(Map<String, dynamic> json) {
    return GroupParticipant(
      userId: json['user_id'].toString(),
      surname: json['surname'],
      name: json['name'],
      patronymic: json['patronymic'],
      isAdmin: json['is_admin'] ?? false,
    );
  }
}
