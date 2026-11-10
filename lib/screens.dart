import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'providers.dart';
import 'services.dart';

// ==================== 1. الدردشة ====================
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _c = TextEditingController();
  final _scrollController = ScrollController();
  bool _search = false, _thinking = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatProvider);
    ref.listen(chatProvider, (prev, next) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alili Omni'), backgroundColor: const Color(0xFF0A0A0A),
        actions: [IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () => ref.read(chatProvider.notifier).clear())],
      ),
      body: Column(children: [
        Expanded(child: ListView.builder(controller: _scrollController, itemCount: msgs.length, itemBuilder: (c, i) {
          final m = msgs[i];
          return Align(alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: m.isUser ? const Color(0xFF1E1E24) : const Color(0xFF141414), borderRadius: BorderRadius.circular(16)),
              child: m.isUser ? Text(m.text, style: const TextStyle(color: Colors.white)) : MarkdownBody(data: m.text, styleSheet: MarkdownStyleSheet(p: const TextStyle(color: Colors.white70)))));
        })),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _toggle(Icons.search, 'بحث', _search, () => setState(() => _search = !_search)),
          const SizedBox(width: 10),
          _toggle(Icons.psychology, 'تفكير', _thinking, () => setState(() => _thinking = !_thinking)),
        ]),
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(controller: _c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'اكتب...', hintStyle: TextStyle(color: Colors.white38)), onSubmitted: (_) => _send())),
          IconButton(icon: const Icon(Icons.send, color: Color(0xFF00E5FF)), onPressed: _send),
        ])),
      ]),
    );
  }

  void _send() {
    if (_c.text.isEmpty) return;
    ref.read(chatProvider.notifier).send(_c.text, _search, _thinking);
    _c.clear();
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
    if (_c.text.isEmpty) return;
    setState(() { _loading = true; _img = null; });
    try {
      final res = await http.post(Uri.parse(ApiService.workerUrl),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'type': 'image', 'message': _c.text})).timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (res.headers['content-type']?.contains('image') == true) {
        setState(() => _img = res.bodyBytes);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل التوليد')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الصور'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'صف الصورة...', hintStyle: TextStyle(color: Colors.white38))),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _gen, child: const Text('توليد')),
        const SizedBox(height: 10),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : (_img != null ? Image.memory(_img!) : const Center(child: Text('لا صورة', style: TextStyle(color: Colors.white54))))),
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
    if (_c.text.isEmpty) return;
    setState(() { _loading = true; _status = 'جاري الإرسال...'; });
    try {
      final res = await http.post(Uri.parse(ApiService.workerUrl),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'type': 'video_create', 'message': _c.text})).timeout(const Duration(seconds: 30));
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      if (d['request_id'] != null) _poll(d['request_id']);
      else throw Exception();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _status = 'خطأ في الاتصال'; });
    }
  }

  void _poll(String id) {
    _timer = Timer.periodic(const Duration(seconds: 5), (t) async {
      try {
        final res = await http.post(Uri.parse(ApiService.workerUrl),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'type': 'video_status', 'request_id': id}));
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (!mounted) return;
        if (d['status'] == 'COMPLETED' && d['video_url'] != null) {
          t.cancel();
          final p = VideoPlayerController.networkUrl(Uri.parse(d['video_url']));
          await p.initialize();
          if (mounted) { setState(() { _player = p; _loading = false; _status = 'جاهز'; }); p.play(); }
        } else { setState(() => _status = 'الحالة: ${d['status']}'); }
      } catch(e) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفيديو'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'صف الفيديو...', hintStyle: TextStyle(color: Colors.white38))),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _create, child: const Text('توليد فيديو')),
        const SizedBox(height: 10),
        Text(_status, style: const TextStyle(color: Colors.white70)),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : (_player != null ? AspectRatio(aspectRatio: _player!.value.aspectRatio, child: VideoPlayer(_player!)) : const Center(child: Text('لا فيديو', style: TextStyle(color: Colors.white54))))),
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
    if (_c.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await http.post(Uri.parse(ApiService.workerUrl),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'type': 'game', 'message': _c.text})).timeout(const Duration(seconds: 60));
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      if (!mounted) return;
      if (d['html'] != null) {
        setState(() {
          _web = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadHtmlString(d['html'], baseUrl: 'https://localhost');
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل توليد اللعبة')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الألعاب'), backgroundColor: const Color(0xFF0A0A0A)),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(controller: _c, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'صف اللعبة...', hintStyle: TextStyle(color: Colors.white38))),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _gen, child: const Text('توليد لعبة')),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : (_web != null ? WebViewWidget(controller: _web!) : const Center(child: Text('لا لعبة', style: TextStyle(color: Colors.white54))))),
      ])),
    );
  }
}
