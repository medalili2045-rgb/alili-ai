import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers.dart';
import 'screens.dart';

void main() {
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});
  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _prefs = prefs);
    } catch (e) {
      // في حال فشل الذاكرة، نبدأ بدونها لتجنب الانهيار
      if (mounted) setState(() => _prefs = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_prefs == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0A0A0A),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
        ),
      );
    }

    return ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(_prefs!)],
      child: const AliliApp(),
    );
  }
}

class AliliApp extends StatelessWidget {
  const AliliApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          surface: Color(0xFF141414),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}
