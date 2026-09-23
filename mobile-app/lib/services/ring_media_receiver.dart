// ring_media_receiver.dart — Receives and reassembles media frames from Zero Ring
//
// Protocol:
//   1. Ring sends RingMediaHeader e.g. "M:photo:24810"
//   2. Ring sends chunked RingMediaFrame binary packets
//   3. Ring sends RingMediaEnd ("M:END")
//
// This receiver accumulates the bytes, calculates progress, and emits
// the final image Uint8List and cached File.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'ring_ble_service.dart';

class RingPhoto {
  final Uint8List bytes;
  final String filePath;
  final DateTime timestamp;
  final int byteSize;

  const RingPhoto({
    required this.bytes,
    required this.filePath,
    required this.timestamp,
    required this.byteSize,
  });
}

class RingMediaReceiver {
  RingMediaReceiver._();
  static final RingMediaReceiver instance = RingMediaReceiver._();

  StreamSubscription? _bleSub;
  bool _isReceiving = false;
  bool get isReceiving => _isReceiving;

  // ignore: unused_field
  String _currentMediaType = 'photo'; // set from BLE M: header, e.g. "photo" or "video"
  int _expectedBytes = 0;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  final _photoController = StreamController<RingPhoto>.broadcast();
  Stream<RingPhoto> get onPhotoReceived => _photoController.stream;

  final _progressController = StreamController<double>.broadcast();
  Stream<double> get onProgress => _progressController.stream;

  final List<RingPhoto> _savedPhotos = [];
  List<RingPhoto> get savedPhotos => List.unmodifiable(_savedPhotos);

  RingPhoto? _latestPhoto;
  RingPhoto? get latestPhoto => _latestPhoto;

  void initialize() {
    _bleSub?.cancel();
    _bleSub = RingBleService.instance.events.listen(_handleBleEvent);
    loadSavedPhotos();
    debugPrint('[RingMediaReceiver] Initialized');
  }

  Future<void> loadSavedPhotos() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${docs.path}/ZeroRingPhotos');
      if (await photoDir.exists()) {
        final files = photoDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.jpeg'))
            .toList();
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        _savedPhotos.clear();
        for (final f in files) {
          final bytes = await f.readAsBytes();
          _savedPhotos.add(RingPhoto(
            bytes: bytes,
            filePath: f.path,
            timestamp: f.lastModifiedSync(),
            byteSize: bytes.length,
          ));
        }
        if (_savedPhotos.isNotEmpty) {
          _latestPhoto = _savedPhotos.first;
        }
      }
    } catch (e) {
      debugPrint('[RingMediaReceiver] Error loading saved photos: $e');
    }
  }

  void dispose() {
    _bleSub?.cancel();
    _photoController.close();
    _progressController.close();
  }

  void _handleBleEvent(RingEvent event) {
    switch (event) {
      case RingMediaHeader(:final raw):
        _onHeader(raw);
        break;

      case RingMediaFrame(:final bytes):
        _onFrame(bytes);
        break;

      case RingMediaEnd():
        _onEnd();
        break;

      default:
        break;
    }
  }

  void _onHeader(String raw) {
    // Expected format: "M:photo:<length>" or "M:video:<length>"
    debugPrint('[RingMediaReceiver] Header received: $raw');
    _buffer.clear();
    _isReceiving = true;

    final parts = raw.split(':');
    if (parts.length >= 3) {
      _currentMediaType = parts[1];
      _expectedBytes = int.tryParse(parts[2]) ?? 0;
    } else {
      _currentMediaType = 'photo';
      _expectedBytes = 0;
    }
    _progressController.add(0.0);
  }

  void _onFrame(Uint8List chunk) {
    if (!_isReceiving) {
      _isReceiving = true;
      _buffer.clear();
    }
    _buffer.add(chunk);

    if (_expectedBytes > 0) {
      final progress = (_buffer.length / _expectedBytes).clamp(0.0, 1.0);
      _progressController.add(progress);
    }
  }

  Future<void> _onEnd() async {
    if (!_isReceiving) return;
    _isReceiving = false;
    _progressController.add(1.0);

    final rawBytes = Uint8List.fromList(_buffer.toBytes());
    _buffer.clear();

    if (rawBytes.isEmpty) {
      debugPrint('[RingMediaReceiver] Received empty media payload');
      return;
    }

    debugPrint('[RingMediaReceiver] Media complete: ${rawBytes.length} bytes');

    try {
      final timeStr = DateTime.now().millisecondsSinceEpoch;
      final docs = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${docs.path}/ZeroRingPhotos');
      if (!await photoDir.exists()) {
        await photoDir.create(recursive: true);
      }

      final file = File('${photoDir.path}/ring_photo_$timeStr.jpg');
      await file.writeAsBytes(rawBytes);

      // Also save copy to public Pictures / DCIM folder if accessible on Android
      try {
        if (Platform.isAndroid) {
          final publicDir = Directory('/storage/emulated/0/DCIM/ZeroRing');
          if (!await publicDir.exists()) {
            await publicDir.create(recursive: true);
          }
          final pubFile = File('${publicDir.path}/ring_photo_$timeStr.jpg');
          await pubFile.writeAsBytes(rawBytes);
          debugPrint('[RingMediaReceiver] Saved public gallery copy: ${pubFile.path}');
        }
      } catch (e) {
        debugPrint('[RingMediaReceiver] Public storage copy optional notice: $e');
      }

      final photo = RingPhoto(
        bytes: rawBytes,
        filePath: file.path,
        timestamp: DateTime.now(),
        byteSize: rawBytes.length,
      );

      _savedPhotos.insert(0, photo);
      _latestPhoto = photo;
      _photoController.add(photo);
      debugPrint('[RingMediaReceiver] Saved ring photo permanently to: ${file.path}');
    } catch (e) {
      debugPrint('[RingMediaReceiver] Error saving photo: $e');
    }
  }
}
