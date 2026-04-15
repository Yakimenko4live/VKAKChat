import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/file_service.dart';
import '../services/chat_keys_service.dart';
import '../services/encryption_service.dart';
import '../services/unread_counter_service.dart';
import '../models/chat.dart';
import '../widgets/file_message_widget.dart';
import '../widgets/image_message_widget.dart';
import 'dart:convert';

enum MessageType { text, image, file }

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;
  final int initialUnreadCount;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
    this.initialUnreadCount = 0,
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

  String? _myPrivateKey;
  String? _otherPublicKey;
  bool _isEncryptionReady = false;

  final Map<String, Uint8List> _fileCache = {};
  bool _hasResetUnread = false;

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadKeys();
    _loadMessages();

    _webSocketService = Provider.of<WebSocketService>(context, listen: false);
    // ✅ Подписываемся через Stream
    _messageSubscription = _webSocketService.messageStream.listen(_onNewMessage);

    _resetUnreadCounter();
  }

  @override
  void dispose() {
    // ✅ Отписываемся
    _messageSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _resetUnreadCounter() async {
    if (_hasResetUnread) return;
    _hasResetUnread = true;

    final unreadService = Provider.of<UnreadCounterService>(
      context,
      listen: false,
    );

    if (widget.initialUnreadCount > 0) {
      unreadService.resetForChat(widget.chatId, widget.initialUnreadCount);

      try {
        await _apiService.markMessagesAsRead(widget.chatId);
        print('✅ Сообщения в чате ${widget.chatId} отмечены как прочитанные');
      } catch (e) {
        print('❌ Ошибка отметки сообщений как прочитанных: $e');
      }
    }
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

    try {
      _otherPublicKey = await _apiService.getPublicKey(widget.otherUserId);
      if (_otherPublicKey != null) {
        final existingSecret = await ChatKeysService.getSharedSecret(
          widget.chatId,
        );
        if (existingSecret != null) {
          _isEncryptionReady = true;
          print('✅ Общий секрет уже существует для чата ${widget.chatId}');
        } else {
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
          if (msg.content.startsWith('{')) {
            decryptedMessages.add(msg);
          } else {
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

  Future<void> _sendTextMessage(String text) async {
    if (text.isEmpty) return;
    if (!_isEncryptionReady || _currentUserId == null) return;

    final sharedSecret = await ChatKeysService.getSharedSecret(widget.chatId);
    if (sharedSecret == null) return;

    final encryptedMessage = EncryptionService.encryptMessage(
      text,
      sharedSecret,
    );
    _webSocketService.sendMessage(
      widget.chatId,
      encryptedMessage,
      _currentUserId!,
    );
    _messageController.clear();
  }

  Future<void> _sendFile(
    Map<String, dynamic> fileData,
    MessageType type,
  ) async {
    if (!_isEncryptionReady || _currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Шифрование не готово')));
      return;
    }

    final sharedSecret = await ChatKeysService.getSharedSecret(widget.chatId);
    if (sharedSecret == null) return;

    setState(() => _isLoading = true);

    try {
      final fileId = await FileService.uploadFile(
        chatId: widget.chatId,
        fileBytes: fileData['bytes'],
        filename: fileData['name'],
        sharedSecret: sharedSecret,
      );

      final messageData = {
        'type': type == MessageType.image ? 'image' : 'file',
        'data': {
          'file_id': fileId,
          'filename': fileData['name'],
          'size': fileData['size'],
          'mime_type': fileData['mimeType'],
        },
      };

      final jsonMessage = json.encode(messageData);
      _webSocketService.sendMessage(
        widget.chatId,
        jsonMessage,
        _currentUserId!,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка отправки файла: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final imageData = await FileService.pickImage();
    if (imageData != null) await _sendFile(imageData, MessageType.image);
  }

  Future<void> _pickFile() async {
    final fileData = await FileService.pickFile();
    if (fileData != null) await _sendFile(fileData, MessageType.file);
  }

  Future<void> _downloadAndShowFile(
    String fileId,
    String filename,
    int size,
  ) async {
    final sharedSecret = await ChatKeysService.getSharedSecret(widget.chatId);
    if (sharedSecret == null) return;

    if (_fileCache.containsKey(fileId)) {
      _openFile(_fileCache[fileId]!, filename);
      return;
    }

    try {
      final fileData = await FileService.downloadFile(
        chatId: widget.chatId,
        fileId: fileId,
        sharedSecret: sharedSecret,
      );
      _fileCache[fileId] = fileData;
      _openFile(fileData, filename);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки файла: $e')));
    }
  }

  void _openFile(Uint8List data, String filename) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(filename),
        content: Text('Файл загружен. Размер: ${data.length} байт'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
      setState(() => _messages.add(message));
      return;
    }

    if (message.content.startsWith('{')) {
      setState(() => _messages.add(message));
      return;
    }

    try {
      final decryptedText = EncryptionService.decryptMessage(
        message.content,
        sharedSecret,
      );
      final decryptedMessage = MessageResponse(
        id: message.id,
        chatId: message.chatId,
        senderId: message.senderId,
        content: decryptedText,
        isRead: message.isRead,
        createdAt: message.createdAt,
      );
      setState(() => _messages.add(decryptedMessage));
    } catch (e) {
      setState(() => _messages.add(message));
    }
  }

  Widget _buildMessageBubble(MessageResponse message, bool isMe) {
    if (message.content.startsWith('{')) {
      try {
        final data = json.decode(message.content);
        final type = data['type'];
        final fileData = data['data'];

        if (type == 'image') {
          return FutureBuilder<Uint8List?>(
            future: _loadImage(fileData['file_id']),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return ImageMessageWidget(
                  imageData: snapshot.data!,
                  isMe: isMe,
                );
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMe ? Colors.green : Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const SizedBox(
                  width: 50,
                  height: 50,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            },
          );
        } else if (type == 'file') {
          return FileMessageWidget(
            filename: fileData['filename'],
            size: fileData['size'],
            isMe: isMe,
            onTap: () => _downloadAndShowFile(
              fileData['file_id'],
              fileData['filename'],
              fileData['size'],
            ),
          );
        }
      } catch (e) {}
    }

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

  Future<Uint8List?> _loadImage(String fileId) async {
    if (_fileCache.containsKey(fileId)) return _fileCache[fileId];

    final sharedSecret = await ChatKeysService.getSharedSecret(widget.chatId);
    if (sharedSecret == null) return null;

    try {
      final imageData = await FileService.downloadFile(
        chatId: widget.chatId,
        fileId: fileId,
        sharedSecret: sharedSecret,
      );
      _fileCache[fileId] = imageData;
      return imageData;
    } catch (e) {
      print('❌ Ошибка загрузки изображения: $e');
      return null;
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.green),
              title: const Text(
                'Изображение',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.green),
              title: const Text('Файл', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
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
                IconButton(
                  onPressed: _showAttachmentMenu,
                  icon: const Icon(Icons.attach_file, color: Colors.green),
                ),
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
                    onSubmitted: (_) =>
                        _sendTextMessage(_messageController.text),
                  ),
                ),
                IconButton(
                  onPressed: () => _sendTextMessage(_messageController.text),
                  icon: const Icon(Icons.send, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}