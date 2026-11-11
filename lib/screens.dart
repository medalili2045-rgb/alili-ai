import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _c = TextEditingController();
  final _scrollController = ScrollController();
  Uint8List? _selectedImage;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (mounted) {
        setState(() => _selectedImage = bytes);
      }
    }
  }

  void _send() {
    if (_c.text.isEmpty && _selectedImage == null) return;
    ref.read(chatProvider.notifier).send(_c.text, _selectedImage);
    _c.clear();
    setState(() => _selectedImage = null);
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatProvider);
    ref.listen(chatProvider, (prev, next) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const CircleAvatar(backgroundColor: Color(0xFF00E5FF), radius: 14, child: Icon(Icons.bolt, size: 18, color: Colors.black)),
          const SizedBox(width: 8),
          const Text('Alili Omni', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent), onPressed: () => ref.read(chatProvider.notifier).clear())],
      ),
      body: Column(children: [
        Expanded(child: ListView.builder(
          controller: _scrollController, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: msgs.length, itemBuilder: (c, i) {
            final m = msgs[i];
            if (!m.isUser && m.text.isEmpty) return _buildTypingIndicator();
            return _buildMessageBubble(m);
          }
        )),
        
        if (_selectedImage != null)
          Container(
            padding: const EdgeInsets.all(8), color: const Color(0xFF141414),
            child: Row(children: [
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_selectedImage!, width: 60, height: 60, fit: BoxFit.cover)),
                Positioned(top: 0, right: 0, child: GestureDetector(onTap: () => setState(() => _selectedImage = null), child: Container(color: Colors.black54, child: const Icon(Icons.close, color: Colors.white, size: 18)))),
              ]),
              const SizedBox(width: 10),
              const Text('صورة جاهزة للإرسال...', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),

        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16), decoration: const BoxDecoration(color: Color(0xFF0A0A0A)),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00E5FF), size: 28), onPressed: _pickImage),
            Expanded(child: Container(
              decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: TextField(
                controller: _c, style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(hintText: 'اسأل أو أرفق صورة...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                onSubmitted: (_) => _send()
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(onTap: _send, child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle), child: const Icon(Icons.arrow_upward, color: Colors.black, size: 24))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMessageBubble(ChatMessage m) {
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Column(crossAxisAlignment: m.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: m.isUser ? const Color(0xFF1E1E24) : const Color(0xFF141414),
              borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(m.isUser ? 20 : 4), bottomRight: Radius.circular(m.isUser ? 4 : 20)),
              border: m.isUser ? null : Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.imageBytes != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(m.imageBytes!, width: double.infinity, fit: BoxFit.cover)),
              if (m.imageBytes != null) const SizedBox(height: 8),
              if (m.text.isNotEmpty) m.isUser ? Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)) : MarkdownBody(data: m.text, styleSheet: MarkdownStyleSheet(p: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6), code: const TextStyle(backgroundColor: Colors.black45, color: Color(0xFF00E5FF)))),
            ]),
          ),
          if (!m.isUser && m.text.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: InkWell(onTap: () { Clipboard.setData(ClipboardData(text: m.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ!'), duration: Duration(seconds: 1))); }, child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.copy, size: 14, color: Colors.white38), SizedBox(width: 4), Text('نسخ', style: TextStyle(color: Colors.white38, fontSize: 12))]))),
        ]),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(), _dot(), _dot()]),
      ),
    );
  }

  Widget _dot() => Container(margin: const EdgeInsets.symmetric(horizontal: 3), width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle));
}
