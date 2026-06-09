import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  static ThemeData get lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.grey[100],
        cardColor: Colors.white,
        appBarTheme: AppBarTheme(backgroundColor: Colors.blue[700]),
      );

  static ThemeData get darkTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        cardColor: const Color(0xFF16213E),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F3460)),
      );
}
