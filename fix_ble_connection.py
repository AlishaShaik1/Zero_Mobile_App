import sys

TARGET = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion\android\app\src\main\kotlin\com\example\zero_air\RingBleHandler.kt'

with open(TARGET, 'r', encoding='utf-8') as f:
    content = f.read()

print('Original size:', len(content))

# ── Fix 1: Bonded device auto-connect - include empty-name BLE devices ────────
OLD1 = (
    '                val isKnownRing = name.contains(DEVICE_NAME, ignoreCase = true) ||\n'
    '                                  name.contains("Ring", ignoreCase = true) ||\n'
    '                                  (storedAddress != null && dev.address.equals(storedAddress, ignoreCase = true))\n'
    '                if (isKnownRing && gatt == null && !isConnecting) {\n'
    '                    android.util.Log.i("RingBle", "Auto-connecting to bonded Zero device: ${name.ifEmpty { "(no name)" }} [${dev.address}]")\n'
    '                    connectDevice(dev, "bonded")\n'
    '                    return\n'
    '                }'
)

NEW1 = (
    '                val isKnownRing = name.contains(DEVICE_NAME, ignoreCase = true) ||\n'
    '                                  name.contains("Ring", ignoreCase = true) ||\n'
    '                                  (storedAddress != null && dev.address.equals(storedAddress, ignoreCase = true))\n'
    '                // Also try empty-name bonded devices (Android hides name until BLUETOOTH_CONNECT granted)\n'
    '                val isEmptyNameBle = name.isEmpty()\n'
    '                if ((isKnownRing || isEmptyNameBle) && gatt == null && !isConnecting) {\n'
    '                    val logName = name.ifEmpty { "(no name - might be Zero Ring)" }\n'
    '                    android.util.Log.i("RingBle", "Auto-connecting to bonded device: $logName [${dev.address}]")\n'
    '                    connectDevice(dev, "bonded")\n'
    '                    return\n'
    '                }'
)

if OLD1 in content:
    content = content.replace(OLD1, NEW1, 1)
    print('[OK] Fix 1: Bonded device auto-connect includes empty-name devices')
else:
    print('[WARN] Fix 1: bonded block not found - trying partial match...')
    if 'isKnownRing && gatt == null && !isConnecting' in content:
        print('  -> Found partial match, skipping to preserve existing logic')
    else:
        print('  -> No match found')

# ── Fix 2: Scan timeout 20s -> 30s with auto-restart ─────────────────────────
OLD2 = (
    '        try {\n'
    '            stopScan()\n'
    '            bleScanner?.startScan(null, settings, scanCallback)\n'
    '            mainHandler.postDelayed({\n'
    '                stopScan()\n'
    '            }, 20_000)\n'
    '        } catch (e: Exception) {\n'
    '            android.util.Log.e("RingBle", "startScan error: ${e.message}")\n'
    '            sendEvent(mapOf("type" to "disconnected", "error" to e.message))\n'
    '        }'
)

NEW2 = (
    '        try {\n'
    '            stopScan()\n'
    '            bleScanner?.startScan(null, settings, scanCallback)\n'
    '            // After 30s, if still not connected, stop scan and auto-retry after 1.5s\n'
    '            mainHandler.postDelayed({\n'
    '                stopScan()\n'
    '                if (gatt == null && !isConnecting) {\n'
    '                    android.util.Log.i("RingBle", "Scan 30s timeout — restarting scan automatically")\n'
    '                    mainHandler.postDelayed({ startScan() }, 1500)\n'
    '                }\n'
    '            }, 30_000)\n'
    '        } catch (e: Exception) {\n'
    '            android.util.Log.e("RingBle", "startScan error: ${e.message}")\n'
    '            sendEvent(mapOf("type" to "disconnected", "error" to e.message))\n'
    '        }'
)

if OLD2 in content:
    content = content.replace(OLD2, NEW2, 1)
    print('[OK] Fix 2: Scan timeout extended to 30s with auto-restart')
else:
    print('[WARN] Fix 2: scan timeout block not found')

# ── Fix 3: Watchdog 10s -> 15s with retry ─────────────────────────────────────
OLD3 = (
    '        // Watchdog timeout after 10s: release connecting lock if handshake hung\n'
    '        mainHandler.postDelayed({\n'
    '            if (isConnecting && (gatt == null || charCommand == null)) {\n'
    '                android.util.Log.w("RingBle", "connectDevice watchdog timeout after 10s")\n'
    '                isConnecting = false\n'
    '            }\n'
    '        }, 10_000)'
)

NEW3 = (
    '        // Watchdog: if service discovery not done in 15s, unlock and retry connection\n'
    '        mainHandler.postDelayed({\n'
    '            if (isConnecting && !characteristicsEnabled) {\n'
    '                android.util.Log.w("RingBle", "connectDevice watchdog: 15s — releasing lock, retrying")\n'
    '                isConnecting = false\n'
    '                try { gatt?.disconnect() } catch (_: Exception) {}\n'
    '                try { gatt?.close() } catch (_: Exception) {}\n'
    '                gatt = null\n'
    '                val retryDev = lastConnectDevice\n'
    '                if (retryDev != null) {\n'
    '                    mainHandler.postDelayed({ connectDevice(retryDev, "watchdog-retry") }, 1000)\n'
    '                } else {\n'
    '                    startScan()\n'
    '                }\n'
    '            }\n'
    '        }, 15_000)'
)

if OLD3 in content:
    content = content.replace(OLD3, NEW3, 1)
    print('[OK] Fix 3: Watchdog improved to 15s with retry')
else:
    print('[WARN] Fix 3: watchdog block not found')

# ── Write the fixed file ──────────────────────────────────────────────────────
with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(content)

print()
print('Final size:', len(content), 'bytes')
print('Total lines:', len(content.splitlines()))
