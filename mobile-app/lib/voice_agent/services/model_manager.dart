import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// core/constants.dart not referenced in model_manager

class ModelManager {
  ModelManager._();
  static final ModelManager instance = ModelManager._();

  // One active download lock per model URL to prevent race conditions
  final Map<String, Future<void>> _activeDownloads = {};

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ),
  );

  Future<Directory> asrDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/models/asr');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> kwsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/models/kws');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> ttsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/models/tts2');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<bool> _isReady(Directory dir) async {
    final readyFile = File('${dir.path}/.ready');
    return await readyFile.exists();
  }

  Future<bool> isAsrCached() => asrDir().then(_isReady);
  Future<bool> isKwsCached() => kwsDir().then(_isReady);
  Future<bool> isTtsCached() => ttsDir().then(_isReady);

  /// Performs a robust, resumable, atomic download with extraction.
  Future<void> downloadAndExtract({
    required String url,
    required Directory destDir,
    required void Function(double) onProgress,
  }) async {
    // Return existing future if already downloading
    if (_activeDownloads.containsKey(url)) {
      return _activeDownloads[url];
    }
    final completer = Completer<void>();
    _activeDownloads[url] = completer.future;

    try {
      if (await _isReady(destDir)) {
        onProgress(1.0);
        completer.complete();
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filename = url.split('/').last.split('?').first;
      final partPath = '${tempDir.path}/$filename.part';
      final archPath = '${tempDir.path}/$filename';

      final partFile = File(partPath);

      int retryCount = 0;
      const maxRetries = 5;

      while (retryCount < maxRetries) {
        try {
          int existingBytes = 0;
          if (await partFile.exists()) {
            existingBytes = await partFile.length();
          }

          // 1. HEAD request - Fail fast on 404, check lengths
          final headResponse = await _dio.head(url);
          final totalBytesStr = headResponse.headers.value(
            HttpHeaders.contentLengthHeader,
          );
          final int? totalBytes = totalBytesStr != null
              ? int.tryParse(totalBytesStr)
              : null;

          if (totalBytes != null && existingBytes == totalBytes) {
            // Already fully downloaded in .part
            break;
          }

          if (totalBytes != null && existingBytes > totalBytes) {
            // Corrupted/oversized .part due to changed upstream file
            await partFile.delete();
            existingBytes = 0;
          }

          // 2. Download with Range
          final options = Options(responseType: ResponseType.stream);
          if (existingBytes > 0) {
            options.headers = {
              HttpHeaders.rangeHeader: 'bytes=$existingBytes-',
            };
          }

          final response = await _dio.get<ResponseBody>(
            url,
            options: options,
            cancelToken: CancelToken(),
          );

          if (response.statusCode == 200) {
            // Server didn't honor Range, write from scratch
            if (existingBytes > 0) {
              await partFile.delete();
              existingBytes = 0;
            }
          } else if (response.statusCode == 206) {
            // Partial content respected
          } else {
            throw DioException(
              requestOptions: response.requestOptions,
              response: Response(
                requestOptions: response.requestOptions,
                statusCode: response.statusCode,
              ),
            );
          }

          final sink = partFile.openWrite(mode: FileMode.append);
          var totalReceived = existingBytes;

          final stream = response.data!.stream;
          await for (final chunk in stream) {
            sink.add(chunk);
            totalReceived += chunk.length;
            if (totalBytes != null && totalBytes > 0) {
              onProgress(totalReceived / totalBytes);
            }
          }
          await sink.close();
          break; // success
        } on DioException catch (e) {
          if (e.response?.statusCode == 404 || e.response?.statusCode == 403) {
            throw Exception(
              'Model URL failed with ${e.response?.statusCode}: $url',
            );
          }
          retryCount++;
          if (retryCount >= maxRetries) {
            throw Exception(
              'Failed to download after $maxRetries attempts: $e',
            );
          }
          // Exponential backoff
          final delay = pow(2, retryCount) * 1000;
          await Future.delayed(Duration(milliseconds: delay.toInt()));
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) rethrow;
          final delay = pow(2, retryCount) * 1000;
          await Future.delayed(Duration(milliseconds: delay.toInt()));
        }
      }

      // 3. Atomically finalize download
      try {
        await partFile.rename(archPath);
      } catch (_) {
        await partFile.copy(archPath);
        await partFile.delete();
      }

      // 4. Extract
      onProgress(-1);
      await compute(
        _extractArchive,
        _ExtractArgs(archPath, destDir.path, isTts: url.contains('tts')),
      );

      // 5. Cleanup and mark ready
      final arch = File(archPath);
      if (await arch.exists()) await arch.delete();

      final readyFile = File('${destDir.path}/.ready');
      await readyFile.writeAsString(DateTime.now().toIso8601String());

      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _activeDownloads.remove(url);
    }
  }

  /// Pure on-device STT & TTS — zero audio model downloads required.
  Future<void> ensureModelsDownloaded({
    required void Function(double) onProgress,
  }) async {
    onProgress(1.0);
    return;
  }

  Future<String> ensureKeywordsFile() async {
    final dir = await kwsDir();
    final outPath = '${dir.path}/hey_zero_keywords.txt';
    final outFile = File(outPath);
    final data = await rootBundle.load('assets/kws/keywords.txt');
    await outFile.writeAsBytes(data.buffer.asUint8List());
    return outPath;
  }
}

class _ExtractArgs {
  final String archivePath;
  final String destDir;
  final bool isTts;
  const _ExtractArgs(this.archivePath, this.destDir, {this.isTts = false});
}

void _extractArchive(_ExtractArgs args) {
  final bytes = File(args.archivePath).readAsBytesSync();
  final bzip2Bytes = BZip2Decoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(bzip2Bytes);

  for (final entry in archive) {
    if (!entry.isFile) continue;

    final originalFilename = entry.name.split('/').last;
    String? filename;

    if (args.isTts) {
      filename = entry.name;
    } else {
      final lower = originalFilename.toLowerCase();
      if (lower.contains('encoder')) {
        filename = 'encoder.int8.onnx';
      } else if (lower.contains('decoder')) {
        filename = 'decoder.int8.onnx';
      } else if (lower.contains('joiner')) {
        filename = 'joiner.int8.onnx';
      } else if (lower == 'tokens.txt') {
        filename = 'tokens.txt';
      }
    }

    if (filename != null) {
      final outFile = File('${args.destDir}/$filename');
      if (args.isTts) {
        outFile.parent.createSync(recursive: true);
      }
      outFile.writeAsBytesSync(entry.content);
    }
  }
}
