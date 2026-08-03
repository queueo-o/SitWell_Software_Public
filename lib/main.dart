import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/posture_provider.dart';
import 'providers/theme_notifier.dart';
import 'screens/home_screen.dart';
import 'screens/privacy_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final initialDark = prefs.getBool('is_dark_mode') ?? true;

  runApp(PostureCheckerApp(initialDark: initialDark));
}

class PostureCheckerApp extends StatelessWidget {
  final bool initialDark;
  const PostureCheckerApp({super.key, required this.initialDark});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PostureProvider()),
        ChangeNotifierProvider(
          create: (_) => ThemeNotifier(initialDark: initialDark),
        ),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) {
          return MaterialApp(
            title: 'SitWell',
            debugShowCheckedModeBanner: false,
            themeMode: themeNotifier.mode,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF0099AA),
              brightness: Brightness.light,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: const Color(0xFF00E5FF),
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF060D1F),
              useMaterial3: true,
            ),
            home: Consumer<PostureProvider>(
              builder: (context, p, _) {
                if (!p.prefsLoaded) {
                  return const _SplashScreen();
                }
                if (!p.privacyAccepted) {
                  return const PrivacyScreen();
                }
                return const HomeScreen();
              },
            ),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF060D1F),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      ),
    );
  }
}
