import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String workerUrl = 'https://alili-omni.medalili2045.workers.dev';

  static Stream<String> chatStream(String message, List<Map<String, String>> history, Uint8List? imageBytes) async* {
    final request = http.Request('POST', Uri.parse(workerUrl));
    request.headers['Content-Type'] = 'application/json';
    
    String? base64Image;
    if (imageBytes != null) base64Image = base64Encode(imageBytes);

    request.body = jsonEncode({
      'type': 'chat_stream',
      'message': message,
      'history': history,
      'imageBase64': base64Image,
      'imageMimeType': imageBytes != null ? 'image/jpeg' : null,
    });

    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      yield "حدث خطأ في الخادم (${response.statusCode})";
      return;
    }

    final stream = response.stream.transform(utf8.decoder);
    await for (final chunk in stream) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr.isEmpty || dataStr == '[DONE]') continue;
          try {
            final data = jsonDecode(dataStr);
            if (data['text'] != null) yield data['text'];
          } catch (e) {}
        }
      }
    }
  }
}
