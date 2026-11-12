import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());
final isGeneratingProvider = StateProvider<bool>((ref) => false);

class AppSettings {
  final String model;
  final String systemPrompt;
  final double temperature;
  final double voiceSpeed;
  final bool useSearch;
  final bool useThinking;

  AppSettings({
    this.model = 'glm',
    this.systemPrompt = 'أنت مساعد ذكي.',
    this.temperature = 0.5,
    this.voiceSpeed = 0.5,
    this.useSearch = false,
    this.useThinking = false,
  });
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences prefs;
  SettingsNotifier(this.prefs) : super(AppSettings(
    model: prefs.getString('model') ?? 'glm',
    systemPrompt: prefs.getString('system_prompt') ?? 'أنت مساعد ذكي.',
    temperature: prefs.getDouble('temperature') ?? 0.5,
    voiceSpeed: prefs.getDouble('voice_speed') ?? 0.5,
    useSearch: prefs.getBool('use_search') ?? false,
    useThinking: prefs.getBool('use_thinking') ?? false,
  ));

  void update(AppSettings s) {
    state = s;
    prefs.setString('model', s.model);
    prefs.setString('system_prompt', s.systemPrompt);
    prefs.setDouble('temperature', s.temperature);
    prefs.setDouble('voice_speed', s.voiceSpeed);
    prefs.setBool('use_search', s.useSearch);
    prefs.setBool('use_thinking', s.useThinking);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(sharedPrefsProvider));
});

class ChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBase64;

  ChatMessage({this.text = '', required this.isUser, this.imageBase64});

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'imageBase64': imageBase64 != null ? base64Encode(imageBase64!) : null,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    Uint8List? img;
    try {
      if (j['imageBase64'] != null) img = base64Decode(j['imageBase64']);
    } catch (e) {
      img = null;
    }
    return ChatMessage(text: j['text'] ?? '', isUser: j['isUser'] ?? false, imageBase64: img);
  }
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final SharedPreferences prefs;
  final Ref ref;
  List<String> userMemory = [];
  Timer? _flushTimer;
  String _buffer = "";
  int _aiIndex = -1;

  ChatNotifier(this.prefs, this.ref) : super([]) {
    _load();
  }

  void _load() {
    try {
      final d = prefs.getString('chat_history');
      if (d != null && d.isNotEmpty) {
        state = (jsonDecode(d) as List).map((e) => ChatMessage.fromJson(e)).toList();
      } else {
        state = [ChatMessage(text: 'مرحباً! أنا Alili. اسأل، ارسم، أو اطلب كود.', isUser: false)];
      }
      userMemory = prefs.getStringList('user_memory') ?? [];
    } catch (e) {
      state = [ChatMessage(text: 'مرحباً!', isUser: false)];
    }
  }

  void _save() {
    prefs.setString('chat_history', jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  void _flush() {
    if (_buffer.isEmpty || _aiIndex == -1) return;
    final u = List<ChatMessage>.from(state);
    if (_aiIndex < u.length) {
      u[_aiIndex] = ChatMessage(text: _buffer, isUser: false, imageBase64: u[_aiIndex].imageBase64);
      state = u;
    }
  }

  Future<void> send(String text, Uint8List? img, AppSettings s) async {
    ref.read(isGeneratingProvider.notifier).state = true;
    state = [...state, ChatMessage(text: text, isUser: true, imageBase64: img)];
    _save();
    
    state = [...state, ChatMessage(text: '', isUser: false)];
    _aiIndex = state.length - 1;
    _buffer = "";
    
    _flushTimer = Timer.periodic(const Duration(milliseconds: 80), (_) => _flush());
    final history = state.sublist(0, state.length - 2).map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    try {
      await for (final chunk in ApiService.chatStream(text, history, userMemory, img, s)) {
        final d = jsonDecode(chunk);
        if (d['type'] == 'text') {
          _buffer += d['text'];
        } else if (d['type'] == 'code_output') {
          _buffer += "\n\n**المخرجات:**\n```\n${d['output']}\n```";
        } else if (d['type'] == 'image') {
          _flushTimer?.cancel();
          final u = List<ChatMessage>.from(state);
          u[_aiIndex] = ChatMessage(text: _buffer.isEmpty ? '🎨 الصورة جاهزة' : _buffer, isUser: false, imageBase64: base64Decode(d['base64']));
          state = u;
          _save();
          ref.read(isGeneratingProvider.notifier).state = false;
          return;
        }
      }
    } catch (e) {
      _buffer += "\n\n(فشل الاتصال بالخادم)";
    } finally {
      _flushTimer?.cancel();
      _flush();
      _save();
      ref.read(isGeneratingProvider.notifier).state = false;
    }
  }

  void clear() {
    state = [ChatMessage(text: 'تم مسح المحادثة.', isUser: false)];
    _save();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.watch(sharedPrefsProvider), ref);
});
