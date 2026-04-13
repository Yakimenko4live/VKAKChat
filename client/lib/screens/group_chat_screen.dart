import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/file_service.dart';
import '../services/encryption_service.dart';
import '../services/group_encryption_service.dart';
import '../models/chat.dart';
import '../models/group_chat.dart';
import '../widgets/file_message_widget.dart';
import '../widgets/image_message_widget.dart';
import 'dart:convert';

enum MessageType { text, image, file }

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupTitle;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupTitle,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  List<MessageResponse> _messages = [];
  List<GroupParticipant> _participants = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUserId;
  String? _myPrivateKey;
  String? _groupKey;
  bool _isEncryptionReady = false;
  late WebSocketService _webSocketService;
  final Map<String, Uint8List> _fileCache = {};

  @override
  void initState() {
    super.initState();
    print('🔵 GroupChatScreen initState for group: ${widget.groupId}');

    // Сначала инициализируем WebSocket
    _webSocketService = Provider.of<WebSocketService>(context, listen: false);
    _webSocketService.onNewMessage = _onNewMessage;

    // Потом загружаем данные
    _loadCurrentUser();
    _loadPrivateKey(); // внутри вызовет _loadGroupKey, а тот вызовет _loadMessages
    _loadGroupInfo();
  }

  @override
  void dispose() {
    _webSocketService.onNewMessage = null;
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
    });
    print('🔵 Current user ID: $_currentUserId');
  }

  Future<void> _loadPrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    _myPrivateKey = prefs.getString('private_key');
    if (_myPrivateKey == null) {
      print('❌ Приватный ключ не найден');
    } else {
      print('✅ Приватный ключ загружен: ${_myPrivateKey!.substring(0, 20)}...');
      await _loadGroupKey();
    }
  }

  Future<void> _loadGroupKey() async {
    print('🔵 _loadGroupKey started');
    if (_myPrivateKey == null) {
      print('❌ _myPrivateKey is null, cannot load group key');
      return;
    }
    if (_currentUserId == null) {
      print('❌ _currentUserId is null, cannot load group key');
      return;
    }

    try {
      print(
        '🔑 Getting encrypted key from server for group: ${widget.groupId}',
      );
      final encryptedKey = await _apiService.getGroupEncryptedKey(
        widget.groupId,
      );
      print('🔑 Encrypted key received: $encryptedKey');

      print('🔑 Getting my public key for user: $_currentUserId');
      final myPublicKey = await _apiService.getPublicKey(_currentUserId!);
      if (myPublicKey == null) {
        print('❌ My public key is null');
        return;
      }
      print('✅ My public key: ${myPublicKey.substring(0, 30)}...');

      print('🔑 Deriving shared secret');
      final sharedSecret = EncryptionService.deriveSharedSecret(
        _myPrivateKey!,
        myPublicKey,
      );
      print('✅ Shared secret derived, length: ${sharedSecret.length}');

      print('🔑 Decrypting group key');
      final decryptedKey = EncryptionService.decryptMessage(
        encryptedKey,
        sharedSecret,
      );
      print('✅ Decrypted group key: $decryptedKey');

      setState(() {
        _groupKey = decryptedKey;
        _isEncryptionReady = true;
      });
      print('✅ Ключ группы получен и расшифрован, шифрование готово');

      // Загружаем сообщения после получения ключа
      await _loadMessages();
    } catch (e) {
      print('❌ Ошибка получения ключа группы: $e');
      // Если не удалось получить ключ, всё равно загружаем сообщения
      await _loadMessages();
    }
  }

  Future<void> _loadGroupInfo() async {
    try {
      print('🔵 Loading group info for: ${widget.groupId}');
      final group = await _apiService.getGroupChat(widget.groupId);
      setState(() {
        _participants = group.participants;
        _isAdmin = group.adminIds.contains(_currentUserId);
      });
      print(
        '✅ Group loaded: ${group.title}, participants: ${group.participants.length}, isAdmin: $_isAdmin',
      );
    } catch (e) {
      print('❌ Error loading group info: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      print('🔵 Loading messages for group: ${widget.groupId}');
      final messages = await _apiService.getChatMessages(widget.groupId);
      print('✅ Loaded ${messages.length} messages');

      if (_groupKey != null) {
        print('🔑 Decrypting messages with group key');
        final decryptedMessages = <MessageResponse>[];
        for (final msg in messages) {
          if (msg.content.startsWith('{')) {
            decryptedMessages.add(msg);
          } else {
            try {
              final decryptedText =
                  await GroupEncryptionService.decryptGroupMessage(
                    msg.content,
                    _groupKey!,
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
              print('❌ Failed to decrypt message: $e');
              decryptedMessages.add(msg);
            }
          }
        }
        setState(() {
          _messages = decryptedMessages;
          _isLoading = false;
        });
        print('✅ Decrypted ${decryptedMessages.length} messages');
      } else {
        print('⚠️ No group key, showing messages as is');
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTextMessage(String text) async {
    if (text.isEmpty) return;
    if (_currentUserId == null) {
      print('❌ Cannot send: userId is null');
      return;
    }
    if (!_isEncryptionReady || _groupKey == null) {
      print(
        '❌ Шифрование группы не готово: _isEncryptionReady=$_isEncryptionReady, _groupKey=${_groupKey != null}',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Шифрование не готово')));
      return;
    }

    print('🔐 Sending encrypted message: "$text"');
    final encryptedMessage = await GroupEncryptionService.encryptGroupMessage(
      text,
      _groupKey!,
    );
    print('🔐 Encrypted: $encryptedMessage');
    _webSocketService.sendMessage(
      widget.groupId,
      encryptedMessage,
      _currentUserId!,
    );
    _messageController.clear();
  }

  Future<void> _sendFileToGroup(
    Map<String, dynamic> fileData,
    MessageType type,
  ) async {
    if (_currentUserId == null) return;
    if (!_isEncryptionReady || _groupKey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Шифрование не готово')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fileId = await FileService.uploadFile(
        chatId: widget.groupId,
        fileBytes: fileData['bytes'],
        filename: fileData['name'],
        sharedSecret: [],
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
        widget.groupId,
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

  Future<void> _pickImageForGroup() async {
    final imageData = await FileService.pickImage();
    if (imageData != null) await _sendFileToGroup(imageData, MessageType.image);
  }

  Future<void> _pickFileForGroup() async {
    final fileData = await FileService.pickFile();
    if (fileData != null) await _sendFileToGroup(fileData, MessageType.file);
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
                _pickImageForGroup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.green),
              title: const Text('Файл', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickFileForGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addParticipant() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция добавления участников в разработке'),
      ),
    );
  }

  void _onNewMessage(MessageResponse message) {
    print(
      '📨 New message received in group: ${message.content.substring(0, message.content.length > 50 ? 50 : message.content.length)}...',
    );
    if (message.chatId == widget.groupId && mounted) {
      _decryptAndAddMessage(message);
    }
  }

  Future<void> _decryptAndAddMessage(MessageResponse message) async {
    if (_groupKey == null) {
      print('⚠️ No group key, adding message as is');
      setState(() => _messages.add(message));
      return;
    }

    if (message.content.startsWith('{')) {
      print('📦 Message is JSON (file/image), adding as is');
      setState(() => _messages.add(message));
      return;
    }

    try {
      print(
        '🔓 Decrypting message: ${message.content.substring(0, message.content.length > 50 ? 50 : message.content.length)}...',
      );
      final decryptedText = await GroupEncryptionService.decryptGroupMessage(
        message.content,
        _groupKey!,
      );
      print('✅ Decrypted: "$decryptedText"');
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
      print('❌ Failed to decrypt message: $e');
      setState(() => _messages.add(message));
    }
  }

  Future<Uint8List?> _loadImage(String fileId) async {
    if (_fileCache.containsKey(fileId)) return _fileCache[fileId];
    if (_groupKey == null) return null;

    try {
      final imageData = await FileService.downloadFileWithGroupKey(
        chatId: widget.groupId,
        fileId: fileId,
        groupKey: _groupKey!,
      );
      _fileCache[fileId] = imageData;
      return imageData;
    } catch (e) {
      print('❌ Error loading image: $e');
      return null;
    }
  }

  Future<void> _downloadAndShowFile(
    String fileId,
    String filename,
    int size,
  ) async {
    if (_groupKey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ключ группы не загружен')));
      return;
    }

    if (_fileCache.containsKey(fileId)) {
      _openFile(_fileCache[fileId]!, filename);
      return;
    }

    try {
      final fileData = await FileService.downloadFileWithGroupKey(
        chatId: widget.groupId,
        fileId: fileId,
        groupKey: _groupKey!,
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

  String _getSenderName(String senderId) {
    try {
      final participant = _participants.firstWhere((p) => p.userId == senderId);
      return participant.fullName;
    } catch (e) {
      return 'Пользователь ${senderId.substring(0, 8)}...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.groupTitle,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              onPressed: _addParticipant,
            ),
        ],
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
                      hintText: 'Сообщение в группу...',
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

  Widget _buildMessageBubble(MessageResponse message, bool isMe) {
    final senderName = _getSenderName(message.senderId);

    // Для файлов и изображений
    if (message.content.startsWith('{')) {
      try {
        final data = json.decode(message.content);
        final type = data['type'];
        final fileData = data['data'];

        if (type == 'image') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: SizedBox(
                    width: 200,
                    child: Text(
                      senderName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              FutureBuilder<Uint8List?>(
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
              ),
            ],
          );
        } else if (type == 'file') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: SizedBox(
                    width: 200,
                    child: Text(
                      senderName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              FileMessageWidget(
                filename: fileData['filename'],
                size: fileData['size'],
                isMe: isMe,
                onTap: () => _downloadAndShowFile(
                  fileData['file_id'],
                  fileData['filename'],
                  fileData['size'],
                ),
              ),
            ],
          );
        }
      } catch (e) {}
    }

    // Текстовое сообщение
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: Text(
                    senderName,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Container(
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
          ],
        ),
      ),
    );
  }
}
