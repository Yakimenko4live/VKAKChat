import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/department.dart';
import 'dart:convert';
import '../models/auth.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

  Future<List<Department>> getDepartments() async {
    final response = await http.get(Uri.parse('$baseUrl/api/departments'));

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
}
