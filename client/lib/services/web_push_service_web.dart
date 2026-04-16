import 'dart:js' as js;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WebPushService {
  static const String _vapidPublicKey =
      'BAAZFddWP018osCeyPYLb_VDJoiuRPtoRHirp4JJCTQagc27leAzKlD_BrqeaqSn51z2NcNFl8RzOK3sOfPRtxs';

  static Future<void> init() async {
    print('🌐 Initializing Web Push for iOS PWA');

    try {
      if (!js.context.hasProperty('Notification')) {
        print('📵 Notifications not supported');
        return;
      }

      final notification = js.context['Notification'];
      final permission = await notification
          .callMethod('requestPermission')
          .toFuture;
      if (permission != 'granted') {
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
      final navigator = js.context['navigator'];
      final registration = await navigator['serviceWorker']
          .callMethod('ready')
          .toFuture;

      final existingSubscription = await registration
          .callMethod('getSubscription')
          .toFuture;
      if (existingSubscription != null) {
        print('📱 Already subscribed to push');
        await _sendSubscriptionToServer(existingSubscription);
        return;
      }

      final subscription = await registration.callMethod('subscribe', [
        js.JsObject.jsify({
          'userVisibleOnly': true,
          'applicationServerKey': _vapidPublicKey,
        }),
      ]).toFuture;

      if (subscription != null) {
        print('📱 Push subscription created');
        await _sendSubscriptionToServer(subscription);
      }
    } catch (e) {
      print('❌ Failed to subscribe to push: $e');
    }
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
