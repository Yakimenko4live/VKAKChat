import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/chat.dart';
import '../screens/chat_screen.dart';
import '../services/websocket_service.dart';
import '../services/unread_counter_service.dart';

class ChatListWidget extends StatefulWidget {
  const ChatListWidget({super.key});

  @override
  State<ChatListWidget> createState() => _ChatListWidgetState();
}

class _ChatListWidgetState extends State<ChatListWidget> {
  final ApiService _apiService = ApiService();
  List<ChatResponse> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();

    final wsService = Provider.of<WebSocketService>(context, listen: false);
    wsService.onNewChat = (chatData) {
      _loadChats();
    };
  }

  @override
  void dispose() {
    final wsService = Provider.of<WebSocketService>(context, listen: false);
    wsService.onNewChat = null;
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final allChats = await _apiService.getUserChats();
      final privateChats = allChats
          .where((chat) => chat.chatType == 'private')
          .toList();

      // Обновляем общий счётчик непрочитанных сообщений
      final unreadService = Provider.of<UnreadCounterService>(
        context,
        listen: false,
      );
      int totalUnread = privateChats.fold(
        0,
        (sum, chat) => sum + chat.unreadCount,
      );
      unreadService.updateTotalUnreadCount(totalUnread);

      setState(() {
        _chats = privateChats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Чаты',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : _chats.isEmpty
                ? const Center(
                    child: Text(
                      'Нет чатов. Начните диалог через поиск!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      return _buildChatTile(chat);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatResponse chat) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chat.id,
              otherUserName: chat.otherUserName ?? 'Чат',
              otherUserId: chat.otherUserId ?? '',
              initialUnreadCount: chat.unreadCount,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.otherUserName ?? 'Чат',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Нажмите для открытия чата',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (chat.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
