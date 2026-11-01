import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const ProviderScope(child: AliliApp()));

class AliliApp extends StatelessWidget {
  const AliliApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, brightness: Brightness.dark,
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
  int _index = 0;
  final _screens = [const ChatScreen(), const ImageScreen(), const VideoScreen(), const GameScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF141414),
        indicatorColor: const Color(0xFF00E5FF).withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'الدردشة'),
          NavigationDestination(icon: Icon(Icons.image_outlined), label: 'الصور'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'الفيديو'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), label: 'الألعاب'),
        ],
      ),
    );
  }
}

// ==================== 1. الدردشة ====================
class ChatMessage { final String text; final bool isUser; ChatMessage(this.text, this.isUser); }
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([ChatMessage('أهلاً بك! أنا Alili Omni v4.0.', false)]);
  Future<void> send(String text, bool search, bool thinking) async {
    state = [...state, ChatMessage(text, true)];
    final history = state.sublist(0, state.length - 1).map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}).toList();
    try {
      final res = await http.post(Uri.parse('https://alili-omni.medalili2045.workers.dev'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'chat', 'message': text, 'history': history, 'search': search, 'thinking': thinking}));
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      state = [...state, ChatMessage(data['reply'] ?? data['error'] ?? 'خطأ', false)];
    } catch (e) { state = [...state, ChatMessage('فشل: $e', false)]; }
  }
}
final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) => ChatNotifier());

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _c = TextEditingController();
  bool _search = false, _thinking = false;
  
  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Alili Omni'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Column(children: [
        Expanded(child: ListView.builder(itemCount: msgs.length, itemBuilder: (c, i) {
          final m = msgs[i];
          return Align(alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: m.isUser ? const Color(0xFF1E1E24) : const Color(0xFF141414), borderRadius: BorderRadius.circular(16)),
              child: m.isUser ? Text(m.text) : MarkdownBody(data: m.text, styleSheet: MarkdownStyleSheet(p: const TextStyle(color: Colors.white70)))));
        })),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _toggle(Icons.search, 'بحث', _search, () => setState(() => _search = !_search)),
          const SizedBox(width: 10),
          _toggle(Icons.psychology, 'تفكير', _thinking, () => setState(() => _thinking = !_thinking)),
        ]),
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(controller: _c, decoration: const InputDecoration(hintText: 'اكتب...'), onSubmitted: (_) { ref.read(chatProvider.notifier).send(_c.text, _search, _thinking); _c.clear(); })),
          IconButton(icon: const Icon(Icons.send, color: Color(0xFF00E5FF)), onPressed: () { ref.read(chatProvider.notifier).send(_c.text, _search, _thinking); _c.clear(); }),
        ])),
      ]),
    );
  }
  Widget _toggle(IconData icon, String label, bool active, VoidCallback onTap) => InkWell(onTap: onTap, child: Chip(avatar: Icon(icon, size: 16, color: active ? Colors.black : Colors.white), label: Text(label), backgroundColor: active ? const Color(0xFF00E5FF) : const Color(0xFF141414)));
}

// ==================== 2. الصور ====================
class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});
  @override
  State<ImageScreen> createState() => _ImageScreenState();
}
class _ImageScreenState extends State<ImageScreen> {
  final _c = TextEditingController();
  bool _loading = false;
  Uint8List? _img;

  Future<void> _gen() async {
    setState(() { _loading = true; _img = null; });
    try {
      final res = await http.post(Uri.parse('https://alili-omni.medalili2045.workers.dev'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'type': 'image', 'message': _c.text}));
      if (res.headers['content-type']?.contains('image') == true) setState(() => _img = res.bodyBytes);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الصور'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _c, decoration: const InputDecoration(hintText: 'صف الصورة...')),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _gen, child: const Text('توليد')),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : (_img != null ? Image.memory(_img!) : const Center(child: Text('لا صورة')))),
      ])),
    );
  }
}

// ==================== 3. الفيديو ====================
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}
class _VideoScreenState extends State<VideoScreen> {
  final _c = TextEditingController();
  bool _loading = false;
  String _status = '';
  VideoPlayerController? _player;
  Timer? _timer;

  @override
  void dispose() { _timer?.cancel(); _player?.dispose(); _c.dispose(); super.dispose(); }

  Future<void> _create() async {
    setState(() { _loading = true; _status = 'جاري الإرسال...'; });
    try {
      final res = await http.post(Uri.parse('https://alili-omni.medalili2045.workers.dev'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'type': 'video_create', 'message': _c.text}));
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      if (d['request_id'] != null) _poll(d['request_id']);
      else throw Exception(d['error']);
    } catch (e) { setState(() { _loading = false; _status = 'خطأ: $e'; }); }
  }

  void _poll(String id) {
    _timer = Timer.periodic(const Duration(seconds: 5), (t) async {
      try {
        final res = await http.post(Uri.parse('https://alili-omni.medalili2045.workers.dev'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'type': 'video_status', 'request_id': id}));
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d['status'] == 'COMPLETED' && d['video_url'] != null) {
          t.cancel();
          final p = VideoPlayerController.networkUrl(Uri.parse(d['video_url']));
          await p.initialize();
          setState(() { _player = p; _loading = false; _status = 'جاهز'; });
          p.play();
        } else { setState(() => _status = 'الحالة: ${d['status']}'); }
      } catch(e) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفيديو'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _c, decoration: const InputDecoration(hintText: 'صف الفيديو...')),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _create, child: const Text('توليد فيديو')),
        const SizedBox(height: 10),
        Text(_status),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : (_player != null ? AspectRatio(aspectRatio: _player!.value.aspectRatio, child: VideoPlayer(_player!)) : const Center(child: Text('لا فيديو')))),
      ])),
    );
  }
}

// ==================== 4. الألعاب ====================
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}
class _GameScreenState extends State<GameScreen> {
  final _c = TextEditingController();
  bool _loading = false;
  WebViewController? _web;

  Future<void> _gen() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse('https://alili-omni.medalili2045.workers.dev'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'type': 'game', 'message': _c.text}));
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      if (d['html'] != null) setState(() => _web = WebViewController()..loadHtmlString(d['html']));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الألعاب'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _c, decoration: const InputDecoration(hintText: 'صف اللعبة...')),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _gen, child: const Text('توليد لعبة')),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : (_web != null ? WebViewWidget(controller: _web!) : const Center(child: Text('لا لعبة')))),
      ])),
    );
  }
}
