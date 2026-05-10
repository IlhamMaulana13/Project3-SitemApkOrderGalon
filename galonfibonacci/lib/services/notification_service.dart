import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {

  static final FlutterLocalNotificationsPlugin
      flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future init() async {

    FirebaseMessaging messaging =
        FirebaseMessaging.instance;

    // request permission
    await messaging.requestPermission();

    // android init
    const AndroidInitializationSettings
        androidSettings =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const InitializationSettings settings =
        InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin
        .initialize(settings);

    // foreground message
    FirebaseMessaging.onMessage.listen(

      (RemoteMessage message) {

        showNotification(
          message.notification?.title ?? "",
          message.notification?.body ?? "",
        );
      },
    );
  }

  static Future showNotification(
    String title,
    String body,
  ) async {

    const AndroidNotificationDetails
        androidDetails =
        AndroidNotificationDetails(

      'galon_channel',
      'Galon Notification',

      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
    );
  }
}