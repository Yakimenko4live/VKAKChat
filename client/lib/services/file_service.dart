import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'encryption_service.dart';

class FileService {
  static const String baseUrl = 'http://localhost:3000';

  static Future<Map<String, dynamic>?> pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    return {
      'bytes': bytes,
      'name': image.name,
      'size': bytes.length,
      'mimeType': lookupMimeType(image.name) ?? 'image/jpeg',
    };
  }

  static Future<Map<String, dynamic>?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    return {
      'bytes': bytes,
      'name': file.name,
      'size': bytes.length,
      'mimeType': lookupMimeType(file.name) ?? 'application/octet-stream',
    };
  }

  static Future<String> uploadFile({
    required String chatId,
    required List<int> fileBytes,
    required String filename,
    required List<int> sharedSecret,
  }) async {
    // Шифруем файл
    final encryptedData = await _encryptFileData(fileBytes, sharedSecret);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/files/upload'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['chat_id'] = chatId;
    request.fields['filename'] = filename;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        encryptedData,
        filename: '${DateTime.now().millisecondsSinceEpoch}_$filename',
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = json.decode(responseBody);
      return data['file_id'];
    } else {
      throw Exception('Failed to upload file: $responseBody');
    }
  }

  static Future<Uint8List> downloadFile({
    required String chatId,
    required String fileId,
    required List<int> sharedSecret,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/files/download/$chatId/$fileId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      // Расшифровываем файл
      return await _decryptFileData(response.bodyBytes, sharedSecret);
    } else {
      throw Exception('Failed to download file');
    }
  }

  static Future<List<int>> _encryptFileData(
    List<int> data,
    List<int> sharedSecret,
  ) async {
    // Генерируем случайный IV
    final iv = List<int>.generate(16, (_) => DateTime.now().microsecond % 256);

    // Создаём ключ из shared secret
    final keyBytes =
        sharedSecret.length >= 32
              ? sharedSecret.sublist(0, 32)
              : List<int>.filled(32, 0)
          ..setAll(0, sharedSecret);

    // Для простоты пока используем XOR шифрование
    // TODO: заменить на реальное AES шифрование
    final encrypted = List<int>.from(data);
    for (int i = 0; i < encrypted.length; i++) {
      encrypted[i] = encrypted[i] ^ keyBytes[i % keyBytes.length];
    }

    return [...iv, ...encrypted];
  }

  static Future<Uint8List> _decryptFileData(
    List<int> encryptedData,
    List<int> sharedSecret,
  ) async {
    // Извлекаем IV (первые 16 байт)
    final iv = encryptedData.sublist(0, 16);
    final ciphertext = encryptedData.sublist(16);

    // Создаём ключ
    final keyBytes =
        sharedSecret.length >= 32
              ? sharedSecret.sublist(0, 32)
              : List<int>.filled(32, 0)
          ..setAll(0, sharedSecret);

    // XOR расшифровка
    final decrypted = List<int>.from(ciphertext);
    for (int i = 0; i < decrypted.length; i++) {
      decrypted[i] = decrypted[i] ^ keyBytes[i % keyBytes.length];
    }

    return Uint8List.fromList(decrypted);
  }

  static Future<Uint8List> downloadFileWithGroupKey({
    required String chatId,
    required String fileId,
    required String groupKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/api/files/download/$chatId/$fileId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      // Расшифровываем файл групповым ключом
      return await _decryptFileDataWithGroupKey(response.bodyBytes, groupKey);
    } else {
      throw Exception('Failed to download file');
    }
  }

  static Future<Uint8List> _decryptFileDataWithGroupKey(
    List<int> encryptedData,
    String groupKeyBase64,
  ) async {
    final groupKey = base64.decode(groupKeyBase64);

    // Извлекаем IV (первые 16 байт)
    final iv = encryptedData.sublist(0, 16);
    final ciphertext = encryptedData.sublist(16);

    // Создаём ключ из group key (первые 32 байта)
    final keyBytes =
        groupKey.length >= 32
              ? groupKey.sublist(0, 32)
              : List<int>.filled(32, 0)
          ..setAll(0, groupKey);

    // XOR расшифровка (для простоты, потом заменить на AES)
    final decrypted = List<int>.from(ciphertext);
    for (int i = 0; i < decrypted.length; i++) {
      decrypted[i] = decrypted[i] ^ keyBytes[i % keyBytes.length];
    }

    return Uint8List.fromList(decrypted);
  }
}
