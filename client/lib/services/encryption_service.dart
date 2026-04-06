import 'dart:convert';
import 'dart:typed_data';
import 'package:elliptic/elliptic.dart';
import 'package:elliptic/ecdh.dart' as ecdh;
import 'package:encrypt/encrypt.dart' as encrypt_lib;

class EncryptionService {
  static final _ec = getSecp256k1();

  /// Генерация пары ключей (приватный и публичный)
  static ({String privateKey, String publicKey}) generateKeyPair() {
    final private = _ec.generatePrivateKey();
    final public = private.publicKey;

    return (
      privateKey: _encodePrivateKey(private),
      publicKey: _encodePublicKey(public),
    );
  }

  /// Получение общего секрета для шифрования (ECDH)
  static List<int> deriveSharedSecret(
    String privateKeyHex,
    String otherPublicKeyHex,
  ) {
    final private = _decodePrivateKey(privateKeyHex);
    final otherPublic = _decodePublicKey(otherPublicKeyHex);

    // Вычисляем общий секрет с помощью модуля ecdh
    final sharedSecret = ecdh.computeSecret(private, otherPublic);
    return sharedSecret;
  }

  /// Шифрование сообщения с использованием общего секрета (AES-256)
  static String encryptMessage(String message, List<int> sharedSecret) {
    // Создаём ключ из shared secret (берём первые 32 байта)
    final keyBytes = sharedSecret.length >= 32
        ? sharedSecret.sublist(0, 32)
        : (List<int>.filled(32, 0)..setAll(0, sharedSecret));

    // Используем Uint8List для инициализации Key и IV
    final key = encrypt_lib.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt_lib.IV.fromSecureRandom(16);
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    );

    final encrypted = encrypter.encrypt(message, iv: iv);

    // Сохраняем IV + зашифрованное сообщение
    final result = base64.encode([...iv.bytes, ...encrypted.bytes]);
    return result;
  }

  /// Расшифровка сообщения
  static String decryptMessage(String encryptedBase64, List<int> sharedSecret) {
    final encryptedBytes = base64.decode(encryptedBase64);

    // Извлекаем IV (первые 16 байт)
    final ivBytes = encryptedBytes.sublist(0, 16);
    final ciphertext = encryptedBytes.sublist(16);

    // Создаём ключ
    final keyBytes = sharedSecret.length >= 32
        ? sharedSecret.sublist(0, 32)
        : (List<int>.filled(32, 0)..setAll(0, sharedSecret));

    // Используем Uint8List для инициализации Key и IV
    final key = encrypt_lib.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt_lib.IV(Uint8List.fromList(ivBytes));
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    );

    final decrypted = encrypter.decrypt(
      encrypt_lib.Encrypted(Uint8List.fromList(ciphertext)),
      iv: iv,
    );
    return decrypted;
  }

  // Вспомогательные функции для кодирования/декодирования ключей в формат Hex
  static String _encodePrivateKey(PrivateKey private) {
    return private.toHex();
  }

  static String _encodePublicKey(PublicKey public) {
    return public.toHex();
  }

  static PrivateKey _decodePrivateKey(String hexKey) {
    return PrivateKey.fromHex(_ec, hexKey);
  }

  static PublicKey _decodePublicKey(String hexKey) {
    return PublicKey.fromHex(_ec, hexKey);
  }
}
