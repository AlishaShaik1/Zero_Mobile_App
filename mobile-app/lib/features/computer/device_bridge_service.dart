import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BridgeStatus { offline, connecting, connected }

class DeviceBridgeService {
  DeviceBridgeService._();
  static final instance = DeviceBridgeService._();

  RealtimeChannel? _channel;
  final _statusController = StreamController<BridgeStatus>.broadcast();
  Stream<BridgeStatus> get statusStream => _statusController.stream;
  BridgeStatus _status = BridgeStatus.offline;
  BridgeStatus get status => _status;

  void _setStatus(BridgeStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Future<void> connect(String email, String password) async {
    final client = Supabase.instance.client;

    try {
      await client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        // If the user doesn't exist yet, sign them up
        await client.auth.signUp(email: email, password: password);
      } else {
        rethrow;
      }
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Must be signed in before connecting the device bridge');
    }

    _setStatus(BridgeStatus.connecting);

    _channel = client.channel('device-bridge:$userId')
      ..onBroadcast(
        event: 'ack',
        callback: (payload) {
          // Desktop confirmed receipt
        },
      )
      ..onPresenceSync((payload) {
        final state = _channel!.presenceState();
        final desktopOnline = state.any(
          (p) => p.presences.any((pr) => pr.payload['device'] == 'desktop'),
        );
        _setStatus(
          desktopOnline ? BridgeStatus.connected : BridgeStatus.offline,
        );
      })
      ..subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          _setStatus(BridgeStatus.offline);
        }
      });
  }

  Future<void> sendCommand(String content) async {
    if (_channel == null) {
      throw StateError('Bridge not connected — call connect() first');
    }
    await _channel!.sendBroadcastMessage(
      event: 'command',
      payload: {
        'type': 'command',
        'content': content,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> disconnect() async {
    await _channel?.unsubscribe();
    _channel = null;
    _setStatus(BridgeStatus.offline);
  }
}
