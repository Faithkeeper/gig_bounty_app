import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize push notifications & request user permissions
  Future<void> initNotifications() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions.');
      
      // Register the app instance and listen for its Firebase Installation ID.
      _messaging.onRegistered.listen((installationId) {
        debugPrint('FCM app instance registered: $installationId');
      });
      await _messaging.register();
      
      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground notification: ${message.notification?.title}');
      });
    } else {
      debugPrint('User declined or did not accept notification permissions.');
    }
  }
}