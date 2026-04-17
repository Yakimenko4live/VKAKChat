import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/department.dart';
import '../models/auth.dart';
import '../models/chat.dart';
import '../models/group_chat.dart';
import '../services/group_encryption_service.dart';
import '../services/encryption_service.dart';

class ApiService {
  static const String baseUrl = 'http://45.153.188.197:3000';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Department>> getDepartments() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/departments'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decodedBody);
      return data.map((json) => Department.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load departments');
    }
  }

  Future<void> register(User user, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/register'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: utf8.encode(json.encode({...user.toJson(), 'password': password})),
    );

    if (response.statusCode != 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final error = json.decode(decodedBody);
      throw Exception(error['message'] ?? 'Registration failed');
    }
  }

  Future<LoginResponse> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: utf8.encode(
        json.encode({'identifier': identifier, 'password': password}),
      ),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = json.decode(decodedBody);
      return LoginResponse.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Неверный логин или пароль');
    } else if (response.statusCode == 403) {
      throw Exception('Аккаунт не подтверждён администратором');
    } else {
      final decodedBody = utf8.decode(response.bodyBytes);
      final error = json.decode(decodedBody);
      throw Exception(error['message'] ?? 'Ошибка входа');
    }
  }

  Future<UserData> getMe(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/me'),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = json.decode(decodedBody);
      return UserData.fromJson(data);
    } else {
      throw Exception('Ошибка загрузки данных пользователя');
    }
  }

  Future<String?> getPublicKey(String userId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/$userId/public_key'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = json.decode(decodedBody);
      return data['public_key'];
    }
    return null;
  }

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/users/search?q=${Uri.encodeQueryComponent(query)}',
      ),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decodedBody);
      return data.map((json) => UserSearchResult.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search users');
    }
  }

  Future<List<DepartmentNode>> getDepartmentTree() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/departments/tree'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decodedBody);
      return data.map((json) => DepartmentNode.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load department tree');
    }
  }

  // Новые методы для чатов
  Future<ChatResponse> createChat(String otherUserId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/chats/create'),
      headers: headers,
      body: utf8.encode(json.encode({'other_user_id': otherUserId})),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      return ChatResponse.fromJson(json.decode(decodedBody));
    } else {
      throw Exception('Failed to create chat');
    }
  }

  Future<List<ChatResponse>> getUserChats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/chats'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decodedBody);
      return data.map((json) => ChatResponse.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load chats');
    }
  }

  Future<List<MessageResponse>> getChatMessages(String chatId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/chats/$chatId/messages'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decodedBody);
      return data.map((json) => MessageResponse.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<MessageResponse> sendMessage(String chatId, String content) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/messages/send'),
      headers: headers,
      body: utf8.encode(json.encode({'chat_id': chatId, 'content': content})),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      return MessageResponse.fromJson(json.decode(decodedBody));
    } else {
      throw Exception('Failed to send message');
    }
  }

  Future<UserData> getCurrentUser() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/me'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = json.decode(decodedBody);
      return UserData.fromJson(data);
    } else {
      throw Exception('Failed to load user data');
    }
  }

  Future<void> updateProfile({
    required String surname,
    required String name,
    String? patronymic,
    String? comment,
  }) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/me'),
      headers: headers,
      body: utf8.encode(
        json.encode({
          'surname': surname,
          'name': name,
          'patronymic': patronymic,
          'comment': comment,
        }),
      ),
    );

    if (response.statusCode != 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final error = json.decode(decodedBody);
      throw Exception(error['message'] ?? 'Failed to update profile');
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/change-password'),
      headers: headers,
      body: utf8.encode(
        json.encode({'old_password': oldPassword, 'new_password': newPassword}),
      ),
    );

    if (response.statusCode != 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final error = json.decode(decodedBody);
      throw Exception(error['message'] ?? 'Failed to change password');
    }
  }

  Future<List<UserSearchResult>> getPendingUsers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/pending'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decodedBody);
      return data.map((json) => UserSearchResult.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load pending users');
    }
  }

  Future<void> approveUser(String userId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/approve/$userId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to approve user');
    }
  }

  Future<void> rejectUser(String userId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/admin/reject/$userId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reject user');
    }
  }

  // Добавь в конец класса ApiService

  Future<GroupChat> createGroupChat(
    String title,
    List<String> participantIds,
  ) async {
    final headers = await _getHeaders();

    // Получаем свой приватный ключ
    final prefs = await SharedPreferences.getInstance();
    final myPrivateKey = prefs.getString('private_key');
    if (myPrivateKey == null) {
      throw Exception('Приватный ключ не найден');
    }

    // Получаем свой публичный ключ
    final currentUserId = prefs.getString('userId');
    final myPublicKey = await getPublicKey(currentUserId!);
    if (myPublicKey == null) {
      throw Exception('Публичный ключ не найден');
    }

    // Генерируем общий ключ для группы
    final groupKey = await GroupEncryptionService.generateGroupKey();

    // Шифруем ключ для каждого участника
    final Map<String, String> encryptedKeys = {};

    // Для себя
    final mySharedSecret = EncryptionService.deriveSharedSecret(
      myPrivateKey,
      myPublicKey,
    );
    final myEncryptedKey = EncryptionService.encryptMessage(
      groupKey,
      mySharedSecret,
    );
    encryptedKeys[currentUserId] = myEncryptedKey;

    // Для остальных участников
    for (final userId in participantIds) {
      final userPublicKey = await getPublicKey(userId);
      if (userPublicKey != null) {
        final sharedSecret = EncryptionService.deriveSharedSecret(
          myPrivateKey,
          userPublicKey,
        );
        final encryptedKey = EncryptionService.encryptMessage(
          groupKey,
          sharedSecret,
        );
        encryptedKeys[userId] = encryptedKey;
      }
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/groups/create'),
      headers: headers,
      body: utf8.encode(
        json.encode({
          'title': title,
          'participant_ids': participantIds,
          'encrypted_keys': encryptedKeys,
        }),
      ),
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = json.decode(decodedBody);
      // Сохраняем ключ группы локально
      await GroupEncryptionService.saveGroupKey(data['id'], groupKey);
      return GroupChat.fromJson(data);
    } else {
      final decodedBody = utf8.decode(response.bodyBytes);
      print('❌ Ошибка создания группы: ${response.statusCode} - $decodedBody');
      throw Exception('Failed to create group chat');
    }
  }

  Future<List<GroupChat>> getUserGroupChats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/groups'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decodedBody);
      return data.map((json) => GroupChat.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load group chats');
    }
  }

  Future<GroupChat> getGroupChat(String groupId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/groups/$groupId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = json.decode(decodedBody);
      return GroupChat.fromJson(data);
    } else {
      throw Exception('Failed to load group chat');
    }
  }

  Future<void> addGroupParticipants(
    String groupId,
    List<String> userIds,
    String groupKey, // добавить третий параметр
  ) async {
    final headers = await _getHeaders();

    final prefs = await SharedPreferences.getInstance();
    final myPrivateKey = prefs.getString('private_key');
    if (myPrivateKey == null) {
      throw Exception('Приватный ключ не найден');
    }

    // Шифруем групповой ключ для каждого нового участника
    final Map<String, String> encryptedKeys = {};

    for (final userId in userIds) {
      final userPublicKey = await getPublicKey(userId);
      if (userPublicKey != null) {
        final sharedSecret = EncryptionService.deriveSharedSecret(
          myPrivateKey,
          userPublicKey,
        );
        final encryptedKey = EncryptionService.encryptMessage(
          groupKey,
          sharedSecret,
        );
        encryptedKeys[userId] = encryptedKey;
      }
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/add'),
      headers: headers,
      body: utf8.encode(
        json.encode({'user_ids': userIds, 'encrypted_keys': encryptedKeys}),
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add participants');
    }
  }

  Future<void> setUserRole(String userId, String role) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/set-role/$userId'),
      headers: headers,
      body: utf8.encode(json.encode({'role': role})),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set user role');
    }
  }

  Future<void> removeGroupParticipant(String groupId, String userId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/groups/$groupId/remove/$userId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove participant');
    }
  }

  Future<void> leaveGroupChat(String groupId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/leave'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to leave group');
    }
  }

  Future<String> getGroupEncryptedKey(String groupId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/groups/$groupId/key'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = json.decode(decodedBody);
      return data['encrypted_key'];
    } else {
      throw Exception('Failed to get group key');
    }
  }

  Future<List<AllUser>> getAllUsers() async {
    print('🔵 getAllUsers called');
    final headers = await _getHeaders();
    print('🔵 Headers: $headers');

    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/users'),
      headers: headers,
    );

    print('🔵 Response status: ${response.statusCode}');
    print('🔵 Response body: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = json.decode(decodedBody);
      return data.map((json) => AllUser.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/chats/$chatId/read'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final error = json.decode(decodedBody);
      throw Exception(error['message'] ?? 'Failed to mark messages as read');
    }
  }
}
