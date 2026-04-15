import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../models/chat.dart';
import '../services/unread_counter_service.dart';

enum ConnectionQuality { excellent, good, poor, disconnected }

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Duration _currentLatency = Duration.zero;
  ConnectionQuality _quality = ConnectionQuality.disconnected;
  DateTime? _lastPingSent;
  StreamSubscription? _subscription;

  String? _currentUserId;
  String? _currentUrl;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  final _messageController = StreamController<MessageResponse>.broadcast();
  final _newChatController = StreamController<Map<String, dynamic>>.broadcast();
  final _newGroupChatController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<MessageResponse> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get newChatStream => _newChatController.stream;
  Stream<Map<String, dynamic>> get newGroupChatStream => _newGroupChatController.stream;

  ConnectionQuality get quality => _quality;
  Duration get latency => _currentLatency;

  void connect(String url) {
    _currentUrl = url;
    _isReconnecting = false;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  void authenticate(String userId) {
    if (_channel != null) {
      final authMsg = json.encode({'type': 'auth', 'user_id': userId});
      _channel!.sink.add(authMsg);
      print('WebSocket authenticated for user: $userId');
    }
  }

  void _doConnect() {
    try {
      _channel?.sink.close();
      _subscription?.cancel();

      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
          if (_quality == ConnectionQuality.disconnected) {
            _updateQuality(ConnectionQuality.excellent);
            _reconnectAttempts = 0;
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket disconnected');
          _handleDisconnect();
        },
      );

      print('WebSocket connected');
      _startPing();
      _updateQuality(ConnectionQuality.excellent);
      _reconnectAttempts = 0;
      _isReconnecting = false;
    } catch (e) {
      print('WebSocket connection failed: $e');
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic message) {
    if (message == 'pong') {
      if (_lastPingSent != null) {
        _currentLatency = DateTime.now().difference(_lastPingSent!);
        _updateQualityByLatency(_currentLatency);
        notifyListeners();
      }
      return;
    }

    try {
      final data = json.decode(message);
      if (data['type'] == 'new_message') {
        final msg = MessageResponse.fromJson(data['data']);
        
        // Отправляем событие в поток
        _messageController.add(msg);

        // ✅ Увеличиваем счётчик для личных И групповых чатов
        if (_currentUserId != null && msg.senderId != _currentUserId) {
          UnreadCounterService().incrementUnread(msg.chatId);
          print('📊 Incremented unread for chat: ${msg.chatId}');
        }
      } else if (data['type'] == 'new_chat') {
        _newChatController.add(data['data']);
      } else if (data['type'] == 'new_group_chat') {
        _newGroupChatController.add(data['data']);
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void sendMessage(String chatId, String content, String senderId) {
    if (_channel != null) {
      final message = json.encode({
        'type': 'message',
        'data': {'chat_id': chatId, 'content': content, 'sender_id': senderId},
      });
      _channel!.sink.add(message);
    }
  }

  void _startPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _sendPing();
    });
  }

  void _sendPing() {
    if (_channel != null) {
      _lastPingSent = DateTime.now();
      _channel!.sink.add('ping');
    }
  }

  void _updateQualityByLatency(Duration latency) {
    if (latency.inMilliseconds < 100) {
      _updateQuality(ConnectionQuality.excellent);
    } else if (latency.inMilliseconds < 300) {
      _updateQuality(ConnectionQuality.good);
    } else {
      _updateQuality(ConnectionQuality.poor);
    }
  }

  void _updateQuality(ConnectionQuality newQuality) {
    if (_quality != newQuality) {
      _quality = newQuality;
      notifyListeners();
    }
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _handleDisconnect() {
    _stopPing();
    _updateQuality(ConnectionQuality.disconnected);
    _startReconnect();
  }

  void _startReconnect() {
    if (_isReconnecting) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Max reconnect attempts reached, stopping');
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;

    final delay = Duration(seconds: _reconnectAttempts * 2);
    print(
      'Reconnecting in ${delay.inSeconds} seconds (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _isReconnecting = false;
      _doConnect();
    });
  }

  void disconnect() {
    _stopPing();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    _newChatController.close();
    _newGroupChatController.close();
    super.dispose();
  }
}