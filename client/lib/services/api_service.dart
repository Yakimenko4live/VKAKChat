import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/department.dart';
import '../models/auth.dart';
import '../models/chat.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

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
}
