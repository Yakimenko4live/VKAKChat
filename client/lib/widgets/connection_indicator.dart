import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

class ConnectionIndicator extends StatelessWidget {
  final WebSocketService webSocketService;

  const ConnectionIndicator({super.key, required this.webSocketService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: webSocketService,
      builder: (context, _) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getColor(webSocketService.quality),
            boxShadow: [
              BoxShadow(
                color: _getColor(webSocketService.quality).withOpacity(0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
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
}
