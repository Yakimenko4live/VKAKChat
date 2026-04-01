import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'animated_background.dart';
import 'services/websocket_service.dart';
import 'widgets/connection_indicator.dart';
import 'screens/register_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WebSocketService()..connect('ws://localhost:3000/ws'),
      child: MaterialApp(
        title: 'VKAK Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: Stack(
          children: [
            const AnimatedBackground(
              numberOfPoints: 35,
              connectionDistance: 180,
            ),
            const RegisterScreen(),
            Positioned(
              top: 16,
              right: 16,
              child: Consumer<WebSocketService>(
                builder: (context, service, _) => ConnectionIndicator(
                  webSocketService: service,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}