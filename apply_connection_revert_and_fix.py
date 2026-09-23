import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

BASE_COMPANION = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion'

# ── 1. Revert neverForLocation in AndroidManifest.xml (exact v1.0.5+6 state) ───
manifest_path = os.path.join(BASE_COMPANION, 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
with open(manifest_path, 'r', encoding='utf-8') as f:
    m_content = f.read()

# Replace neverForLocation BLUETOOTH_SCAN declaration with clean standard declaration
old_never = '''    <uses-permission
        android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation"
        tools:targetApi="s" />'''

clean_scan = '    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />'

if old_never in m_content:
    m_content = m_content.replace(old_never, clean_scan)
    print('[OK] AndroidManifest.xml: Removed neverForLocation (matches working v1.0.5+6)')
elif 'neverForLocation' in m_content:
    import re
    m_content = re.sub(r'<uses-permission\s+android:name="android.permission.BLUETOOTH_SCAN"[^>]*/>', clean_scan.strip(), m_content)
    print('[OK] AndroidManifest.xml: Cleaned BLUETOOTH_SCAN via regex')
else:
    print('[INFO] AndroidManifest.xml: neverForLocation already removed')

with open(manifest_path, 'w', encoding='utf-8') as f:
    f.write(m_content)


# ── 2. Fix RingBleHandler.kt ──────────────────────────────────────────────────
ble_path = os.path.join(BASE_COMPANION, 'android', 'app', 'src', 'main', 'kotlin', 'com', 'example', 'zero_air', 'RingBleHandler.kt')
with open(ble_path, 'r', encoding='utf-8') as f:
    ble_content = f.read()

# Remove refreshDeviceCache(g) from onConnectionStateChange
if 'refreshDeviceCache(g)' in ble_content:
    ble_content = ble_content.replace('                    refreshDeviceCache(g)\n', '')
    print('[OK] RingBleHandler.kt: Removed destructive refreshDeviceCache(g) call on connect')

# Remove MTU blocking logic in onServicesDiscovered — restore exact v1.0.5+6 instant enable
old_on_services = '''            // Safety timeout: if onMtuChanged does not fire in 600ms, enable characteristics anyway
            mainHandler.postDelayed({
                if (!characteristicsEnabled && gatt != null) {
                    android.util.Log.i("RingBle", "MTU timeout fallback: enabling characteristics now")
                    enableCharacteristics(g, svc)
                }
            }, 600)

            // Request MTU 517 (exact v1.0.5+6 behavior)
            val requested = try { g.requestMtu(MTU_REQUEST) } catch (_: Exception) { false }
            if (!requested) {
                enableCharacteristics(g, svc)
            }'''

new_on_services = '''            // Request MTU in background, but enable characteristics immediately without blocking! (v1.0.5+6)
            try { g.requestMtu(MTU_REQUEST) } catch (_: Exception) {}
            enableCharacteristics(g, svc)'''

if old_on_services in ble_content:
    ble_content = ble_content.replace(old_on_services, new_on_services)
    print('[OK] RingBleHandler.kt: Restored instant enableCharacteristics without MTU block')
else:
    print('[WARN] RingBleHandler.kt: old_on_services block not found directly, checking partial...')
    # Try finding the MTU delay block
    idx_m = ble_content.find('// Safety timeout: if onMtuChanged does not fire')
    idx_end = ble_content.find('override fun onMtuChanged', idx_m)
    if idx_m != -1 and idx_end != -1:
        ble_content = ble_content[:idx_m] + new_on_services + '\n        }\n\n        ' + ble_content[idx_end:]
        print('[OK] RingBleHandler.kt: Replaced MTU delay block via boundary search')

# Add onBatchScanResults to scanCallback so batched results are not dropped
if 'override fun onBatchScanResults' not in ble_content:
    old_scan_cb = '    private val scanCallback = object : ScanCallback() {'
    new_scan_cb = '''    private val scanCallback = object : ScanCallback() {
        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            for (res in results) {
                onScanResult(ScanSettings.CALLBACK_TYPE_ALL_MATCHES, res)
            }
        }
'''
    ble_content = ble_content.replace(old_scan_cb, new_scan_cb)
    print('[OK] RingBleHandler.kt: Added onBatchScanResults callback to prevent dropped batches')

# Ensure onScanResult emits all devices and auto-connects to Zero
old_emit = '''            // Always emit device_discovered so UI displays it
            if (rawName.isNotEmpty() || hasService || isStoredMatch) {
                val displayName = if (rawName.isNotEmpty()) rawName else "Zero Ring"
                discoveredAddresses.add(address)
                sendEvent(mapOf(
                    "type" to "device_discovered",
                    "name" to displayName,
                    "address" to address,
                    "rssi" to result.rssi,
                    "isBonded" to false
                ))
            }'''

new_emit = '''            // Always emit device_discovered so UI displays it
            val displayName = when {
                rawName.isNotEmpty() -> rawName
                hasService || isStoredMatch -> "Zero Ring"
                else -> "BLE Device (${address.takeLast(5)})"
            }
            discoveredAddresses.add(address)
            sendEvent(mapOf(
                "type" to "device_discovered",
                "name" to displayName,
                "address" to address,
                "rssi" to result.rssi,
                "isBonded" to false
            ))'''

if old_emit in ble_content:
    ble_content = ble_content.replace(old_emit, new_emit)
    print('[OK] RingBleHandler.kt: Ensured all discovered devices are emitted to UI')

with open(ble_path, 'w', encoding='utf-8') as f:
    f.write(ble_content)


# ── 3. Update ring_ble_service.dart ───────────────────────────────────────────
service_path = os.path.join(BASE_COMPANION, 'lib', 'services', 'ring_ble_service.dart')
with open(service_path, 'r', encoding='utf-8') as f:
    s_content = f.read()

# Request Permission.location directly in connect()
old_perm_block = '''      if (Platform.isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.locationWhenInUse,
        ].request();
      }'''

new_perm_block = '''      if (Platform.isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
          Permission.locationWhenInUse,
        ].request();
      }'''

if old_perm_block in s_content:
    s_content = s_content.replace(old_perm_block, new_perm_block)
    print('[OK] ring_ble_service.dart: Added Permission.location to connect()')

with open(service_path, 'w', encoding='utf-8') as f:
    f.write(s_content)


# ── 4. Bump version to 1.0.12+13 in pubspec.yaml ─────────────────────────────
pubspec_path = os.path.join(BASE_COMPANION, 'pubspec.yaml')
with open(pubspec_path, 'r', encoding='utf-8') as f:
    p_content = f.read()

p_content = p_content.replace('version: 1.0.11+12', 'version: 1.0.12+13')
with open(pubspec_path, 'w', encoding='utf-8') as f:
    f.write(p_content)
print('[OK] pubspec.yaml: Bumped version to 1.0.12+13')

print('\nPatch script completed successfully.')
