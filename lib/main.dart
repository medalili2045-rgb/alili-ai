import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [const ChatScreen(), const ImageScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF141414),
        indicatorColor: const Color(0xFF00E5FF).withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF00E5FF)), label: 'الدردشة'),
          NavigationDestination(icon: Icon(Icons.image_outlined), selectedIcon: Icon(Icons.image, color: Color(0xFF00E5FF)), label: 'الصور'),
        ],
      ),
    );
  }
}

// ==================== 1. الدردشة ====================
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, this.isUser);
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([ChatMessage('أهلاً بك! أنا Alili Omni v4.0. جاهز للبحث والتفكير.', false)]);

  Future<void> send(String text, bool search, bool thinking) async {
    state = [...state, ChatMessage(text, true)];

    final history = state.sublist(0, state.length - 1).map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    try {
      final response = await http.post(
        Uri.parse('https://alili-omni.medalili2045.workers.dev'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text, 
          'type': 'chat', 
          'search': search, 
          'thinking': thinking,
          'history': history, 
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        state = [...state, ChatMessage(data['reply'] ?? data['error'] ?? 'خطأ', false)];
      } else {
        state = [...state, ChatMessage('خطأ في الخادم', false)];
      }
    } catch (e) {
      state = [...state, ChatMessage('فشل الاتصال: $e', false)];
    }
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
  bool _useSearch = false;
  bool _useThinking = false;

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).send(_controller.text.trim(), _useSearch, _useThinking);
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
            color: const Color(0xFF0A0A0A),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildToggle(Icons.search, 'بحث', _useSearch, () => setState(() => _useSearch = !_useSearch)),
                    const SizedBox(width: 8),
                    _buildToggle(Icons.psychology, 'تفكير', _useThinking, () => setState(() => _useThinking = !_useThinking)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? const Color(0xFF00E5FF) : const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? const Color(0xFF00E5FF) : Colors.white54),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isActive ? const Color(0xFF00E5FF) : Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ==================== 2. استوديو الصور ====================
class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});
  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Uint8List? _imageData;

  Future<void> _generate() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() { _isLoading = true; _imageData = null; });

    try {
      final res = await http.post(
        Uri.parse('https://alili-omni.medalili2045.workers.dev'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': _controller.text.trim(), 'type': 'image'}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final contentType = res.headers['content-type'] ?? '';
        if (contentType.contains('image')) {
          setState(() => _imageData = res.bodyBytes);
        } else {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'فشل توليد الصورة')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل توليد الصورة')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استوديو الصور'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'صف الصورة (مثال: قطة رائد فضاء)...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true, fillColor: const Color(0xFF141414),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                suffixIcon: IconButton(icon: const Icon(Icons.auto_awesome, color: Color(0xFF00E5FF)), onPressed: _generate),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                : _imageData != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_imageData!, fit: BoxFit.contain))
                  : const Center(child: Text('اكتب وصفاً لتوليد صورة 🎨', style: TextStyle(color: Colors.white54))),
            ),
          ],
        ),
      ),
    );
  }
}
