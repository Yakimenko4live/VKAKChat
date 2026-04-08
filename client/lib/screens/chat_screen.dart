import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/chat.dart';
import '../services/chat_keys_service.dart';
import '../services/encryption_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  List<MessageResponse> _messages = [];
  bool _isLoading = true;
  String? _currentUserId;
  late WebSocketService _webSocketService;

  // Поля для шифрования
  String? _myPrivateKey;
  String? _otherPublicKey;
  bool _isEncryptionReady = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadKeys();
    _loadMessages();

    _webSocketService = Provider.of<WebSocketService>(context, listen: false);
    _webSocketService.onNewMessage = _onNewMessage;
  }

  @override
  void dispose() {
    // Очищаем подписку, чтобы не было утечек памяти при закрытии чата
    _webSocketService.onNewMessage = null;
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
    });
  }

  Future<void> _loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    _myPrivateKey = prefs.getString('private_key');

    if (_myPrivateKey == null) {
      print('❌ Приватный ключ не найден');
      return;
    }

    // Получаем публичный ключ собеседника
    try {
      _otherPublicKey = await _apiService.getPublicKey(widget.otherUserId);
      if (_otherPublicKey != null) {
        // Проверяем, есть ли уже общий секрет для этого чата
        final existingSecret = await ChatKeysService.getSharedSecret(
          widget.chatId,
        );
        if (existingSecret != null) {
          _isEncryptionReady = true;
          print('✅ Общий секрет уже существует для чата ${widget.chatId}');
        } else {
          // Генерируем общий секрет
          await ChatKeysService.generateAndSaveSharedSecret(
            widget.chatId,
            widget.otherUserId,
            _myPrivateKey!,
            _otherPublicKey!,
          );
          _isEncryptionReady = true;
          print('✅ Общий секрет сгенерирован для чата ${widget.chatId}');
        }
      }
    } catch (e) {
      print('❌ Ошибка получения публичного ключа: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _apiService.getChatMessages(widget.chatId);
      final sharedSecret = await ChatKeysService.getSharedSecret(widget.chatId);

      if (sharedSecret != null) {
        final decryptedMessages = <MessageResponse>[];
        for (final msg in messages) {
          try {
            final decryptedText = EncryptionService.decryptMessage(
              msg.content,
              sharedSecret,
            );
            decryptedMessages.add(
              MessageResponse(
                id: msg.id,
                chatId: msg.chatId,
                senderId: msg.senderId,
                content: decryptedText,
                isRead: msg.isRead,
                createdAt: msg.createdAt,
              ),
            );
          } catch (e) {
            decryptedMessages.add(msg);
          }
        }
        setState(() {
          _messages = decryptedMessages;
          _isLoading = false;
        });
      } else {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки сообщений: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    if (!_isEncryptionReady) {
      print('❌ Шифрование не готово');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Шифрование не готово. Пожалуйста, подождите.'),
        ),
      );
      return;
    }

    if (_currentUserId == null) {
      print('❌ Cannot send: userId is null');
      return;
    }

    final sharedSecret = await ChatKeysService.getSharedSecret(widget.chatId);
    if (sharedSecret == null) {
      print('❌ Нет общего секрета');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка шифрования. Попробуйте позже.')),
      );
      return;
    }

    // Шифруем сообщение
    final encryptedMessage = EncryptionService.encryptMessage(
      text,
      sharedSecret,
    );
    print('📤 Отправка зашифрованного сообщения: $encryptedMessage');

    _webSocketService.sendMessage(
      widget.chatId,
      encryptedMessage,
      _currentUserId!,
    );
  }

  void _onNewMessage(MessageResponse message) {
    print('📨 Получено сообщение: ${message.content}');

    if (message.chatId == widget.chatId && mounted) {
      _decryptAndAddMessage(message);
    }
  }

  Future<void> _decryptAndAddMessage(MessageResponse message) async {
    final sharedSecret = await ChatKeysService.getSharedSecret(widget.chatId);
    if (sharedSecret == null) {
      print('❌ Нет общего секрета для расшифровки');
      setState(() {
        _messages.add(message);
      });
      return;
    }

    try {
      final decryptedText = EncryptionService.decryptMessage(
        message.content,
        sharedSecret,
      );
      print('📨 Расшифровано: $decryptedText');

      final decryptedMessage = MessageResponse(
        id: message.id,
        chatId: message.chatId,
        senderId: message.senderId,
        content: decryptedText,
        isRead: message.isRead,
        createdAt: message.createdAt,
      );

      setState(() {
        _messages.add(decryptedMessage);
      });
    } catch (e) {
      print('❌ Ошибка расшифровки: $e');
      setState(() {
        _messages.add(message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.otherUserName,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Нет сообщений. Напишите что-нибудь...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      // Оптимизировано: берем элемент с конца массива без создания нового списка
                      final message = _messages[_messages.length - 1 - index];
                      final isMe = message.senderId == _currentUserId;
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800]?.withOpacity(0.8),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageResponse message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.green : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
