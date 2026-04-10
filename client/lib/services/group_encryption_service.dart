import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'encryption_service.dart';

class GroupEncryptionService {
  static const String _groupKeysPrefix = 'group_key_';

  /// Генерация случайного AES-ключа для группы
  static Future<String> generateGroupKey() async {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(keyBytes);
  }

  /// Сохранить общий ключ группы локально
  static Future<void> saveGroupKey(
    String groupId,
    String groupKeyBase64,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_groupKeysPrefix}$groupId', groupKeyBase64);
  }

  /// Получить общий ключ группы
  static Future<String?> getGroupKey(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${_groupKeysPrefix}$groupId');
  }

  /// Зашифровать сообщение для группы
  static Future<String> encryptGroupMessage(
    String message,
    String groupKeyBase64,
  ) async {
    final groupKey = base64.decode(groupKeyBase64);
    return EncryptionService.encryptMessage(message, groupKey);
  }

  /// Расшифровать сообщение из группы
  static Future<String> decryptGroupMessage(
    String encryptedMessage,
    String groupKeyBase64,
  ) async {
    final groupKey = base64.decode(groupKeyBase64);
    return EncryptionService.decryptMessage(encryptedMessage, groupKey);
  }
}
