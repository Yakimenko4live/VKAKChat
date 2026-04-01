import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class ConnectionIndicator extends StatelessWidget {
  final WebSocketService webSocketService;
  
  const ConnectionIndicator({
    super.key,
    required this.webSocketService,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: webSocketService,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getColor(webSocketService.quality).withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _getColor(webSocketService.quality).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _getColor(webSocketService.quality),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getColor(webSocketService.quality).withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getText(webSocketService.quality),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (webSocketService.latency.inMilliseconds > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '(${webSocketService.latency.inMilliseconds}ms)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Color _getColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Colors.green;
      case ConnectionQuality.good:
        return Colors.orange;
      case ConnectionQuality.poor:
        return Colors.red;
      case ConnectionQuality.disconnected:
        return Colors.grey;
    }
  }
  
  String _getText(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 'Отлично';
      case ConnectionQuality.good:
        return 'Средне';
      case ConnectionQuality.poor:
        return 'Плохо';
      case ConnectionQuality.disconnected:
        return 'Нет связи';
    }
  }
}