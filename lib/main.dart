import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/api_service.dart';
import 'services/history_service.dart';
import 'services/watchlist_service.dart';
import 'services/cast_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    title: 'MAGI',
    titleBarStyle: TitleBarStyle.hidden,
    minimumSize: Size(800, 600),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => HistoryService()),
        ChangeNotifierProvider(create: (_) => WatchlistService()),
        ChangeNotifierProvider(create: (_) => CastService()),
      ],
      child: const MagiApp(),
    ),
  );
}

class MagiApp extends StatelessWidget {
  const MagiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAGI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0a0b0f),
          primary: Color(0xFF00d4d4),
          secondary: Color(0xFF00d4d4),
          onSurface: Color(0xFFc8ccd8),
        ),
        scaffoldBackgroundColor: const Color(0xFF0a0b0f),
        fontFamily: 'monospace',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0f1117),
          foregroundColor: Color(0xFF00d4d4),
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF0f1117),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
