import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
  Map<String, dynamic> toJson() => {'text': text, 'isUser': isUser};
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(json['text'], json['isUser']);
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final SharedPreferences prefs;
  ChatNotifier(this.prefs) : super([]) {
    _load();
  }

  void _load() {
    final data = prefs.getString('chat_history');
    if (data != null) {
      final List decoded = jsonDecode(data);
      state = decoded.map((e) => ChatMessage.fromJson(e)).toList();
    } else {
      state = [ChatMessage('أهلاً بك! أنا Alili Omni v4.0. جاهز للبحث والتفكير.', false)];
    }
  }

  void _save() => prefs.setString('chat_history', jsonEncode(state.map((e) => e.toJson()).toList()));

  Future<void> send(String text, bool search, bool thinking) async {
    state = [...state, ChatMessage(text, true)];
    _save();

    final history = state.sublist(0, state.length - 1).map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}).toList();
    final reply = await ApiService.chat(text, history, search, thinking);
    
    state = [...state, ChatMessage(reply, false)];
    _save();
  }

  void clear() {
    state = [ChatMessage('تم مسح المحادثة.', false)];
    _save();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.watch(sharedPrefsProvider));
});
