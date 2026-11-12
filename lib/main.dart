import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers.dart';
import 'screens.dart';

void main() => runApp(const BootstrapApp());

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});
  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  SharedPreferences? _prefs;
  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    try { final p = await SharedPreferences.getInstance(); if (mounted) setState(() => _prefs = p); }
    catch (e) { if (mounted) setState(() => _prefs = null); }
  }
  @override
  Widget build(BuildContext context) {
    if (_prefs == null) {
      return const MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: Colors.grey))));
    }
    return ProviderScope(overrides: [sharedPrefsProvider.overrideWithValue(_prefs!)], child: const AliliApp());
  }
}

class AliliApp extends StatelessWidget {
  const AliliApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0F0F0F), colorScheme: const ColorScheme.dark(surface: Color(0xFF1A1A1A))),
      home: const ChatScreen(), // تبويب واحد ذكي
    );
  }
}
