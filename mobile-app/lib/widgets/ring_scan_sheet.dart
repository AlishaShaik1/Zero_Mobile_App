// ring_scan_sheet.dart — Real Dynamic BLE Radar Scan & Device Pairing Sheet
// Scans for the "Zero" smart ring, lists discovered & bonded devices in real-time,
// displays live RSSI, MAC addresses, and connects directly.

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ring_ble_service.dart';

class RingScanSheet extends StatefulWidget {
  const RingScanSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const RingScanSheet(),
    );
  }

  @override
  State<RingScanSheet> createState() => _RingScanSheetState();
}

class _RingScanSheetState extends State<RingScanSheet>
    with SingleTickerProviderStateMixin {
  final _ble = RingBleService.instance;
  StreamSubscription? _bleSub;
  RingConnectionState _connState = RingConnectionState.disconnected;
  String? _connectingAddress;
  List<DiscoveredRingDevice> _bondedSnapshot = []; // pre-loaded bonded devices

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _connState = _ble.connectionState;

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _bleSub = _ble.events.listen((event) {
      if (mounted) {
        setState(() {
          _connState = _ble.connectionState;
          if (_connState == RingConnectionState.connected ||
              _connState == RingConnectionState.disconnected) {
            _connectingAddress = null;
          }
        });
      }
    });

    // Pre-populate bonded devices immediately so the ring shows up instantly
    _prefetchBondedDevices();

    // Start scan only if not already connecting/connected
    if (!_ble.isConnected && _connState != RingConnectionState.connecting) {
      _startScan();
    }
  }

  Future<void> _prefetchBondedDevices() async {
    try {
      final bonded = await _ble.getBondedDevices();
      if (mounted && bonded.isNotEmpty) {
        setState(() {
          // Store bonded devices directly so they show in the UI list immediately
          _bondedSnapshot = bonded;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _radarController.dispose();
    _bleSub?.cancel();
    super.dispose();
  }

  void _startScan() {
    _connectingAddress = null;
    _ble.connect();
  }

  void _connectDevice(DiscoveredRingDevice dev) {
    setState(() {
      _connectingAddress = dev.address;
    });
    _ble.connectToAddress(dev.address);
  }

  void _disconnect() {
    _ble.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connState == RingConnectionState.connected;
    final isScanning = _connState == RingConnectionState.scanning;
    final isConnecting = _connState == RingConnectionState.connecting;

    // Merge BLE-discovered devices with bonded snapshot
    // Use a map by address to deduplicate, preferring live scan data
    final deviceMap = <String, DiscoveredRingDevice>{};
    for (final d in _bondedSnapshot) {
      deviceMap[d.address] = d;
    }
    for (final d in _ble.discoveredDevices) {
      deviceMap[d.address] = d; // live scan overwrites bonded snapshot
    }
    // Sort: Zero ring first, then bonded, then highest RSSI
    final devices = deviceMap.values.toList()
      ..sort((a, b) {
        if (a.isZeroRing && !b.isZeroRing) return -1;
        if (!a.isZeroRing && b.isZeroRing) return 1;
        if (a.isBonded && !b.isBonded) return -1;
        if (!a.isBonded && b.isBonded) return 1;
        return b.rssi.compareTo(a.rssi);
      });

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_searching,
                      color: isConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF38BDF8),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Zero Ring Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Radar Scan Visualizer
            Center(
              child: SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isScanning || isConnecting)
                      AnimatedBuilder(
                        animation: _radarController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(130, 130),
                            painter: _RadarPainter(
                              progress: _radarController.value,
                              color: isConnecting
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF38BDF8),
                            ),
                          );
                        },
                      ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? const Color(0xFF10B981)
                            : (isConnecting
                                ? const Color(0xFFF59E0B)
                                : (isScanning
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF334155))),
                        boxShadow: [
                          BoxShadow(
                            color: (isConnected
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF38BDF8))
                                .withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.check
                            : (isScanning
                                ? Icons.bluetooth_searching
                                : Icons.bluetooth),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status Description
            Center(
              child: Text(
                isConnected
                    ? 'Connected to ${_ble.connectedDeviceName ?? "Zero Ring"}'
                    : (isConnecting
                        ? 'Connecting to Zero Ring...'
                        : (isScanning
                            ? 'Scanning for Bluetooth devices (${devices.length} found)...'
                            : 'Scan idle')),
                style: TextStyle(
                  color: isConnected
                      ? const Color(0xFF34D399)
                      : (isConnecting
                          ? const Color(0xFFFBBF24)
                          : (isScanning ? const Color(0xFF38BDF8) : Colors.white70)),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Device List / Active Connection
            Flexible(
              child: isConnected
                  ? _buildConnectedCard()
                  : (devices.isEmpty
                      ? _buildEmptyState(isScanning)
                      : _buildDeviceList(devices, isConnecting)),
            ),

            const SizedBox(height: 12),

            // Actions & Helpful Hint
            Row(
              children: [
                if (!isConnected)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isScanning ? null : _startScan,
                      icon: Icon(
                        isScanning ? Icons.sync : Icons.refresh,
                        size: 18,
                        color: const Color(0xFF38BDF8),
                      ),
                      label: Text(
                        isScanning ? 'Scanning...' : 'Scan Again',
                        style: const TextStyle(color: Color(0xFF38BDF8)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (isConnected)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.bluetooth_disabled, size: 18),
                      label: const Text('Disconnect Ring'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white38, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Zero Ring: Double-tap button to speak. Hold 3s to power off.',
                      style: TextStyle(color: Colors.white54, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _ble.connectedDeviceName ?? 'Zero Ring',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _ble.connectedDeviceAddress != null
                      ? '${_ble.connectedDeviceAddress} • 16kHz PCM Active'
                      : '16kHz PCM Voice & Mascot Ready',
                  style: const TextStyle(color: Color(0xFF34D399), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isScanning) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isScanning ? Icons.radar : Icons.bluetooth_disabled,
              color: Colors.white38,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              isScanning
                  ? 'Searching for "Zero" BLE device...'
                  : 'No devices found',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Make sure Zero Ring is awake (click button once)',
              style: TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(
      List<DiscoveredRingDevice> devices, bool isConnecting) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final dev = devices[idx];
        final isThisConnecting = _connectingAddress == dev.address;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: dev.isZeroRing
                ? const Color(0xFF0F2744)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: dev.isZeroRing
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                  : Colors.white12,
              width: dev.isZeroRing ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: dev.isZeroRing
                      ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  dev.isZeroRing ? Icons.trip_origin : Icons.bluetooth,
                  color: dev.isZeroRing
                      ? const Color(0xFF38BDF8)
                      : Colors.white54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dev.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: dev.isZeroRing
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (dev.isBonded) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PAIRED',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${dev.address} • RSSI ${dev.rssi} dBm',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isConnecting ? null : () => _connectDevice(dev),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dev.isZeroRing
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: isThisConnecting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        dev.isZeroRing ? 'Connect' : 'Pair',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress + (i * 0.33)) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
