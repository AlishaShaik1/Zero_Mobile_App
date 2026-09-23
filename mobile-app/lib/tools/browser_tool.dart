import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

/// BrowserTool — opens a URL or search query in the device's default browser.
/// Step 1 (executePromptB): extract URL / search query from the raw user message.
/// Step 2 (executeNative): invoke the 'open_browser' native channel method.
class BrowserTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  BrowserTool() : super('browser');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    final lower = userMessage.toLowerCase();

    // Fast-path: already contains a full URL
    final urlMatch = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    ).firstMatch(userMessage);
    if (urlMatch != null) return urlMatch.group(0)!;

    // Fast-path: looks like a domain (e.g. "open youtube.com")
    final domainMatch = RegExp(
      r'\b([a-z0-9-]+\.(com|org|net|io|co|in|uk|gov|edu))\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (domainMatch != null) return 'https://${domainMatch.group(1)}';

    // Common site names → URLs
    const siteMap = {
      'youtube': 'https://youtube.com',
      'google': 'https://google.com',
      'twitter': 'https://twitter.com',
      'instagram': 'https://instagram.com',
      'facebook': 'https://facebook.com',
      'whatsapp': 'https://web.whatsapp.com',
      'amazon': 'https://amazon.in',
      'flipkart': 'https://flipkart.com',
      'gmail': 'https://mail.google.com',
      'linkedin': 'https://linkedin.com',
      'reddit': 'https://reddit.com',
      'netflix': 'https://netflix.com',
      'wikipedia': 'https://wikipedia.org',
      'maps': 'https://maps.google.com',
    };
    for (final entry in siteMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    // Fallback: use the raw message as a Google search query
    final query = Uri.encodeQueryComponent(userMessage.trim());
    return 'https://www.google.com/search?q=$query';
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    String url = promptBOutput.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    try {
      await _channel.invokeMethod('open_browser', {'url': url});
      return 'success:$url';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final url = executionResult.substring(8);
      return '🌐 Opened browser: $url';
    }
    return 'Could not open the browser.';
  }
}
