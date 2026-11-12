import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _c = TextEditingController();
  final _sc = ScrollController();
  Uint8List? _img;
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  bool _listening = false;

  @override
  void initState() { super.initState(); _tts.setLanguage("ar-SA"); }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) { final b = await f.readAsBytes(); if (mounted) setState(() => _img = b); }
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'md', 'csv', 'json']);
    if (r != null && r.files.single.path != null) {
      final f = r.files.single;
      final b = await f.readAsBytes();
      final content = String.fromCharCodes(b);
      if (mounted) setState(() => _c.text = "حلل هذا الملف (${f.name}):\n\n${content.substring(0, content.length > 5000 ? 5000 : content.length)}");
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 12), decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          ListTile(leading: Icon(Icons.photo, color: Colors.grey[400]), title: Text('صورة', style: TextStyle(color: Colors.grey[300])), onTap: () { Navigator.pop(c); _pickImage(); }),
          ListTile(leading: Icon(Icons.folder, color: Colors.grey[400]), title: Text('ملف', style: TextStyle(color: Colors.grey[300])), onTap: () { Navigator.pop(c); _pickFile(); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _listen() async {
    if (!_listening) {
      final ok = await _speech.initialize();
      if (ok) { setState(() => _listening = true); _speech.listen(onResult: (v) => setState(() => _c.text = v.recognizedWords), localeId: "ar_SA"); }
    } else { setState(() => _listening = false); _speech.stop(); }
  }

  void _send() {
    if (_c.text.isEmpty && _img == null) return;
    ref.read(chatProvider.notifier).send(_c.text, _img, ref.read(settingsProvider));
    _c.clear();
    setState(() => _img = null);
  }

  void _showSettings() {
    final s = ref.read(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => StatefulBuilder(builder: (context, setSt) => SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الإعدادات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('النموذج', style: TextStyle(color: Colors.grey[400])),
          DropdownButton<String>(
            value: s.model, dropdownColor: const Color(0xFF1A1A1A), isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'glm', child: Text('GLM-5.3', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 'gemini', child: Text('Gemini 3.8', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (v) { n.update(AppSettings(model: v!, systemPrompt: s.systemPrompt, temperature: s.temperature, voiceSpeed: s.voiceSpeed, useSearch: s.useSearch, useThinking: s.useThinking)); setSt((){}); },
          ),
          const SizedBox(height: 12),
          Text('درجة الإبداع', style: TextStyle(color: Colors.grey[400])),
          Slider(value: s.temperature, min: 0, max: 1, activeColor: Colors.grey, onChanged: (v) { n.update(AppSettings(model: s.model, systemPrompt: s.systemPrompt, temperature: v, voiceSpeed: s.voiceSpeed, useSearch: s.useSearch, useThinking: s.useThinking)); setSt((){}); }),
          Text('سرعة الصوت', style: TextStyle(color: Colors.grey[400])),
          Slider(value: s.voiceSpeed, min: 0.1, max: 1, activeColor: Colors.grey, onChanged: (v) { n.update(AppSettings(model: s.model, systemPrompt: s.systemPrompt, temperature: s.temperature, voiceSpeed: v, useSearch: s.useSearch, useThinking: s.useThinking)); setSt((){}); }),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatProvider);
    final isGen = ref.watch(isGeneratingProvider);
    final settings = ref.watch(settingsProvider);
    ref.listen(chatProvider, (_, __) => _scrollDown());

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F), elevation: 0, centerTitle: true,
        title: Text('Alili Omni', style: TextStyle(color: Colors.grey[300], fontSize: 15, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(icon: Icon(Icons.settings, color: Colors.grey[500], size: 20), onPressed: _showSettings),
          IconButton(icon: Icon(Icons.delete_sweep, color: Colors.grey[500], size: 20), onPressed: () => ref.read(chatProvider.notifier).clear()),
        ],
      ),
      body: Column(children: [
        Expanded(child: ListView.builder(
          controller: _sc, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: msgs.length,
          itemBuilder: (c, i) {
            final m = msgs[i];
            if (!m.isUser && m.text.isEmpty && m.imageBase64 == null && m.videoUrl == null) return const SizedBox.shrink();
            return _bubble(m);
          },
        )),

        if (_img != null)
          Container(padding: const EdgeInsets.all(10), color: const Color(0xFF141414),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(_img!, width: 40, height: 40, fit: BoxFit.cover, cacheWidth: 80)),
              const SizedBox(width: 10),
              Text('صورة مرفقة', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close, color: Colors.grey[500], size: 18), onPressed: () => setState(() => _img = null)),
            ])),

        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _circleToggle(Icons.search, settings.useSearch, () {
              ref.read(settingsProvider.notifier).update(AppSettings(model: settings.model, systemPrompt: settings.systemPrompt, temperature: settings.temperature, voiceSpeed: settings.voiceSpeed, useSearch: !settings.useSearch, useThinking: settings.useThinking));
            }),
            const SizedBox(width: 12),
            _circleToggle(Icons.psychology_outlined, settings.useThinking, () {
              ref.read(settingsProvider.notifier).update(AppSettings(model: settings.model, systemPrompt: settings.systemPrompt, temperature: settings.temperature, voiceSpeed: settings.voiceSpeed, useSearch: settings.useSearch, useThinking: !settings.useThinking));
            }),
          ]),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), color: const Color(0xFF0F0F0F),
          child: Row(children: [
            IconButton(icon: Icon(Icons.add, color: Colors.grey[500], size: 22), onPressed: _showAttachmentMenu),
            Expanded(child: Container(
              constraints: const BoxConstraints(maxHeight: 110),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _c, maxLines: 3, minLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(hintText: 'اسأل، ارسم، أو اطلب فيديو...', hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  onSubmitted: (_) => _send(),
                )),
                IconButton(icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Colors.white : Colors.grey[500], size: 20), onPressed: _listen, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                  onTap: isGen ? null : _send,
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(color: isGen ? Colors.grey[800] : Colors.grey[700], shape: BoxShape.circle), child: Icon(isGen ? Icons.stop : Icons.arrow_upward, color: Colors.grey[300], size: 18)),
                )),
              ]),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _circleToggle(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: active ? Colors.grey[700] : Colors.grey[900], shape: BoxShape.circle, border: Border.all(color: active ? Colors.grey[500]! : Colors.grey[850]!, width: 1)),
      child: Icon(icon, color: active ? Colors.white : Colors.grey[500], size: 16),
    ));
  }

  Widget _bubble(ChatMessage m) {
    if (m.isUser) {
      return Align(alignment: Alignment.centerRight, child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (m.imageBase64 != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(m.imageBase64!, fit: BoxFit.cover, cacheWidth: 600)),
          if (m.text.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(18)), child: Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))),
        ]),
      ));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 10, backgroundColor: Colors.grey[800], child: Icon(Icons.spa, size: 12, color: Colors.grey[400])),
          const SizedBox(width: 6),
          Text('Alili', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        if (m.imageBase64 != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(m.imageBase64!, fit: BoxFit.cover, cacheWidth: 600)),
        if (m.imageBase64 != null) const SizedBox(height: 6),
        if (m.videoUrl != null) VideoPlayerWidget(url: m.videoUrl!),
        if (m.videoLoading) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400])), const SizedBox(width: 8), Text('جاري توليد الفيديو...', style: TextStyle(color: Colors.grey[400], fontSize: 12))])),
        if (m.text.isNotEmpty) Padding(padding: EdgeInsets.only(top: (m.imageBase64 != null || m.videoUrl != null) ? 6 : 0), child: MarkdownBody(data: m.text, styleSheet: MarkdownStyleSheet(p: TextStyle(color: Colors.grey[300], fontSize: 14, height: 1.6), code: TextStyle(backgroundColor: const Color(0xFF1A1A1A), color: Colors.grey[300], fontFamily: 'monospace', fontSize: 13)))),
      ]),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});
  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _c;
  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_) => setState(() {}));
  }
  @override
  void dispose() { _c?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_c == null || !_c!.value.isInitialized) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: Colors.grey)));
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: AspectRatio(aspectRatio: _c!.value.aspectRatio, child: VideoPlayer(_c!)));
  }
}
