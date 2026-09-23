import 'dart:convert';
import 'package:http/http.dart' as http;

class PublishService {
  // ── Replace with your actual Cloudflare Worker URL ──────────────────────
  static const String _proxyUrl =
      "https://zero-air-proxy.founderzero1.workers.dev";
  static const String _clientSecret = "type_any_random_password_here_123!";
  // ────────────────────────────────────────────────────────────────────────

  Future<String> publish({
    required String html,
    required String type,
    String? requestedSlug,
  }) async {
    final response = await http
        .post(
          Uri.parse("$_proxyUrl/publish"),
          headers: {
            "Content-Type": "application/json",
            "X-Zero-Air-Secret": _clientSecret,
          },
          body: jsonEncode({
            "html": html,
            "type": type,
            "requestedSlug": requestedSlug,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      String errorMessage = "Publish failed (${response.statusCode})";
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['detail'] != null) {
          errorMessage += ": ${errorData['detail']}";
        } else if (errorData['error'] != null) {
          errorMessage += ": ${errorData['error']}";
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }

    final data = jsonDecode(response.body);
    return data["url"] as String;
  }
}
