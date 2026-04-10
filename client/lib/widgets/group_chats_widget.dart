import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/group_chat.dart';
import '../screens/group_chat_screen.dart';

class GroupChatsWidget extends StatefulWidget {
  const GroupChatsWidget({super.key});

  @override
  State<GroupChatsWidget> createState() => _GroupChatsWidgetState();
}

class _GroupChatsWidgetState extends State<GroupChatsWidget> {
  final ApiService _apiService = ApiService();
  List<GroupChat> _groupChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupChats();
  }

  Future<void> _loadGroupChats() async {
    try {
      final chats = await _apiService.getUserGroupChats();
      setState(() {
        _groupChats = chats;
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
          Row(
            children: [
              const Text(
                'Групповые чаты',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.green),
                onPressed: () => _showCreateGroupDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : _groupChats.isEmpty
                ? const Center(
                    child: Text(
                      'Нет групповых чатов. Создайте новый!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _groupChats.length,
                    itemBuilder: (context, index) {
                      final chat = _groupChats[index];
                      return _buildGroupChatTile(chat);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateGroupDialog() async {
    final titleController = TextEditingController();
    final List<String> selectedUserIds = [];

    // Получаем список пользователей для добавления
    final users = await _apiService.searchUsers('');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Создать групповой чат',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Название чата',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Участники:', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isSelected = selectedUserIds.contains(user.id);
                      return CheckboxListTile(
                        title: Text(
                          user.surname,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: isSelected,
                        onChanged: (selected) {
                          setDialogState(() {
                            if (selected == true) {
                              selectedUserIds.add(user.id);
                            } else {
                              selectedUserIds.remove(user.id);
                            }
                          });
                        },
                        checkColor: Colors.green,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  await _apiService.createGroupChat(
                    titleController.text,
                    selectedUserIds,
                  );
                  Navigator.pop(context);
                  _loadGroupChats();
                }
              },
              child: const Text(
                'Создать',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupChatTile(GroupChat chat) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                GroupChatScreen(groupId: chat.id, groupTitle: chat.title),
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
                color: Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Center(
                child: Icon(Icons.group, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${chat.participants.length} участников',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
