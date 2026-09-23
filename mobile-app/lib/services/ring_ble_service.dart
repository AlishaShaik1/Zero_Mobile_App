// ring_ble_service.dart — Zero Ring BLE companion service (Dart side)
//
// Responsibilities:
//   • Scan for ring by name "Zero" or service UUID
//   • Stream discovered BLE & bonded devices in real-time
//   • Connect, discover services, request MTU 517
//   • Enable NOTIFY on mic-audio, media, air-mouse characteristics (incl. CCCD)
//   • Keep a foreground service alive so Android cannot kill the BLE connection
//   • Auto-reconnect with exponential backoff (1s → 2s → 5s → 10s)
//   • Expose a typed event stream (audio chunks, media frames, air-mouse deltas, devices)
//   • Write caption, audio-reply and command characteristics (phone → ring)

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ring_constants.dart';

// ── Event types ───────────────────────────────────────────────────────────────

sealed class RingEvent {
  const RingEvent();
}

/// PCM audio chunk from mic characteristic (16 kHz mono, 16-bit LE).
class RingAudioChunk extends RingEvent {
  final Uint8List pcm;
  const RingAudioChunk(this.pcm);
}

/// Binary media frame — accumulated by RingMediaReceiver.
class RingMediaFrame extends RingEvent {
  final Uint8List bytes;
  const RingMediaFrame(this.bytes);
}

/// Media header notif — e.g. "M:photo:48213".
class RingMediaHeader extends RingEvent {
  final String raw;
  const RingMediaHeader(this.raw);
}

/// Media end-of-transfer marker.
class RingMediaEnd extends RingEvent {
  const RingMediaEnd();
}

/// Signed [dx, dy] from air-mouse characteristic.
class RingAirMouse extends RingEvent {
  final int dx;
  final int dy;
  const RingAirMouse(this.dx, this.dy);
}

/// Connection state change.
class RingConnectionEvent extends RingEvent {
  final RingConnectionState state;
  final String? deviceName;
  final String? address;
  const RingConnectionEvent(this.state, {this.deviceName, this.address});
}

/// Discovered device during scanning or from system bonded list
class RingDeviceDiscoveredEvent extends RingEvent {
  final DiscoveredRingDevice device;
  const RingDeviceDiscoveredEvent(this.device);
}

enum RingConnectionState { scanning, connecting, connected, disconnected }

class DiscoveredRingDevice {
  final String name;
  final String address;
  final int rssi;
  final bool isBonded;

  const DiscoveredRingDevice({
    required this.name,
    required this.address,
    required this.rssi,
    this.isBonded = false,
  });

  bool get isZeroRing =>
      name.toLowerCase().contains('zero') ||
      name.toLowerCase().contains('ring');
}

// ── Service ───────────────────────────────────────────────────────────────────

class RingBleService {
  RingBleService._();
  static final RingBleService instance = RingBleService._();

  // MethodChannel: Dart → Kotlin (commands)
  final MethodChannel _ch = const MethodChannel(kBleChannel);
  // EventChannel: Kotlin → Dart (BLE events stream)
  final EventChannel _ev = const EventChannel(kBleEventChannel);

  final _controller = StreamController<RingEvent>.broadcast();

  /// Stream of all events from the ring. Subscribe once.
  Stream<RingEvent> get events => _controller.stream;

  StreamSubscription? _nativeSub;
  RingConnectionState _state = RingConnectionState.disconnected;
  RingConnectionState get connectionState => _state;
  bool get isConnected => _state == RingConnectionState.connected;

  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  String? _connectedDeviceAddress;
  String? get connectedDeviceAddress => _connectedDeviceAddress;

