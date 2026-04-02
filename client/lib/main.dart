import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'animated_background.dart';
import 'services/websocket_service.dart';
import 'widgets/connection_indicator.dart';
import 'screens/auth_screen.dart';

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
          // Убедимся, что Scaffold по умолчанию прозрачный во всем приложении
          scaffoldBackgroundColor: Colors.transparent,
        ),
        // Используем builder, чтобы фон был статичным при переходах между экранами
        builder: (context, child) {
          return Stack(
            children: [
              const AnimatedBackground(
                numberOfPoints: 35,
                connectionDistance: 180,
              ),
              if (child != null) child,
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
          );
        },
        home: const AuthScreen(),
      ),
    );
  }
}