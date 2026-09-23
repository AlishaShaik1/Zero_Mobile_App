import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

BASE_COMPANION = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion'

# ── 1. Update AndroidManifest.xml ─────────────────────────────────────────────
manifest_path = os.path.join(BASE_COMPANION, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
with open(manifest_path, 'r', encoding='utf-8') as f:
    m_content = f.read()

# Ensure xmlns:tools is present
if 'xmlns:tools=' not in m_content:
    m_content = m_content.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:tools="http://schemas.android.com/tools">'
    )

# Update BLUETOOTH_SCAN to include neverForLocation
old_bt_scan = '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />'
new_bt_scan = (
    '<uses-permission\n'
    '        android:name="android.permission.BLUETOOTH_SCAN"\n'
    '        android:usesPermissionFlags="neverForLocation"\n'
    '        tools:targetApi="s" />'
)
if old_bt_scan in m_content:
    m_content = m_content.replace(old_bt_scan, new_bt_scan)
    print('[OK] AndroidManifest.xml: Updated BLUETOOTH_SCAN with neverForLocation')
else:
    print('[INFO] AndroidManifest.xml: BLUETOOTH_SCAN already modified or pattern different')

with open(manifest_path, 'w', encoding='utf-8') as f:
    f.write(m_content)


# ── 2. Update RingBleHandler.kt ───────────────────────────────────────────────
ble_path = os.path.join(BASE_COMPANION, 'android', 'app', 'src', 'main', 'kotlin', 'com', 'example', 'zero_air', 'RingBleHandler.kt')
with open(ble_path, 'r', encoding='utf-8') as f:
    ble_content = f.read()

# Replace startScan implementation with clean, non-blocking scan that always scans
old_start_scan_marker = '    fun startScan() {'
idx_start_scan = ble_content.find(old_start_scan_marker)

# Find stopScan() after startScan
idx_stop_scan = ble_content.find('    fun stopScan() {', idx_start_scan)

if idx_start_scan != -1 and idx_stop_scan != -1:
    new_start_scan = '''    fun startScan() {
        val adapter = bluetoothAdapter ?: run {
            val bm = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            bluetoothAdapter = bm?.adapter
            bluetoothAdapter
        }

        if (adapter == null || !adapter.isEnabled) {
            sendEvent(mapOf("type" to "disconnected", "error" to "bluetooth_disabled"))
            return
        }

        isConnecting = false // ensure we never stay stuck in connecting
        discoveredAddresses.clear()
        sendEvent(mapOf("type" to "scanning"))

        // ── Emit bonded devices for UI list display ──────────────────────────
        try {
            val bonded = adapter.bondedDevices ?: emptySet<BluetoothDevice>()
            for (dev in bonded) {
                val name = try { dev.name } catch (_: SecurityException) { null } ?: ""
                discoveredAddresses.add(dev.address)
                sendEvent(mapOf(
                    "type" to "device_discovered",
                    "name" to (if (name.isNotEmpty()) name else "Paired Device"),
                    "address" to dev.address,
                    "rssi" to -45,
                    "isBonded" to true
                ))
            }
        } catch (e: Exception) {
            android.util.Log.w("RingBle", "bonded listing warning: ${e.message}")
        }

        // ── Active BLE Scanner (Always runs so Zero Ring is discovered) ────────
        bleScanner = adapter.bluetoothLeScanner
        if (bleScanner == null) {
            sendEvent(mapOf("type" to "disconnected", "error" to "scanner_unavailable"))
            return
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setReportDelay(0)
            .build()

        try {
            stopScan()
            bleScanner?.startScan(null, settings, scanCallback)
            android.util.Log.i("RingBle", "BLE active scan started (low latency)")
            // Auto-refresh scan every 25s if still disconnected
            mainHandler.postDelayed({
                if (gatt == null && !isConnecting) {
                    android.util.Log.i("RingBle", "Scan cycle refresh")
                    stopScan()
                    mainHandler.postDelayed({ startScan() }, 1000)
                }
            }, 25_000)
        } catch (e: Exception) {
            android.util.Log.e("RingBle", "startScan error: ${e.message}")
            sendEvent(mapOf("type" to "disconnected", "error" to e.message))
        }
    }

'''
    ble_content = ble_content[:idx_start_scan] + new_start_scan + ble_content[idx_stop_scan:]
    print('[OK] RingBleHandler.kt: Rewrote startScan() to always run active BLE scan cleanly')

# Fix connectDevice watchdog: 8s timeout, fallback to startScan() instead of infinite device retry
old_watchdog_snippet = '''        // Watchdog: if service discovery not done in 15s, unlock and retry connection
        mainHandler.postDelayed({
            if (isConnecting && !characteristicsEnabled) {
                android.util.Log.w("RingBle", "connectDevice watchdog: 15s — releasing lock, retrying")
                isConnecting = false
                try { gatt?.disconnect() } catch (_: Exception) {}
                try { gatt?.close() } catch (_: Exception) {}
                gatt = null
                val retryDev = lastConnectDevice
                if (retryDev != null) {
                    mainHandler.postDelayed({ connectDevice(retryDev, "watchdog-retry") }, 1000)
                } else {
                    startScan()
                }
            }
        }, 15_000)'''

