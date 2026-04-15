import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await Firebase.initializeApp();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
  }

  static Future<void> sendTokenToServer() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      print('🔑 FCM Token: $token');

      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null) return;

      await http.post(
        Uri.parse('http://localhost:3000/api/users/fcm_token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({'token': token}),
      );
    } catch (e) {
      print('❌ Failed to send FCM token: $e');
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    await Firebase.initializeApp();
    print('📨 Background message: ${message.messageId}');
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message: ${message.notification?.title}');

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'chat_channel',
          'Chat Notifications',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Новое сообщение',
      message.notification?.body ?? '',
      details,
    );
  }

  static Future<void> _handleMessageOpened(RemoteMessage message) async {
    print('📨 Message opened: ${message.data}');
  }
}
