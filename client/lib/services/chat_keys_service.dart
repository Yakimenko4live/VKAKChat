import 'package:shared_preferences/shared_preferences.dart';
import 'encryption_service.dart';
import 'dart:convert';

class ChatKeysService {
  static const String _sharedSecretsPrefix = 'shared_secret_';

  /// Сохранить общий секрет для чата
  static Future<void> saveSharedSecret(
    String chatId,
    List<int> sharedSecret,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_sharedSecretsPrefix}$chatId',
      base64.encode(sharedSecret),
    );
  }

  /// Получить общий секрет для чата
  static Future<List<int>?> getSharedSecret(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final secret = prefs.getString('${_sharedSecretsPrefix}$chatId');
    if (secret != null) {
      return base64.decode(secret);
    }
    return null;
  }

  /// Сгенерировать и сохранить общий секрет для чата
  static Future<List<int>> generateAndSaveSharedSecret(
    String chatId,
    String otherUserId,
    String myPrivateKey,
    String otherPublicKey,
  ) async {
    final sharedSecret = EncryptionService.deriveSharedSecret(
      myPrivateKey,
      otherPublicKey,
    );
    await saveSharedSecret(chatId, sharedSecret);
    return sharedSecret;
  }
}
