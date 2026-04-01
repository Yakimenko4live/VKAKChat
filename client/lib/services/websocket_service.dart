import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

enum ConnectionQuality {
  excellent,
  good,
  poor,
  disconnected,
}

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Duration _currentLatency = Duration.zero;
  ConnectionQuality _quality = ConnectionQuality.disconnected;
  DateTime? _lastPingSent;
  StreamSubscription? _subscription;
  
  String? _currentUrl;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  
  ConnectionQuality get quality => _quality;
  Duration get latency => _currentLatency;
  
  void connect(String url) {
    _currentUrl = url;
    _isReconnecting = false;
    _reconnectAttempts = 0;
    _doConnect();
  }
  
  void _doConnect() {
    try {
      _channel?.sink.close();
      _subscription?.cancel();
      
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));
      
      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
          // При получении любого сообщения — соединение живо
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
    print('Reconnecting in ${delay.inSeconds} seconds (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _isReconnecting = false;
      _doConnect();
    });
  }
  
  void _handleMessage(dynamic message) {
    if (message == 'pong' && _lastPingSent != null) {
      _currentLatency = DateTime.now().difference(_lastPingSent!);
      _updateQualityByLatency(_currentLatency);
      notifyListeners();
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
  
  void send(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
    }
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
    super.dispose();
  }
}