import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class ChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBytes;
  ChatMessage(this.text, this.isUser, {this.imageBytes});
  
  Map<String, dynamic> toJson() => {
    'text': text, 
    'isUser': isUser,
    'image': imageBytes != null ? base64Encode(imageBytes!) : null
  };
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Uint8List? img;
    try {
      if (json['image'] != null) img = base64Decode(json['image']);
    } catch (e) {
      img = null; // تجاهل الصورة إذا كانت تالفة
    }
    return ChatMessage(json['text'] ?? '', json['isUser'] ?? false, imageBytes: img);
  }
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final SharedPreferences prefs;
  
  ChatNotifier(this.prefs) : super([]) { _load(); }

  void _load() {
    try {
      final data = prefs.getString('chat_history');
      if (data != null && data.isNotEmpty) {
        final List decoded = jsonDecode(data);
        state = decoded.map((e) => ChatMessage.fromJson(e)).toList();
        if (state.isEmpty) _defaultState();
      } else {
        _defaultState();
      }
    } catch (e) {
      _defaultState(); // إذا كانت الذاكرة تالفة، نبدأ من جديد
    }
  }

  void _defaultState() {
    state = [ChatMessage('أهلاً بك! أنا Alili Omni v4.0. جاهز للبحث والتفكير.', false)];
    _save();
  }

  void _save() {
    try { prefs.setString('chat_history', jsonEncode(state.map((e) => e.toJson()).toList())); } catch (e) {}
  }

  Future<void> send(String text, Uint8List? imageBytes) async {
    state = [...state, ChatMessage(text, true, imageBytes: imageBytes)];
    _save();

    state = [...state, ChatMessage('', false)];
    final aiIndex = state.length - 1;

    final history = state.sublist(0, state.length - 2).map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}).toList();

    String currentReply = "";
    try {
      await for (final chunk in ApiService.chatStream(text, history, imageBytes)) {
        currentReply += chunk;
        final updatedState = List<ChatMessage>.from(state);
        updatedState[aiIndex] = ChatMessage(currentReply, false);
        state = updatedState;
      }
    } catch(e) {
      final updatedState = List<ChatMessage>.from(state);
      updatedState[aiIndex] = ChatMessage('فشل الاتصال بالخادم.', false);
      state = updatedState;
    }
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
