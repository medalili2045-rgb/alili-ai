import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String workerUrl = 'https://alili-omni.medalili2045.workers.dev';

  static Future<String> chat(String message, List<Map<String, String>> history, bool search, bool thinking) async {
    try {
      final res = await http.post(Uri.parse(workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'chat', 'message': message, 'history': history, 'search': search, 'thinking': thinking}))
        .timeout(const Duration(seconds: 60));
      
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['reply'] ?? data['error'] ?? 'خطأ غير معروف';
    } catch (e) {
      return 'فشل الاتصال بالخادم. تأكد من الإنترنت.';
    }
  }
}
