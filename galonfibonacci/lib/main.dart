import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/provider/cart_provider.dart';
import 'package:galonfibonacci/provider/theme_provider.dart';
import 'package:galonfibonacci/screens/auth_screen.dart';
import 'package:galonfibonacci/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'screens/payment_success_screen.dart';

import 'firebase_options.dart';

Future<void> backgroundHandler(RemoteMessage message) async {
  print("BACKGROUND NOTIF");
  print(message.notification?.title);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // REQUEST IZIN NOTIFIKASI
  await FirebaseMessaging.instance.requestPermission();

  // INIT LOCAL NOTIFICATION
  await NotificationService.init();
  await DeepLinkService.init();

  // BACKGROUND NOTIF
  FirebaseMessaging.onBackgroundMessage(backgroundHandler);

  // foreground notification sudah ditangani di NotificationService.init()

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            home: const AuthScreen(),
          );
        },
      ),
    );
  }
}

class DeepLinkService {
  static Future<void> init() async {
    final appLinks = AppLinks();

    appLinks.uriLinkStream.listen((Uri uri) {

      print("DEEP LINK MASUK");
      print(uri);

      if (uri.host == "payment-success") {

        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const PaymentSuccessScreen(),
          ),
          (route) => false,
        );
      }
    });
  }
}
