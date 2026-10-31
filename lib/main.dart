import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const ProviderScope(child: AliliApp()));
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
        colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF), surface: Color(0xFF141414)),
        textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([ChatMessage('أهلاً بك! أنا Alili Omni v4.0. جاهز للانطلاق؟', false)]);

  void send(String text) {
    state = [...state, ChatMessage(text, true)];
    // رد تجريبي (سيتم ربطه بالخادم لاحقاً)
    Future.delayed(const Duration(seconds: 1), () {
      state = [...state, ChatMessage('هذا رد تجريبي. الخادم جاهز للربط!', false)];
    });
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) => ChatNotifier());

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).send(_controller.text.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alili Omni', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0A0A),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFF1E1E24) : const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(20),
                      border: msg.isUser ? null : Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: msg.isUser 
                      ? Text(msg.text, style: const TextStyle(color: Colors.white))
                      : MarkdownBody(
                          data: msg.text,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.white70),
                            code: const TextStyle(backgroundColor: Colors.black45, color: Color(0xFF00E5FF)),
                          ),
                        ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اسأل عن أي شيء...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF141414),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF00E5FF),
                  child: IconButton(icon: const Icon(Icons.arrow_upward, color: Colors.black), onPressed: _send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
