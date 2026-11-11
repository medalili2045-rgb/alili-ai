import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'providers.dart';

class ApiService {
  static const String workerUrl = 'https://alili-omni.medalili2045.workers.dev';

  static Stream<String> chatStream(String message, List<Map<String, String>> history, List<String> memory, Uint8List? img, AppSettings s) async* {
    final req = http.Request('POST', Uri.parse(workerUrl));
    req.headers['Content-Type'] = 'application/json';
    req.body = jsonEncode({
      'type': 'chat_stream', 'message': message, 'history': history,
      'userMemory': memory, 'imageBase64': img != null ? base64Encode(img) : null,
      'model': s.model, 'systemPrompt': s.systemPrompt, 'temperature': s.temperature,
      'search': s.useSearch, 'thinking': s.useThinking,
    });
    final resp = await http.Client().send(req);
    if (resp.statusCode != 200) { yield jsonEncode({'type': 'text', 'text': 'خطأ في الخادم (${resp.statusCode})'}); return; }
    await for (final chunk in resp.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          final d = line.substring(6).trim();
          if (d.isEmpty || d == '[DONE]') continue;
          yield d;
        }
      }
    }
  }
}
