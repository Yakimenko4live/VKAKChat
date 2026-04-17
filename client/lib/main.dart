import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'animated_background.dart';
import 'services/websocket_service.dart';
import 'services/unread_counter_service.dart';
import 'services/notification_service.dart';
import 'services/web_push_service.dart';
import 'widgets/connection_indicator.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await NotificationService.initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final wsService = WebSocketService();
            wsService.connect('ws://45.153.188.197:3000/ws');
            return wsService;
          },
        ),
        ChangeNotifierProvider(create: (_) => UnreadCounterService()),
      ],
      child: MaterialApp(
        title: 'VKAK Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.transparent,
        ),
        builder: (context, child) {
          return Scaffold(
            resizeToAvoidBottomInset:
                true, // Автоматически сдвигает при появлении клавиатуры
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                const AnimatedBackground(
                  numberOfPoints: 35,
                  connectionDistance: 180,
                ),
                if (child != null) child,
                Positioned(
                  top: 40, // Сдвигаем ниже, чтобы не перекрывало статус-бар
                  right: 16,
                  child: Consumer<WebSocketService>(
                    builder: (context, service, _) =>
                        ConnectionIndicator(webSocketService: service),
                  ),
                ),
              ],
            ),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) {
      _goToAuth();
      return;
    }

    try {
      final userData = await _apiService.getMe(token);
      if (userData.isApproved) {
        final wsService = Provider.of<WebSocketService>(context, listen: false);
        wsService.authenticate(userId);

        if (kIsWeb) {
          await WebPushService.init();
        } else {
          await NotificationService.sendTokenToServer();
        }

        _goToMain();
      } else {
        await prefs.clear();
        _goToAuth();
      }
    } catch (e) {
      await prefs.clear();
      _goToAuth();
    }
  }

  void _goToAuth() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  void _goToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
    );
  }
}
