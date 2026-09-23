// ignore_for_file: prefer_const_constructors
// model_service.dart — Fireworks GLM-5P3-Flash (Cloud API, zero local model needed)
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:llamadart/llamadart.dart';
import '../utils/json_corrector.dart';

// tool_dispatcher.dart and search_service.dart not used directly in model_service

enum ModelProfile { textFast, vision, none }

enum DeviceTier { budget, mid, flagship }

Future<int> _detectTotalRamMb() async {
  try {
    final meminfo = File('/proc/meminfo');
    if (!await meminfo.exists()) return 0;
    for (final line in await meminfo.readAsLines()) {
      if (line.startsWith('MemTotal:')) {
        final kb = int.tryParse(
          RegExp(r'\d+').firstMatch(line)?.group(0) ?? '',
        );
        if (kb != null) return kb ~/ 1024;
      }
    }
  } catch (_) {}
  return 0;
}

Future<DeviceTier> _classifyDevice() async {
  final ramMb = await _detectTotalRamMb();
  if (ramMb == 0) return DeviceTier.budget; // unknown RAM -> safest path
  if (ramMb < 3500) return DeviceTier.budget;
  if (ramMb <= 6500) return DeviceTier.mid;
  return DeviceTier.flagship;
}

Future<File> _gpuAttemptMarkerFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/.gpu_attempt_marker');
}

Future<int> detectPerformanceCoreCount() async {
  try {
    final cpuDirs = Directory('/sys/devices/system/cpu')
        .listSync()
        .whereType<Directory>()
        .where((d) => RegExp(r'cpu\d+$').hasMatch(d.path.split('/').last));

    final freqs = <int, int>{};
    for (final dir in cpuDirs) {
      final coreIndex = int.tryParse(
        RegExp(r'cpu(\d+)$').firstMatch(dir.path)!.group(1)!,
      );
      final freqFile = File('${dir.path}/cpufreq/cpuinfo_max_freq');
      if (coreIndex != null && await freqFile.exists()) {
        final freq = int.tryParse((await freqFile.readAsString()).trim());
        if (freq != null) freqs[coreIndex] = freq;
      }
    }

    if (freqs.isEmpty) return _fallbackThreadCount();

    final topFreq = freqs.values.reduce((a, b) => a > b ? a : b);
    final threshold = (topFreq * 0.8).round();
    final perfCoreCount = freqs.values.where((f) => f >= threshold).length;

    return perfCoreCount.clamp(2, 6);
  } catch (e) {
    return _fallbackThreadCount();
  }
}

int _fallbackThreadCount() {
  final total = Platform.numberOfProcessors;
  return (total / 2).round().clamp(2, 6);
}

sealed class ChatDelta {
  const ChatDelta();
}

class ThinkingDelta extends ChatDelta {
  final String text;
  const ThinkingDelta(this.text);
}

class ContentDelta extends ChatDelta {
  final String text;
  const ContentDelta(this.text);
}

class RouteSearchDelta extends ChatDelta {
  const RouteSearchDelta();
}

class RouteAgentDelta extends ChatDelta {
  const RouteAgentDelta();
}

class ThinkingProfile {
  final int thinkingCap; // hard cap on reasoning tokens
  final int contentReserve; // tokens GUARANTEED left over for the actual reply
  const ThinkingProfile({
    required this.thinkingCap,
    required this.contentReserve,
  });
  int get totalMaxTokens => thinkingCap + contentReserve;
}

class ModelService {
  static final ModelService _instance = ModelService._internal();

  factory ModelService() {
    return _instance;
  }

  ModelService._internal();

  /// Common stop-sequences for all inference calls.
  static final List<String> kStops = ['<|im_end|>', '<|endoftext|>', '</s>'];

  static const String mtpModelUrl =
      'https://huggingface.co/24A31A42A4/Titan-Small/resolve/main/Qwen3.5-0.8B.Q5_K_M.gguf';
  static const String mtpModelName = 'Qwen3.5-0.8B.Q5_K_M.gguf';

  /// 500 MB floor — Titan-Small / Qwen3.5-0.8B Q5_K_M is ~580 MB
  static const int minModelBytes = 500 * 1024 * 1024;
  static const String prefsMemoryKey = 'chat_memory_v3';
  static const String _prefsModelUrlKey = 'last_downloaded_model_url_v1';

  ModelProfile _activeProfile = ModelProfile.none;
  ModelProfile get activeProfile => _activeProfile;
  bool _usingGpuBackend = false;

  File? _mtpModelFile;

  bool _isMmprojReady = false;
  bool get isMmprojReady => _isMmprojReady;

  late LlamaEngine _engine;
  LlamaEngine get engine => _engine; // Exposed for direct string-based routing