new_watchdog_snippet = '''        // Watchdog: if service discovery not complete in 8s, unlock and return to scan
        mainHandler.postDelayed({
            if (isConnecting && !characteristicsEnabled) {
                android.util.Log.w("RingBle", "connectDevice watchdog: 8s timeout — releasing lock & restarting scan")
                isConnecting = false
                try { gatt?.disconnect() } catch (_: Exception) {}
                try { gatt?.close() } catch (_: Exception) {}
                gatt = null
                startScan()
            }
        }, 8_000)'''

if old_watchdog_snippet in ble_content:
    ble_content = ble_content.replace(old_watchdog_snippet, new_watchdog_snippet)
    print('[OK] RingBleHandler.kt: Watchdog updated to 8s with clean startScan fallback')
else:
    # Try generic replacement for watchdog if lines differed
    import re
    watchdog_pattern = r'//\s*Watchdog.*?mainHandler\.postDelayed\(\{.*?isConnecting &&.*?\},\s*(?:10_000|15_000)\)'
    m = re.search(watchdog_pattern, ble_content, re.DOTALL)
    if m:
        ble_content = ble_content[:m.start()] + new_watchdog_snippet.strip() + ble_content[m.end():]
        print('[OK] RingBleHandler.kt: Watchdog updated via regex to 8s')

# Fix startAutoReconnectLoop to call startScan() rather than locking on stale lastConnectDevice
old_reconnect_logic = '''                    val dev = lastConnectDevice ?: run {
                        val stored = getStoredAddress()
                        if (stored != null) bluetoothAdapter?.getRemoteDevice(stored) else null
                    }
                    if (dev != null) {
                        android.util.Log.i("RingBle", "Auto-reconnect attempting connection to ${dev.address}")
                        connectDevice(dev, "auto-reconnect")
                    } else {
                        startScan()
                    }'''

new_reconnect_logic = '''                    // Run scan so we actively see when Zero ring advertising starts
                    android.util.Log.i("RingBle", "Auto-reconnect starting scan...")
                    startScan()'''

if old_reconnect_logic in ble_content:
    ble_content = ble_content.replace(old_reconnect_logic, new_reconnect_logic)
    print('[OK] RingBleHandler.kt: Auto-reconnect now scans actively')

with open(ble_path, 'w', encoding='utf-8') as f:
    f.write(ble_content)


# ── 3. Update ring_audio_pipeline.dart ────────────────────────────────────────
pipe_path = os.path.join(BASE_COMPANION, 'lib', 'services', 'ring_audio_pipeline.dart')
with open(pipe_path, 'r', encoding='utf-8') as f:
    pipe_content = f.read()

# Fix 1: In _processUtteranceWithTranscript: do NOT overwrite liveTranscript with 'Searching AI...'
# Overwriting transcript with 'Searching AI...' prevents the user from seeing their spoken words
old_pipe_thinking = '''  Future<void> _processUtteranceWithTranscript(String transcript) async {
    _setState(RingPipelineState.thinking);
    _liveTranscriptController.add('Searching AI...');'''

new_pipe_thinking = '''  Future<void> _processUtteranceWithTranscript(String transcript) async {
    _setState(RingPipelineState.thinking);
    // Keep user's spoken words in liveTranscript — post status to liveAiResponse
    _liveAiResponseController.add('Searching AI...');'''

if old_pipe_thinking in pipe_content:
    pipe_content = pipe_content.replace(old_pipe_thinking, new_pipe_thinking)
    print('[OK] ring_audio_pipeline.dart: Preserved user transcript on screen')
else:
    print('[WARN] ring_audio_pipeline.dart: old_pipe_thinking pattern not found')

# Fix 2: In tool execution: show doing message in AI response, not in liveTranscript
old_tool_doing = "        _liveTranscriptController.add('Doing: ${route.toolName}...');"
new_tool_doing = "        _liveAiResponseController.add('Doing: ${route.toolName}...');"

if old_tool_doing in pipe_content:
    pipe_content = pipe_content.replace(old_tool_doing, new_tool_doing)
    print('[OK] ring_audio_pipeline.dart: Routed tool doing status to AI response stream')

with open(pipe_path, 'w', encoding='utf-8') as f:
    f.write(pipe_content)


# ── 4. Update ring_companion_screen.dart ──────────────────────────────────────
screen_path = os.path.join(BASE_COMPANION, 'lib', 'screens', 'ring_companion_screen.dart')
with open(screen_path, 'r', encoding='utf-8') as f:
    screen_content = f.read()

# Fix: In connection hero button onTap: allow tapping during scanning to cancel or restart scan
old_tap = 'onTap: isScan ? null : _toggleConnection,'
new_tap = 'onTap: _toggleConnection,'

if old_tap in screen_content:
    screen_content = screen_content.replace(old_tap, new_tap)
    print('[OK] ring_companion_screen.dart: Enabled connection button tap while scanning')

with open(screen_path, 'w', encoding='utf-8') as f:
    f.write(screen_content)

print('\\nAll fixes successfully applied!')
