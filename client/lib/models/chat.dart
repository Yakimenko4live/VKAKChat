class ChatResponse {
  final String id;
  final String? title;
  final String chatType;
  final String? otherUserId;
  final String? otherUserName;
  final int unreadCount;

  ChatResponse({
    required this.id,
    this.title,
    required this.chatType,
    this.otherUserId,
    this.otherUserName,
    this.unreadCount = 0,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      id: json['id'].toString(),
      title: json['title'],
      chatType: json['chat_type'],
      otherUserId: json['other_user_id']?.toString(),
      otherUserName: json['other_user_name'],
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

class MessageResponse {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  MessageResponse({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      id: json['id'].toString(),
      chatId: json['chat_id'].toString(),
      senderId: json['sender_id'].toString(),
      content: json['content'],
      isRead: json['is_read'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