  final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 KHTML, like Gecko Chrome/120.0.0.0 Safari/537.36',
      },
    ),
  );

  bool _isReady = true; // Always ready — Fireworks GLM needs no local model
  bool get isReady => true; // Exposed for caller safety checks

  // ── Fireworks GLM-5P3-Flash ──────────────────────────────────────────────────
  static const _kFwKey = 'fw_3iUKfhBn2vryacJynHPsUU';
  static const _kFwModel = 'accounts/fireworks/models/glm-5p3-flash';
  static const _kFwUrl = 'https://api.fireworks.ai/inference/v1/chat/completions';

  /// Call Fireworks non-streaming. Returns content string.
  Future<String> _fireworks(String sys, String user, {int maxTokens = 700, double temp = 0.7}) async {
    try {
      final body = jsonEncode({
        'model': _kFwModel,
        'max_tokens': maxTokens,
        'top_k': 40,
        'temperature': temp,
        'messages': [
          {'role': 'system', 'content': sys},
          {'role': 'user', 'content': user},
        ],
      });
      final res = await http.post(
        Uri.parse(_kFwUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_kFwKey',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return (decoded['choices']?[0]?['message']?['content'] as String?)?.trim() ?? '';
      }
      debugPrint('[ModelService/Fireworks] HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('[ModelService/Fireworks] error: $e');
    }
    return '';
  }

  bool _isGenerating = false;
  DateTime? _genStartTime;
  bool get isGenerating => _isGenerating;

  // ── Cached thinking prefs — loaded once, avoids SharedPrefs I/O per chat turn
  // Thinking prefs read directly per-call via _getThinkingProfile() / _isThinkingEnabled()

  Future<bool> acquireLock() async {
    if (_isGenerating && _genStartTime != null) {
      final elapsed = DateTime.now().difference(_genStartTime!);
      if (elapsed.inSeconds > 30) {
        debugPrint(
          '[ModelService] Force-cancelling stale generation (${elapsed.inSeconds}s)',
        );
        forceReleaseLock();
      }
    }

    int waited = 0;
    while (_isGenerating && waited < 3000) {
      await Future.delayed(
        const Duration(milliseconds: 10),
      ); // poll every 10ms, max 30 seconds total
      waited++;
    }

    if (_isGenerating) {
      debugPrint('[ModelService] Lock timeout (30s) — force cancelling previous generation');
      forceReleaseLock();
    }

    _isGenerating = true;
    _genStartTime = DateTime.now();

    try {
      const channel = MethodChannel('com.example.zero_air/tools');
      await channel.invokeMethod('force_performance_mode');
    } catch (_) {}

    _cancelRequested = false;

    return true;
  }

  void releaseLock() {
    _isGenerating = false;
    _genStartTime = null;
  }

  void forceReleaseLock() {
    try {
      _engine.cancelGeneration();
    } catch (_) {}
    _isGenerating = false;
    _genStartTime = null;
  }

  // ignore: unused_field
  bool _cancelRequested = false; // set by cancelGeneration(), checked by LLM loop

  void cancelGeneration() {
    _cancelRequested = true;
    forceReleaseLock();
    debugPrint('[ModelService] Generation cancelled.');
  }

  Function(int downloaded, int total)? onDownloadProgress;
  Function(String status)? onStatusUpdate;

  // ignore: unused_element
  Future<ThinkingProfile?> _getThinkingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('thinkmode_enabled') ?? false;
    if (!enabled) return null;
    final effort = prefs.getString('thinkmode_effort') ?? 'Low';
    return effort == 'Max'
        ? const ThinkingProfile(thinkingCap: 480, contentReserve: 420)
        : const ThinkingProfile(thinkingCap: 220, contentReserve: 300);
  }

  // ignore: unused_element
  Future<bool> _isThinkingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('thinkmode_enabled') ?? false;
  }

  /// Clear, concise system instructions for Zero Voice Assistant & Thinking Mode
  static const String _kStaticSysPrompt =
      'You are Zero, a fast, highly intelligent voice AI assistant designed for the Zero Smart Ring. '
      'Think clearly and provide direct, helpful, concise, and accurate responses. Keep answers conversational.';

  // _buildSystemPrompt / _buildDynamicContext removed — static prompt used directly

  final List<LlamaChatMessage> _history = [];

  Future<String?> _readGgufArchitecture(String path) async {
    try {
      final raf = await File(path).open(mode: FileMode.read);
      final header = await raf.read(16);
      if (header.length < 4 ||
          header[0] != 0x47 ||
          header[1] != 0x47 ||
          header[2] != 0x55 ||
          header[3] != 0x46) {
        await raf.close();
        throw const GgufCheckException(
          'Not a valid GGUF file — magic bytes mismatch.',
        );
      }
      final remaining = await raf.read(256 * 1024);
      await raf.close();
      final keyBytes = utf8.encode('general.architecture');
      for (int i = 0; i < remaining.length - keyBytes.length - 8; i++) {
        bool match = true;
        for (int j = 0; j < keyBytes.length; j++) {
          if (remaining[i + j] != keyBytes[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          final valStart = i + keyBytes.length + 12;
          if (valStart + 32 < remaining.length) {
            final sb = StringBuffer();
            for (
              int k = valStart;
              k < valStart + 64 && k < remaining.length;
              k++
            ) {
              final c = remaining[k];
              if (c >= 32 && c < 127) {
                sb.writeCharCode(c);
              } else {
                break;
              }
            }
            final arch = sb.toString().trim();
            if (arch.isNotEmpty) {
              debugPrint('[ModelService] GGUF arch: $arch');
              return arch;
            }
          }
        }
      }
      return null;
    } catch (e) {
      if (e is GgufCheckException) {
        rethrow;
      }
      debugPrint('[ModelService] Preflight error: $e');
      return null;
    }
  }

  // ignore: unused_element
  Future<void> _ensureModelDownloaded(
    File file,
    String url,
    int minBytes,
  ) async {
    // ── URL fingerprint guard: if the target URL changed, delete stale file ──
    final prefs = await SharedPreferences.getInstance();
    final lastUrl = prefs.getString(_prefsModelUrlKey) ?? '';
    if (lastUrl != url && await file.exists()) {
      debugPrint('[ModelService] URL changed — deleting stale model.');
      try { await file.delete(); } catch (_) {}
      final part = File('${file.path}.part');
      if (await part.exists()) try { await part.delete(); } catch (_) {}
    }

    bool valid = await file.exists() && await file.length() >= minBytes;
    if (valid) {
      try {
        final arch = await _readGgufArchitecture(file.path);
        if (arch == null || arch.isEmpty) {
          valid = false;
        }
      } catch (_) {
        valid = false;
      }
    }
    if (!valid) {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      onStatusUpdate?.call(
        'downloading ${file.path.split(Platform.pathSeparator).last}',
      );
      await _downloadWithResume(url, file);
      // Store fingerprint only after a confirmed successful download
      await prefs.setString(_prefsModelUrlKey, url);
    }
  }

  Future<void> _loadTextFastProfile() async {
    if (_activeProfile == ModelProfile.textFast) return;
    onStatusUpdate?.call('loading fast profile');

    final perfThreads = await detectPerformanceCoreCount();

    // Dispose only if already initialized (avoid calling dispose on uninitialized engine)
    if (_activeProfile != ModelProfile.none) {
      try {
        await _engine.dispose();
      } catch (_) {}
    }
    _engine = LlamaEngine(LlamaBackend());

    final prefs = await SharedPreferences.getInstance();
    final gpuDisabledPermanently =
        prefs.getBool('gpu_offload_disabled') ?? false;

    final diagThreads = prefs.getInt('model_nThreads') ?? perfThreads;
    final diagMmap = prefs.getBool('model_useMmap') ?? true;
    final diagGpuLayers = prefs.getInt('model_nGpuLayers');
    final tier = await _classifyDevice();
    final marker = await _gpuAttemptMarkerFile();

    // A marker surviving into this launch means the last GPU load attempt
    // never completed -- almost certainly a native crash, not a Dart exception.
    if (await marker.exists()) {
      debugPrint(
        '[ModelService] Prior GPU load did not complete cleanly — disabling GPU permanently.',
      );
      await prefs.setBool('gpu_offload_disabled', true);
      await marker.delete();
    }

    final attemptGpu =
        !gpuDisabledPermanently &&
        tier != DeviceTier.budget &&
        !(await marker.exists());

    if (attemptGpu) {
      await marker.writeAsString(DateTime.now().toIso8601String());
    }

    Future<void> loadWith(int layers) => _engine.loadModel(
      _mtpModelFile!.path,
      modelParams: ModelParams(
        contextSize: 2048, // Generous context size
        gpuLayers: diagGpuLayers ?? layers,
        numberOfThreads: diagThreads,
        batchSize: 512,
        microBatchSize: 256,
        cacheTypeK: KvCacheType.f16, // F16 prevents garbage character drift
        cacheTypeV: KvCacheType.f16, // F16 prevents garbage character drift
        flashAttention: FlashAttention.disabled,
        useMmap: diagMmap,
        useMlock: false,
        speculativeRollbackTokenMax: 0,
      ),
    );

    try {
      await loadWith(attemptGpu ? 99 : 0); // 99 = offload all available layers
      _usingGpuBackend =
          attemptGpu && ((await _engine.getResolvedGpuLayers()) ?? 0) > 0;
    } catch (e) {
      if (e is NoSuchMethodError) {
        _usingGpuBackend =
            attemptGpu; // getResolvedGpuLayers missing in 0.8.16, trust attemptGpu
      } else {
        debugPrint('[ModelService] GPU load failed, falling back to CPU: $e');
        await prefs.setBool('gpu_offload_disabled', true);
        _usingGpuBackend = false;
        _engine = LlamaEngine(LlamaBackend());
        await loadWith(0);
      }
    }

    if (attemptGpu) {
      await marker
          .delete(); // reached here without crashing -> clear breadcrumb
    }

    _isMmprojReady = false;

    _activeProfile = ModelProfile.textFast;
    debugPrint(
      '[ModelService] Text-fast profile active. threads=$perfThreads, gpu=$_usingGpuBackend',
    );

    await _raceConfigsOnceIfNeeded(perfThreads);
  }

  Future<void> _raceConfigsOnceIfNeeded(int perfThreads) async {
    final prefs = await SharedPreferences.getInstance();
    const raceKey = 'gpu_race_done_v1';
    if (prefs.getBool(raceKey) ?? false) return;
    if (!_usingGpuBackend) {
      await prefs.setBool(raceKey, true);
      return;
    }

    const testPrompt = 'Explain how photosynthesis works in three sentences.';

    Future<double> tokensPerSecond({required bool useMtp}) async {
      final sw = Stopwatch()..start();
      int count = 0;
      await for (final _ in _engine.generate(
        testPrompt,
        params: GenerationParams(
          maxTokens: 24,
          temp: 0.6,
          speculativeDecodingConfig: null,
        ),
      )) {
        count++;
      }
      sw.stop();
      return count / (sw.elapsedMilliseconds / 1000);
    }

    // Currently loaded as GPU/no-MTP -- measure it first.
    final gpuTps = await tokensPerSecond(useMtp: false);

    // Reload CPU+MTP to measure the alternative.
    await _engine.dispose();
    _engine = LlamaEngine(LlamaBackend());
    final diagThreads = prefs.getInt('model_nThreads') ?? perfThreads;
    final diagMmap = prefs.getBool('model_useMmap') ?? true;

    await _engine.loadModel(
      _mtpModelFile!.path,
      modelParams: ModelParams(
        contextSize: 2048,
        gpuLayers: 0,
        numberOfThreads: diagThreads,
        batchSize: 512,
        microBatchSize: 256,
        cacheTypeK: KvCacheType.f16,
        cacheTypeV: KvCacheType.f16,
        flashAttention: FlashAttention.disabled,
        useMmap: diagMmap,
        useMlock: false,
        speculativeRollbackTokenMax: 0,
      ),
    );
    final cpuMtpTps = await tokensPerSecond(useMtp: true);

    debugPrint(
      '[ModelService] Race result — GPU/noMTP: ${gpuTps.toStringAsFixed(1)} tok/s, CPU/MTP: ${cpuMtpTps.toStringAsFixed(1)} tok/s',
    );

    if (cpuMtpTps >= gpuTps) {
      // CPU+MTP wins or ties -- stay on it (already loaded), disable GPU going forward.
      await prefs.setBool('gpu_offload_disabled', true);
      _usingGpuBackend = false;
    } else {
      // GPU wins -- reload GPU config, since we're currently sitting on CPU from the test above.
      await _engine.dispose();
      _engine = LlamaEngine(LlamaBackend());
      await _engine.loadModel(
        _mtpModelFile!.path,
        modelParams: ModelParams(
          contextSize: 2048,
          gpuLayers: prefs.getInt('model_nGpuLayers') ?? 99,
          numberOfThreads: diagThreads,
          batchSize: 512,
          microBatchSize: 256,
          cacheTypeK: KvCacheType.f16,
          cacheTypeV: KvCacheType.f16,
          flashAttention: FlashAttention.disabled,
          useMmap: diagMmap,
          useMlock: false,
          speculativeRollbackTokenMax: 0,
        ),
      );
      _usingGpuBackend = true;
    }
    await prefs.setBool(raceKey, true);
  }

  Future<void> _ensureTextFastProfile() async {
    if (_activeProfile != ModelProfile.textFast) await _loadTextFastProfile();
  }

  Future<void> initialize() async {
    // Model download paused per user request — Fireworks GLM-5P3-Flash handles all inference
    _isReady = true;
    onStatusUpdate?.call('ready');
    debugPrint('[ModelService] Ready.');
  }

  // _refreshSystemPrompt removed — thinking prefs read fresh each call via _getThinkingProfile()

  void addAssistantMessageToHistory(String text) {
    if (text.trim().isEmpty) return;
    _history.add(
      LlamaChatMessage.fromText(role: LlamaChatRole.assistant, text: text),
    );
    if (_history.length > 5) {
      _history.removeRange(1, _history.length - 4);
    }
  }

  void commitPartialResponse(String text) {
    if (text.trim().isEmpty) return;
    final partialText = '${text.trim()} ... [interrupted]';
    _history.add(
      LlamaChatMessage.fromText(
        role: LlamaChatRole.assistant,
        text: partialText,
      ),
    );
    if (_history.length > 5) {
      _history.removeRange(1, _history.length - 4);
    }
    debugPrint('[ModelService] Saved partial context: $partialText');
  }

  Stream<ChatDelta> chatWithImage(String userMessage, String imagePath) async* {
    try {
      // Read image as base64 for Fireworks multimodal
      String? base64Image;
      String? mimeType;
      try {
        final bytes = await File(imagePath).readAsBytes();
        base64Image = base64Encode(bytes);
        final ext = imagePath.toLowerCase();
        mimeType = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';
      } catch (e) {
        debugPrint('[chatWithImage] Image read error: $e');
      }

      final List<Map<String, dynamic>> messageContent;
      if (base64Image != null) {
        messageContent = [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
              },
              {'type': 'text', 'text': userMessage},
            ],
          },
        ];
      } else {
        messageContent = [
          {'role': 'user', 'content': userMessage},
        ];
      }

      final body = jsonEncode({
        'model': _kFwModel,
        'max_tokens': 700,
        'top_k': 40,
        'temperature': 0.7,
        'messages': [
          {'role': 'system', 'content': _kStaticSysPrompt},
          ...messageContent,
        ],
      });

      final res = await http.post(
        Uri.parse(_kFwUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_kFwKey',
        },
        body: body,
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final content = (decoded['choices']?[0]?['message']?['content'] as String?)?.trim() ?? '';
        if (content.isNotEmpty) yield ContentDelta(content);
      } else {
        yield const ContentDelta('Could not analyze image right now.');
      }
    } catch (e) {
      debugPrint('[chatWithImage] error: $e');
      yield const ContentDelta('Image analysis unavailable.');
    }
  }

  /// Single-pass chat: ONE LLM call. If model emits a <tool> tag the tokens
  /// are buffered (not yielded); after the stream ends we execute the tool
  /// and do a short synthesis pass to present the result naturally.
  /// The lock is acquired ONCE and released after the whole thing.
  Stream<ChatDelta> chat(String userMessage, {String? toolContext}) async* {
    // ── Fireworks GLM streaming chat ───────────────────────────────────────
    try {
      final body = jsonEncode({
        'model': _kFwModel,
        'max_tokens': 800,
        'top_k': 40,
        'temperature': 0.7,
        'stream': true,
        'messages': [
          {'role': 'system', 'content': _kStaticSysPrompt},
          {'role': 'user', 'content': userMessage},
        ],
      });

      final request = http.Request('POST', Uri.parse(_kFwUrl));
      request.headers.addAll({
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_kFwKey',
      });
      request.body = body;

      final client = http.Client();
      try {
        final streamedResponse = await client.send(request).timeout(const Duration(seconds: 20));
        final lines = streamedResponse.stream
            .transform(const Utf8Decoder())
            .transform(const LineSplitter());
        await for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final j = jsonDecode(data) as Map<String, dynamic>;
            final content = j['choices']?[0]?['delta']?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield ContentDelta(content);
            }
          } catch (_) {}
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[ModelService.chat] Fireworks error: $e');
      yield const ContentDelta('Zero is ready. How can I help?');
    }
  }

  Future<String> generateOneShot(
    String systemPrompt,
    String userPrompt, {
    int maxTokens = 200,
    double temperature = 0.10,
    String? gbnfGrammar,  // ignored for Fireworks API
  }) async {
    // Route through Fireworks GLM — no local model needed
    return _fireworks(systemPrompt, userPrompt, maxTokens: maxTokens, temp: temperature);
  }


  Stream<String> generateStream(String userPrompt) async* {
    // Route through Fireworks GLM streaming
    try {
      final body = jsonEncode({
        'model': _kFwModel,
        'max_tokens': 700,
        'top_k': 40,
        'temperature': 0.6,
        'stream': true,
        'messages': [
          {'role': 'system', 'content': 'You are Zero. Be brief and conversational. No markdown.'},
          {'role': 'user', 'content': userPrompt},
        ],
      });
      final request = http.Request('POST', Uri.parse(_kFwUrl));
      request.headers.addAll({
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_kFwKey',
      });
      request.body = body;
      final client = http.Client();
      try {
        final sr = await client.send(request).timeout(const Duration(seconds: 20));
        final lines = sr.stream.transform(const Utf8Decoder()).transform(const LineSplitter());
        await for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final j = jsonDecode(data) as Map<String, dynamic>;
            final c = j['choices']?[0]?['delta']?['content'] as String?;
            if (c != null && c.isNotEmpty) yield c;
          } catch (_) {}
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[ModelService.generateStream] $e');
      yield "I'm ready. How can I help?";
    }
  }

  Stream<String> generateResearchStream(
    String sysPrompt,
    String userContext, {
    int maxTokens = 1000,
  }) async* {
    // Route through Fireworks GLM
    try {
      final body = jsonEncode({
        'model': _kFwModel,
        'max_tokens': maxTokens,
        'top_k': 20,
        'temperature': 0.3,
        'stream': true,
        'messages': [
          {'role': 'system', 'content': sysPrompt},
          {'role': 'user', 'content': userContext},
        ],
      });
      final request = http.Request('POST', Uri.parse(_kFwUrl));
      request.headers.addAll({
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_kFwKey',
      });
      request.body = body;
      final client = http.Client();
      try {
        final sr = await client.send(request).timeout(const Duration(seconds: 45));
        final lines = sr.stream.transform(const Utf8Decoder()).transform(const LineSplitter());
        await for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final j = jsonDecode(data) as Map<String, dynamic>;
            final c = j['choices']?[0]?['delta']?['content'] as String?;
            if (c != null && c.isNotEmpty) yield c;
          } catch (_) {}
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[ModelService.generateResearchStream] $e');
      yield 'Research unavailable right now.';
    }
  }

  ///   MEMORY_RECALL=<question>
  ///   DATETIME=time|date|both
  ///   CHAT
  Future<String> classifyIntent(String userMessage, {String? hint}) async {
    const sysPrompt =
        'You are an intent classifier. Output EXACTLY ONE token from the list below. /no_think\n\n'
        'SEARCH=<query>        \u2192 live/current info: news, real people/events, prices, weather, sports scores,'
        ' or anything that may have changed recently or you are not 100% certain of\n'
        'MEMORY_SAVE=<note>    \u2192 user explicitly asks you to remember/save/note something, or casually shares'
        ' personal info about themselves (name, birthday, location, job, preference)\n'
        'MEMORY_RECALL=<q>     \u2192 user asks what you remember, references something they told you before, or asks'
        " 'do you know my...' / 'what did I tell you'\n"
        'DATETIME=time         \u2192 user asks what the current time is\n'
        'DATETIME=date         \u2192 user asks what day or date it is\n'
        'DATETIME=both         \u2192 user asks for both time and date\n'
        'CHAT                  \u2192 greetings, opinions, coding help, math, jokes, general knowledge, or a tool'
        ' word used casually (not as a real request)\n\n'
        'Examples:\n'
        '"who won the game last night" \u2192 SEARCH=who won the game last night\n'
        '"is it going to rain today" \u2192 SEARCH=weather today\n'
        '"I love searching for antiques at flea markets" \u2192 CHAT\n'
        '"remember that my dog is named Max" \u2192 MEMORY_SAVE=user\'s dog is named Max\n'
        '"my birthday is march 3rd, just fyi" \u2192 MEMORY_SAVE=user\'s birthday is March 3rd\n'
        '"do you remember my dog\'s name?" \u2192 MEMORY_RECALL=user\'s dog\'s name\n'
        '"you know where I work right" \u2192 MEMORY_RECALL=where the user works\n'
        '"what time is it" \u2192 DATETIME=time\n'
        '"what\'s today\'s date" \u2192 DATETIME=date\n'
        '"hey what\'s up" \u2192 CHAT\n'
        '"can you write me a python function" \u2192 CHAT\n\n'
        'When genuinely unsure between SEARCH and CHAT for a live-fact question, prefer SEARCH. '
        'When unsure between MEMORY_SAVE and CHAT for casual personal statements, prefer MEMORY_SAVE. '
        'Output ONLY the token, nothing else.';

    final hintLine = hint != null
        ? '\n(A fast keyword scan suggests this might be $hint \u2014 verify against the actual message '
              'and override if it looks wrong.)'
        : '';
    final raw = await generateOneShot(
      sysPrompt,
      '"$userMessage"$hintLine \u2192',
      maxTokens: 20,
      temperature: 0.0,
    );
    return raw.trim();
  }

  Future<String> extractSingleField({
    required String fieldName,
    required String toolName,
    required String userMessage,
    int maxTokens = 80,
  }) async {
    const sysPrompt =
        'You are a precise data extractor. '
        'Output ONLY the raw value requested — no JSON, no quotes, no explanation, no labels.';
    final userPrompt =
        'Extract only the $fieldName for a $toolName action from the user\'s message below.\n'
        'Output only the raw value, no JSON, no quotes, no explanation.\n\n'
        'USER MESSAGE: \'$userMessage\'\n'
        'FIELD TO EXTRACT: $fieldName\n'
        'OUTPUT:';
    return generateOneShot(sysPrompt, userPrompt, maxTokens: maxTokens);
  }

  /// Agent-screen-optimised single-call router.
  /// Uses a minimal, stable system prompt (~90 tokens) designed for KV-cache reuse:
  /// the system message never changes between calls so llamadart can cache it.
  /// Returns the matched tool name, "MULTI", or "NONE".
  Future<String> agentClassifyTool(String userMessage) async {
    // This system prompt is intentionally static (no dynamic date/time/memory)
    // so the KV cache is reused on every agent request → faster, lower latency.
    // ── Agent Router System Prompt ────────────────────────────────────────────
    // ~120 tokens prefill. Rules:
    // 1. STATIC — KV-cacheable (no dynamic content).
    // 2. GROUPED — model narrows category before picking token.
    // 3. TRIMMED FEW-SHOT — only confusable pairs; obvious cases omitted.
    //    0.8B gets flashlight/wifi/bluetooth right from category alone.
    //    It struggles with: call vs sms vs whatsapp, alarm vs timer,
    //    camera vs screenshot, app_launch vs browser, MULTI, NONE.
    const agentSysPrompt =
        'Task classifier. Output ONLY one token below. /no_think\n\n'
        'HARDWARE: flashlight brightness volume screenshot camera\n'
        'NETWORK:  wifi bluetooth hotspot airplane_mode dnd\n'
        'TIME:     timer alarm\n'
        'COMMS:    call sms email whatsapp\n'
        'PHONE:    contacts calendar clipboard share settings app_launch remember\n'
        'MEDIA:    play_music\n'
        'WEB:      browser search ui_automate\n'
        'SPECIAL:  MULTI=two-or-more-tasks  NONE=question-or-chat\n\n'
        // Only examples the model genuinely confuses:
        'Ex:\n'
        '"call dad"→call  "text John"→sms  "whatsapp Sara hi"→whatsapp\n'
        '"remind me 7am"→alarm  "5 min countdown"→timer\n'
        '"take photo"→camera  "take screenshot"→screenshot\n'
        '"open YouTube"→app_launch  "go to youtube.com"→browser\n'
        '"what time is it?"→NONE  "set alarm and email boss"→MULTI\n'
        '\nToken:';

    final raw = await generateOneShot(
      agentSysPrompt,
      // Matches the exact few-shot format: "command" → TOKEN
      // The model just continues the established pattern.
      '"$userMessage" →',
      maxTokens: 8, // one token is max 3-4 chars; 8 is generous safety margin
      temperature: 0.01, // near-zero: routing must be deterministic
    );
    final token = raw.trim().toLowerCase().split(RegExp(r'[\s.,!?]+')).first;
    const validTokens = {
      'flashlight',
      'wifi',
      'bluetooth',
      'hotspot',
      'airplane_mode',
      'dnd',
      'brightness',
      'volume',
      'screenshot',
      'camera',
      'timer',
      'alarm',
      'email',
      'whatsapp',
      'call',
      'sms',
      'calendar',
      'contacts',
      'clipboard',
      'share',
      'settings',
      'app_launch',
      'play_music',
      'remember',
      'browser',
      'ui_automate',
      'search',
      'multi',
      'none',
    };
    if (validTokens.contains(token)) return token;
    // Fuzzy fallback: scan raw for any valid token
    for (final t in validTokens) {
      if (raw.toLowerCase().contains(t)) return t;
    }
    return 'none';
  }

  // ── FIXED: now goes through the real lock instead of hand-rolled _isGenerating ──
  Future<List<String>> extractPlanArray(
    String userMessage,
    List<String> validTools,
  ) async {
    if (!_isReady) return [];

    final toolEnum = validTools.map((t) => t).toList();
    final schema = <String, dynamic>{
      'type': 'object',
      'properties': {
        'tools': {
          'type': 'array',
          'items': {'type': 'string', 'enum': toolEnum},
        },
      },
      'required': ['tools'],
      'additionalProperties': false,
    };

    const toolManifest =
        'TOOLS: flashlight(state:on|off), wifi(state:on|off), bluetooth(state:on|off), '
        'brightness(level:0-100), volume(level:0-15), screenshot(), '
        'timer(minutes:int,label:string), alarm(time:string,label:string), '
        'play_music(query:string), '
        'email(to,subject,body), whatsapp(contact,message), call(contact), '
        'sms(contact,message), browser(query_or_url), maps(destination), '
        'app_launch(app_name), settings(category), share(text), clipboard(text), '
        'calendar(title,time), contacts(), remember(note), ui_automate(app,goal)';

    const sysPrompt =
        'You are a task planner. Output ONLY a JSON object containing a tools array of tool names in execution order. '
        'Use only names from the provided TOOLS. No parameters. No explanation.';
    final userPrompt =
        '$toolManifest\n\nUSER MESSAGE: "$userMessage"\n\n'
        'OUTPUT (JSON object):';

    await acquireLock();
    try {
      final messages = [
        const LlamaChatMessage.fromText(
          role: LlamaChatRole.system,
          text: '$sysPrompt\n/no_think',
        ),
        LlamaChatMessage.fromText(role: LlamaChatRole.user, text: userPrompt),
      ];

      final output = LlamaStructuredOutput<List<String>>.jsonSchema(
        schema: schema,
        decoder: (json) {
          final tools = json['tools'];
          if (tools is List) return tools.map((e) => e.toString()).toList();
          return <String>[];
        },
      );

      final result = await _engine
          .createStructuredJson(
            messages,
            output: output,
            params: GenerationParams(
              maxTokens: 60,
              temp: 0.1,
              topK: 10,
              topP: 0.8,
              thinkingBudget: const ThinkingBudget(maxTokens: 0),
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (result.isNotEmpty) {
        debugPrint('[Planner] GBNF plan: $result');
        releaseLock(); // release before returning
        return result;
      }
    } catch (e) {
      debugPrint(
        '[Planner] GBNF structured output failed ($e). Attempting JSON Corrector fallback.',
      );
    }
    // CRITICAL: Release lock BEFORE calling generateOneShot (which re-acquires it)
    releaseLock();

    try {
      final raw = await generateOneShot(sysPrompt, userPrompt, maxTokens: 60);
      final corrected = JsonCorrector.repair(raw);
      final parsed = jsonDecode(corrected);
      if (parsed is Map && parsed['tools'] is List) {
        final tools = (parsed['tools'] as List)
            .map((e) => e.toString())
            .toList();
        debugPrint('[Planner] Fallback plan: $tools');
        return tools;
      }
    } catch (e2) {
      debugPrint('[Planner] Fallback also failed: $e2');
    }

    return _fallbackKeywordScan(userMessage, validTools);
  }

  List<String> _fallbackKeywordScan(
    String userMessage,
    List<String> validTools,
  ) {
    final lower = userMessage.toLowerCase();
    const keywordMap = {
      'flashlight': 'toggle_torch',
      'torch': 'toggle_torch',
      'wifi': 'toggle_wifi',
      'wi-fi': 'toggle_wifi',
      'bluetooth': 'toggle_bluetooth',
      'brightness': 'set_brightness',
      'volume': 'set_volume',
      'mute': 'set_volume',
      'screenshot': 'take_screenshot',
      'timer': 'set_timer',
      'countdown': 'set_timer',
      'alarm': 'set_reminder',
      'remind': 'set_reminder',
      'email': 'send_email',
      'mail': 'send_email',
      'whatsapp': 'send_whatsapp_message',
      'call': 'make_call',
      'dial': 'make_call',
      'sms': 'send_sms',
      'text message': 'send_sms',
      'browser': 'open_browser',
      'website': 'open_browser',
      'maps': 'open_maps',
      'directions': 'open_maps',
      'settings': 'open_settings',
      'share': 'share_text',
      'clipboard': 'copy_to_clipboard',
      'copy': 'copy_to_clipboard',
      'calendar': 'open_calendar',
      'event': 'open_calendar',
      'contacts': 'open_contacts',
      'remember': 'remember',
      'note': 'remember',
      'play music': 'play_music',
      'spotify': 'play_music',
      'export': 'document_export',
      'pdf': 'document_export',
      'pptx': 'document_export',
      'build': 'build_app',
      'html': 'build_app',
      'css': 'build_app',
      'automate': 'ui_automate',
      'click': 'ui_automate',
    };

    final seen = <String>{};
    final found = <String>[];
    for (final entry in keywordMap.entries) {
      if (lower.contains(entry.key) && !seen.contains(entry.value)) {
        seen.add(entry.value);
        found.add(entry.value);
      }
    }
    const appNames = [
      'youtube',
      'instagram',
      'spotify',
      'netflix',
      'twitter',
      'whatsapp',
      'facebook',
      'tiktok',
      'telegram',
      'discord',
      'chrome',
      'gmail',
    ];
    for (final app in appNames) {
      if (lower.contains(app) &&
          !seen.contains('launch_app') &&
          (lower.contains('open') ||
              lower.contains('launch') ||
              lower.contains('start'))) {
        found.add('launch_app');
        seen.add('launch_app');
        break;
      }
    }
    return found;
  }

  Future<Map<String, dynamic>?> getToolCallJson(
    String prompt, {
    int maxRetries = 2,
  }) async {
    if (!_isReady) return null;
    String currentPrompt = prompt;
    for (int i = 0; i <= maxRetries; i++) {
      String raw = '';
      await acquireLock();
      try {
        await for (final chunk
            in _engine
                .create(
                  [
                    LlamaChatMessage.fromText(
                      role: LlamaChatRole.user,
                      text: currentPrompt,
                    ),
                  ],
                  params: GenerationParams(
                    maxTokens: 40,
                    temp: 0.3,
                    topK: 20,
                    topP: 0.85,
                    thinkingBudget: const ThinkingBudget(maxTokens: 0),
                    stopSequences: const [
                      '<|im_end|>',
                      '<|endoftext|>',
                      '</s>',
                    ],
                  ),
                )
                .timeout(const Duration(seconds: 15))) {
          final content = chunk.choices.first.delta.content;
          if (content != null) raw += content;
        }
      } catch (e) {
        debugPrint('[getToolCallJson] attempt ${i + 1} error: $e');
      } finally {
        releaseLock();
      }
      final extracted = _extractJsonBlock(raw);
      if (extracted != null) {
        try {
          return jsonDecode(extracted) as Map<String, dynamic>;
        } catch (_) {}
      }
      currentPrompt =
          '$prompt\n\nYour last response was not valid JSON. '
          'Reply with ONLY the JSON object, nothing else.';
    }
    return null;
  }

  String? _extractJsonBlock(String text) {
    int braceCount = 0;
    int? start;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '{') {
        start ??= i;
        braceCount++;
      } else if (text[i] == '}') {
        braceCount--;
        if (braceCount == 0 && start != null) {
          return text.substring(start, i + 1);
        }
      }
    }
    return null;
  }

  // ── FIXED: now goes through the real lock instead of an unguarded write ──
  Future<Map<String, dynamic>?> extractDocumentExportParams(
    String userMessage,
  ) async {
    if (!_isReady) return null;

    final schema = <String, dynamic>{
      'type': 'object',
      'properties': {
        'format': {
          'type': 'string',
          'enum': ['pdf', 'pptx'],
        },
        'title': {'type': 'string'},
        'content': {'type': 'string'},
      },
      'required': ['format', 'title', 'content'],
      'additionalProperties': false,
    };

    const sysPrompt =
        'Extract document export details from the user message. '
        'Infer format: pdf for reports/letters/documents, pptx for slides/presentations. '
        'Break pptx content into slide sections separated by blank lines.';
    final userPrompt = 'USER MESSAGE: "$userMessage"\nOUTPUT (JSON):';

    final output = LlamaStructuredOutput<Map<String, dynamic>>.jsonSchema(
      schema: schema,
      decoder: (json) => json,
    );

    await acquireLock();
    // _ensureTextFastProfile must run INSIDE the lock to avoid racing on _engine
    if (_activeProfile != ModelProfile.textFast) {
      releaseLock();
      await _ensureTextFastProfile();
      await acquireLock();
    }
    try {
      final result = await _engine
          .createStructuredJson(
            [
              LlamaChatMessage.fromText(
                role: LlamaChatRole.system,
                text: '$sysPrompt\n/no_think',
              ),
              LlamaChatMessage.fromText(
                role: LlamaChatRole.user,
                text: userPrompt,
              ),
            ],
            output: output,
            params: GenerationParams(
              maxTokens: 600,
              temp: 0.4,
              thinkingBudget: const ThinkingBudget(maxTokens: 0),
            ),
          )
          .timeout(const Duration(seconds: 25));
      return result;
    } catch (e) {
      debugPrint('[document_export] extraction failed: $e');
      return null;
    } finally {
      releaseLock();
    }
  }

  Future<void> _downloadWithResume(String url, File dest) async {
    final partFile = File('${dest.path}.part');
    int startByte = 0;
    if (await partFile.exists()) {
      startByte = await partFile.length();
      if (startByte >= 4) {
        try {
          final raf = await partFile.open(mode: FileMode.read);
          final bytes = await raf.read(4);
          await raf.close();
          final validMagic =
              bytes.length == 4 &&
              bytes[0] == 0x47 &&
              bytes[1] == 0x47 &&
              bytes[2] == 0x55 &&
              bytes[3] == 0x46;
          if (!validMagic) {
            await partFile.delete();
            startByte = 0;
          }
        } catch (_) {
          await partFile.delete();
          startByte = 0;
        }
      }
      if (startByte >= minModelBytes * 2) {
        await partFile.delete();
        startByte = 0;
      }
    }
    if (startByte > 0) {
      debugPrint('[ModelService] Resuming from byte $startByte');
    }
    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          receiveTimeout: const Duration(minutes: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final raf = await partFile.open(mode: FileMode.append);
      int received = startByte, total = -1;
      final contentRange = response.headers.value('content-range');
      if (contentRange != null && contentRange.contains('/')) {
        total = int.tryParse(contentRange.split('/').last) ?? -1;
      } else {
        final cl = response.headers.value('content-length');
        if (cl != null) total = (int.tryParse(cl) ?? 0) + startByte;
      }
      await for (final chunk in response.data!.stream) {
        await raf.writeFrom(chunk);
        received += chunk.length;
        onDownloadProgress?.call(received, total > 0 ? total : received);
      }
      await raf.close();
      final partLen = await partFile.length();
      if (partLen < minModelBytes) {
        await partFile.delete();
        throw Exception(
          'Download incomplete (${partLen ~/ 1024 ~/ 1024}MB). Please retry.',
        );
      }
      await partFile.rename(dest.path);
      debugPrint('[ModelService] Download complete: ${dest.path}');
    } catch (e) {
      debugPrint('[ModelService] Download error: $e');
      rethrow;
    }
  }

  Future<void> saveHistory(List<Map<String, String>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsMemoryKey, jsonEncode(messages));
  }

  Future<List<Map<String, String>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsMemoryKey);
    if (raw == null) return [];
    try {
      return List<Map<String, String>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, String>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> dispose() async => _engine.dispose();
}

class GgufCheckException implements Exception {
  final String message;
  const GgufCheckException(this.message);
  @override
  String toString() => 'GgufCheckException: $message';
}