  final Map<String, DiscoveredRingDevice> _discoveredDevices = {};
  List<DiscoveredRingDevice> get discoveredDevices =>
      _discoveredDevices.values.toList()
        ..sort((a, b) {
          // Zero devices first, then bonded, then highest RSSI
          if (a.isZeroRing && !b.isZeroRing) return -1;
          if (!a.isZeroRing && b.isZeroRing) return 1;
          if (a.isBonded && !b.isBonded) return -1;
          if (!a.isBonded && b.isBonded) return 1;
          return b.rssi.compareTo(a.rssi);
        });

  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  bool _userDisconnected = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _setupForegroundTask();
    _listenNative();
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _nativeSub?.cancel();
    _controller.close();
  }

  // ── Foreground service ────────────────────────────────────────────────────

  void _setupForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'zero_ring_ble',
        channelName: 'Zero Ring',
        channelDescription: 'Keeps Zero Ring connected.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> _startForeground() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 3001,
      notificationTitle: 'Zero Ring Connected',
      notificationText: 'Voice AI & Sensor streaming active',
    );
  }

  Future<void> _stopForeground() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }

  // ── Native event stream ───────────────────────────────────────────────────

  void _listenNative() {
    _nativeSub = _ev.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (e) => debugPrint('[RingBle] EventChannel error: $e'),
    );
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final type = raw['type'] as String? ?? '';

    switch (type) {
      case 'device_discovered':
        final name = (raw['name'] as String?) ?? 'Unknown';
        final address = (raw['address'] as String?) ?? '';
        final rssi = (raw['rssi'] as int?) ?? -60;
        final isBonded = (raw['isBonded'] as bool?) ?? false;
        if (address.isNotEmpty) {
          final dev = DiscoveredRingDevice(
            name: name,
            address: address,
            rssi: rssi,
            isBonded: isBonded,
          );
          _discoveredDevices[address] = dev;
          _controller.add(RingDeviceDiscoveredEvent(dev));
        }

      case 'audio':
        final data = raw['data'];
        if (data is Uint8List && data.isNotEmpty) {
          _controller.add(RingAudioChunk(data));
        }

      case 'media_header':
        final header = raw['header'] as String? ?? '';
        _controller.add(RingMediaHeader(header));

      case 'media_frame':
        final data = raw['data'];
        if (data is Uint8List) _controller.add(RingMediaFrame(data));

      case 'media_end':
        _controller.add(const RingMediaEnd());

      case 'air_mouse':
        final dx = (raw['dx'] as int?) ?? 0;
        final dy = (raw['dy'] as int?) ?? 0;
        _controller.add(RingAirMouse(dx, dy));

      case 'connected':
        _reconnectAttempt = 0;
        _reconnectTimer?.cancel();
        _state = RingConnectionState.connected;
        _connectedDeviceName = (raw['name'] as String?) ?? 'Zero';
        _connectedDeviceAddress = raw['address'] as String?;
        _controller.add(
          RingConnectionEvent(
            RingConnectionState.connected,
            deviceName: _connectedDeviceName,
            address: _connectedDeviceAddress,
          ),
        );
        _startForeground();

      case 'disconnected':
        _state = RingConnectionState.disconnected;
        _connectedDeviceName = null;
        _connectedDeviceAddress = null;
        _controller.add(
          const RingConnectionEvent(RingConnectionState.disconnected),
        );
        _stopForeground();
        if (!_userDisconnected) _scheduleReconnect();

      case 'scanning':
        _state = RingConnectionState.scanning;
        _controller.add(
          const RingConnectionEvent(RingConnectionState.scanning),
        );

      case 'connecting':
        _state = RingConnectionState.connecting;
        _connectedDeviceName = raw['name'] as String?;
        _connectedDeviceAddress = raw['address'] as String?;
        _controller.add(
          RingConnectionEvent(
            RingConnectionState.connecting,
            deviceName: _connectedDeviceName,
            address: _connectedDeviceAddress,
          ),
        );

      default:
        debugPrint('[RingBle] Unknown event type: $type');
    }
  }

  // ── Reconnect backoff ─────────────────────────────────────────────────────

  static const _backoffDelays = [1, 2, 5, 10];

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delaySeconds = _reconnectAttempt < _backoffDelays.length
        ? _backoffDelays[_reconnectAttempt]
        : _backoffDelays.last;
    _reconnectAttempt++;
    debugPrint(
      '[RingBle] Reconnect in ${delaySeconds}s (attempt $_reconnectAttempt)',
    );
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> connect() async {
    _userDisconnected = false;
    _state = RingConnectionState.scanning;
    _discoveredDevices.clear();
    _controller.add(const RingConnectionEvent(RingConnectionState.scanning));
    try {
      if (Platform.isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
          Permission.locationWhenInUse,
        ].request();
      }
      await _ch.invokeMethod<void>('startScan');
    } catch (e) {
      debugPrint('[RingBle] connect error: $e');
      _scheduleReconnect();
    }
  }

  Future<bool> connectToAddress(String address) async {
    _userDisconnected = false;
    _state = RingConnectionState.connecting;
    _controller.add(const RingConnectionEvent(RingConnectionState.connecting));
    try {
      final ok = await _ch.invokeMethod<bool>('connectAddress', {'address': address});
      return ok ?? false;
    } catch (e) {
      debugPrint('[RingBle] connectToAddress error: $e');
      return false;
    }
  }

  Future<List<DiscoveredRingDevice>> getBondedDevices() async {
    try {
      final list = await _ch.invokeListMethod<Map>('getBondedDevices');
      if (list != null) {
        return list.map((m) => DiscoveredRingDevice(
          name: m['name']?.toString() ?? 'Paired Device',
          address: m['address']?.toString() ?? '',
          rssi: -45,
          isBonded: true,
        )).toList();
      }
    } catch (e) {
      debugPrint('[RingBle] getBondedDevices error: $e');
    }
    return [];
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      final res = await _ch.invokeMethod<bool>('isBluetoothEnabled');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    _reconnectTimer?.cancel();
    try {
      await _ch.invokeMethod<void>('disconnect');
    } catch (e) {
      debugPrint('[RingBle] disconnect error: $e');
    }
    await _stopForeground();
  }

  // ── Write helpers ─────────────────────────────────────────────────────────

  Future<void> sendCommand(String cmd) async {
    if (!isConnected) return;
    try {
      await _ch.invokeMethod<void>('writeCommand', {'command': cmd});
    } catch (e) {
      debugPrint('[RingBle] sendCommand error: $e');
    }
  }

  /// UTF-8 encode and chunk-write to the Caption characteristic.
  Future<void> sendCaption(String text) async {
    if (!isConnected) return;
    final bytes = Uint8List.fromList(
      text.runes.expand((r) {
        if (r < 0x80) return [r];
        if (r < 0x800) return [0xC0 | (r >> 6), 0x80 | (r & 0x3F)];
        return [0xE0 | (r >> 12), 0x80 | ((r >> 6) & 0x3F), 0x80 | (r & 0x3F)];
      }).toList(),
    );
    await _writeChunked(kCharCaption, bytes);
  }

  Future<void> sendAudioReply(Uint8List pcm16kHz) async {
    if (!isConnected) return;
    await _writeChunked(kCharAiReply, pcm16kHz);
  }

  Future<void> _writeChunked(String charUuid, Uint8List data) async {
    int seq = 0;
    int offset = 0;

    while (offset < data.length) {
      final end = (offset + kChunkSize).clamp(0, data.length);
      final slice = data.sublist(offset, end);
      final chunk = Uint8List(1 + slice.length)..[0] = seq & 0xFF;
      chunk.setRange(1, chunk.length, slice);

      try {
        await _ch.invokeMethod<void>('writeCharacteristic', {
          'uuid': charUuid,
          'data': chunk,
        });
      } catch (e) {
        debugPrint('[RingBle] write error ($charUuid): $e');
        return;
      }
      seq++;
      offset = end;
    }

    // Zero-length end marker
    try {
      await _ch.invokeMethod<void>('writeCharacteristic', {
        'uuid': charUuid,
        'data': Uint8List.fromList([seq & 0xFF]),
      });
    } catch (_) {}
  }
}
