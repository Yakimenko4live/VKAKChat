import 'dart:js' as js;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WebPushService {
  static const String _vapidPublicKey =
      'BIRJVNhgVihe7MZkCdz_Vu6LE_sr8Pd8dXpFg1gFSKif3gFCTZPd36ydlaFrSO9qH3-LaIj5iD4Ysxet4j8Dv2I';

  static Future<void> init() async {
    print('🌐 Initializing Web Push for iOS PWA');

    try {
      final hasNotification = js.context.hasProperty('Notification');
      if (!hasNotification) {
        print('📵 Notifications not supported');
        return;
      }

      final notification = js.context['Notification'];
      final permission = notification.callMethod('requestPermission');
      final permissionResult = await permission.toFuture;

      if (permissionResult != 'granted') {
        print('❌ Notification permission denied');
        return;
      }

      await _subscribe();
    } catch (e) {
      print('❌ Web Push init error: $e');
    }
  }

  static Future<void> _subscribe() async {
    try {
      final registration = await _getServiceWorkerRegistration();
      if (registration == null) {
        print('❌ No service worker registration');
        return;
      }

      final existingSubscription = await _getPushSubscription(registration);
      if (existingSubscription != null) {
        print('📱 Already subscribed to push');
        await _sendSubscriptionToServer(existingSubscription);
        return;
      }

      final subscription = await _subscribeToPush(registration);
      if (subscription != null) {
        print('📱 Push subscription created');
        await _sendSubscriptionToServer(subscription);
      }
    } catch (e) {
      print('❌ Failed to subscribe to push: $e');
    }
  }

  static Future<dynamic> _getServiceWorkerRegistration() async {
    final navigator = js.context['navigator'];
    final serviceWorker = navigator['serviceWorker'];
    final ready = serviceWorker.callMethod('ready');
    return await ready.toFuture;
  }

  static Future<dynamic> _getPushSubscription(dynamic registration) async {
    final pushManager = registration['pushManager'];
    final subscription = await pushManager
        .callMethod('getSubscription')
        .toFuture;
    return subscription;
  }

  static Future<dynamic> _subscribeToPush(dynamic registration) async {
    final pushManager = registration['pushManager'];
    final subscription = await pushManager.callMethod('subscribe', [
      js.JsObject.jsify({
        'userVisibleOnly': true,
        'applicationServerKey': _vapidPublicKey,
      }),
    ]).toFuture;
    return subscription;
  }

  static Future<void> _sendSubscriptionToServer(dynamic subscription) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print('❌ No token, cannot save push subscription');
      return;
    }

    final endpoint = subscription['endpoint'];
    final keys = subscription['keys'];

    final subscriptionJson = {
      'endpoint': endpoint,
      'keys': {'p256dh': keys['p256dh'], 'auth': keys['auth']},
    };

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/webpush/subscribe'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'subscription': subscriptionJson}),
      );

      if (response.statusCode == 200) {
        print('✅ Push subscription saved on server');
      } else {
        print('❌ Failed to save push subscription: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending subscription: $e');
    }
  }
}
