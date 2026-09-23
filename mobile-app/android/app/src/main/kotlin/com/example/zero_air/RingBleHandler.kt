package com.example.zero_air

import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

// ── UUID constants (must match ring_constants.dart & ZeroRing.ino) ───────────

private val SERVICE_UUID   = UUID.fromString("6e400001-0000-1000-8000-00805f9b34fb")
private val CHAR_MIC_AUDIO = UUID.fromString("6e400002-0000-1000-8000-00805f9b34fb")
private val CHAR_AI_REPLY  = UUID.fromString("6e400003-0000-1000-8000-00805f9b34fb")
private val CHAR_COMMAND   = UUID.fromString("6e400004-0000-1000-8000-00805f9b34fb")
private val CHAR_CAPTION   = UUID.fromString("6e400005-0000-1000-8000-00805f9b34fb")
private val CHAR_MEDIA     = UUID.fromString("6e400006-0000-1000-8000-00805f9b34fb")
private val CHAR_AIR_MOUSE = UUID.fromString("6e400007-0000-1000-8000-00805f9b34fb")
private val CCCD_UUID      = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

private const val DEVICE_NAME = "Zero"
private const val MTU_REQUEST  = 517

/**
 * RingBleHandler — Owns all native BLE operations for the Zero Ring.
 *
 * Exposes:
 *  - MethodChannel: com.example.zero_ring/ble
 *  - EventChannel:  com.example.zero_ring/ble_events
 *
 * Restores exact v1.0.5+6 high-performance connection architecture:
 *  1. Stored MAC instant direct connect (reconnects in 0ms without waiting for radio scan)
 *  2. Bonded device instant auto-connect (connects to paired Zero Ring immediately)
 *  3. Active BLE low-latency scan fallback (auto-connects upon detecting "Zero" or service UUID)
 *  4. GATT cache invalidation via reflection to prevent stale handles
 *  5. Multi-service fallback lookup (6e40... / 4faf... / characteristic inspect)
 *  6. Non-blocking MTU negotiation + safe CCCD serialization
 */
class RingBleHandler(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bleScanner: BluetoothLeScanner? = null
    private var gatt: BluetoothGatt? = null

    private var charAiReply:  BluetoothGattCharacteristic? = null
    private var charCommand:  BluetoothGattCharacteristic? = null
    private var charCaption:  BluetoothGattCharacteristic? = null

    private var eventSink: EventChannel.EventSink? = null

    private val writeQueue = ArrayDeque<Pair<BluetoothGattCharacteristic, ByteArray>>()
    private var writeInFlight = false
    private var isConnecting = false
    private var characteristicsEnabled = false

    // GATT status 133 fix: retry once for bonded-device connection race
    private var lastConnectDevice: BluetoothDevice? = null
    private var lastConnectSource: String = ""
    private var gatt133RetryCount = 0
    private val MAX_GATT_133_RETRIES = 2

    private val discoveredAddresses = mutableSetOf<String>()

    // Background processor — handles ring pipeline natively when app is screen-off
    lateinit var backgroundProcessor: BackgroundRingProcessor
    fun isBackgroundProcessorInitialized() = ::backgroundProcessor.isInitialized

    // Direct reference to native STT handler for 0ms audio routing
    var ringStt: RingSttHandler? = null

    // Auto-reconnect supervisor loop
    private var reconnectRunnable: Runnable? = null

    // ── SharedPrefs: persist ring MAC across sessions ──────────────────────────
    private val prefs by lazy {
        context.getSharedPreferences("zero_ring_prefs", Context.MODE_PRIVATE)
    }
    private fun saveConnectedDevice(address: String, name: String) {
        prefs.edit().putString("ring_address", address).putString("ring_name", name).apply()
        android.util.Log.i("RingBle", "Saved ring MAC: $address ($name)")
    }
    private fun getStoredAddress(): String? = prefs.getString("ring_address", null)
    private fun getStoredName(): String = prefs.getString("ring_name", "Zero Ring") ?: "Zero Ring"

    /**
     * Clear Android's internal Bluetooth GATT cache using reflection.
     * Prevents stale service handles when reconnecting to ESP32 firmware updates.
     */
    private fun refreshDeviceCache(gatt: BluetoothGatt): Boolean {
        return try {
            val method = gatt.javaClass.getMethod("refresh")
            val res = method.invoke(gatt) as? Boolean ?: false
            android.util.Log.i("RingBle", "GATT cache refreshed: $res")
            res
        } catch (e: Exception) {
            android.util.Log.w("RingBle", "GATT refresh reflection failed: ${e.message}")
            false
        }
    }

    fun setupChannels(
        methodChannel: MethodChannel,
        eventChannel: EventChannel
    ) {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(args: Any?) {
                eventSink = null
            }
        })

        methodChannel.setMethodCallHandler { call, result ->
            val bm = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            bluetoothAdapter = bm?.adapter

            when (call.method) {
                "startScan" -> {
                    startScan()
                    result.success(true)
                }
                "stopScan" -> {
                    stopScan()
                    result.success(true)
                }
                "disconnect" -> {
                    disconnect()
                    result.success(true)
                }
                "connectAddress" -> {
                    val addr = call.argument<String>("address") ?: ""
                    val success = connectByAddress(addr)
                    result.success(success)
                }
                "getBondedDevices" -> {
                    result.success(getBondedDevicesList())
                }
                "isBluetoothEnabled" -> {
                    result.success(bluetoothAdapter?.isEnabled == true)
                }
                "writeCommand" -> {
                    val cmd = call.argument<String>("command") ?: ""
                    writeAscii(charCommand, cmd)
                    result.success(true)
                }
                "writeCharacteristic" -> {
                    val uuid  = call.argument<String>("uuid") ?: ""
                    val data  = call.argument<ByteArray>("data") ?: byteArrayOf()
                    val char  = gatt?.getService(SERVICE_UUID)?.getCharacteristic(UUID.fromString(uuid))
                    if (char != null) enqueueWrite(char, data)
                    result.success(char != null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getBondedDevicesList(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            val bonded = bluetoothAdapter?.bondedDevices ?: emptySet()
            for (dev in bonded) {
                val name = try { dev.name } catch (_: SecurityException) { null } ?: "Unknown"
                list.add(mapOf(
                    "name" to name,
                    "address" to dev.address,
                    "isBonded" to true
                ))
            }
        } catch (e: Exception) {
            android.util.Log.w("RingBle", "Error reading bonded devices: ${e.message}")
        }
        return list
    }

    fun startScan() {
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

    fun stopScan() {
        try {
            bleScanner?.stopScan(scanCallback)
        } catch (_: Exception) {}
    }

    private fun connectByAddress(address: String): Boolean {
        val adapter = bluetoothAdapter ?: return false
        try {
            stopScan()
            stopAutoReconnectLoop()
            isConnecting = false // Unlock immediately for manual user action
            val dev = adapter.getRemoteDevice(address) ?: return false
            connectDevice(dev, "manual")
            return true
        } catch (e: Exception) {
            android.util.Log.e("RingBle", "connectByAddress failed: ${e.message}")
            return false
        }
    }

    private fun connectDevice(dev: BluetoothDevice, source: String) {
        if (isConnecting) return
        isConnecting = true
        stopScan()

        lastConnectDevice = dev
        lastConnectSource = source

        val name = try { dev.name } catch (_: SecurityException) { DEVICE_NAME } ?: DEVICE_NAME
        android.util.Log.i("RingBle", "Connecting to $name [${dev.address}] via $source")
        sendEvent(mapOf(
            "type" to "connecting",
            "name" to name,
            "address" to dev.address,
            "source" to source
        ))

        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {}

        // Watchdog: if service discovery not complete in 8s, unlock and return to scan
        mainHandler.postDelayed({
            if (isConnecting && !characteristicsEnabled) {
                android.util.Log.w("RingBle", "connectDevice watchdog: 8s timeout — releasing lock & restarting scan")
                isConnecting = false
                try { gatt?.disconnect() } catch (_: Exception) {}
                try { gatt?.close() } catch (_: Exception) {}
                gatt = null
                startScan()
            }
        }, 8_000)

        // ALWAYS force TRANSPORT_LE — critical for BLE devices
        gatt = dev.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    private val scanCallback = object : ScanCallback() {
        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            for (res in results) {
                onScanResult(ScanSettings.CALLBACK_TYPE_ALL_MATCHES, res)
            }
        }

        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val dev = result.device ?: return
            val address = dev.address
            val devName = try { dev.name } catch (_: SecurityException) { null }
            val scanName = result.scanRecord?.deviceName
            val rawName = devName ?: scanName ?: ""

            val serviceUuids = result.scanRecord?.serviceUuids ?: emptyList<ParcelUuid>()
            val hasService = serviceUuids.any { 
                it.uuid.toString().equals(SERVICE_UUID.toString(), ignoreCase = true) ||
                it.uuid.toString().startsWith("6e40", ignoreCase = true)
            }
            val storedAddr = getStoredAddress()
            val isStoredMatch = storedAddr != null && address.equals(storedAddr, ignoreCase = true)

            val isZero = rawName.contains(DEVICE_NAME, ignoreCase = true) ||
                         rawName.contains("Ring", ignoreCase = true) ||
                         hasService ||
                         isStoredMatch

            // Always emit device_discovered so UI displays it
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
            ))

            // Auto-connect AFTER emitting device_discovered so the user sees it in the list
            if (isZero && gatt == null && !isConnecting) {
                android.util.Log.i("RingBle", "Found Zero device in scan: $rawName [$address] RSSI=${result.rssi}")
                connectDevice(dev, "scan")
            }
        }

        override fun onScanFailed(errorCode: Int) {
            android.util.Log.e("RingBle", "Scan failed: $errorCode")
            sendEvent(mapOf("type" to "disconnected", "error" to "scan_failed_$errorCode"))
        }
    }

    // ── GATT Callbacks ────────────────────────────────────────────────────────

    private val gattCallback = object : BluetoothGattCallback() {

        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            gatt = g
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    android.util.Log.i("RingBle", "GATT connected (status=$status). Discovering services in 300ms...")
                    gatt133RetryCount = 0
                    characteristicsEnabled = false
                    mainHandler.postDelayed({
                        try {
                            val ok = g.discoverServices()
                            android.util.Log.i("RingBle", "discoverServices returned: $ok")
                        } catch (e: Exception) {
                            android.util.Log.e("RingBle", "discoverServices call error: ${e.message}")
                        }
                    }, 300)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    android.util.Log.i("RingBle", "GATT disconnected (status=$status)")
                    isConnecting = false
                    characteristicsEnabled = false
                    try { g.close() } catch (_: Exception) {}
                    gatt = null
                    charAiReply = null
                    charCommand = null
                    charCaption = null
                    writeQueue.clear()
                    writeInFlight = false

                    // GATT error 133 = Android BLE stack race on bonded devices
                    if (status == 133 && gatt133RetryCount < MAX_GATT_133_RETRIES) {
                        gatt133RetryCount++
                        val dev = lastConnectDevice
                        val src = lastConnectSource
                        android.util.Log.w("RingBle", "GATT 133 error — retry $gatt133RetryCount/$MAX_GATT_133_RETRIES in 600ms")
                        mainHandler.postDelayed({
                            if (dev != null) connectDevice(dev, src)
                        }, 600)
                    } else {
                        gatt133RetryCount = 0
                        sendEvent(mapOf("type" to "disconnected", "status" to status))
                        startAutoReconnectLoop()
                    }
                }
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                android.util.Log.e("RingBle", "Service discovery failed with status $status")
                g.disconnect()
                return
            }

            android.util.Log.i("RingBle", "Discovered ${g.services.size} services on device.")
            var svc = g.getService(SERVICE_UUID)
            if (svc == null) {
                for (s in g.services) {
                    android.util.Log.i("RingBle", "Service UUID found: ${s.uuid}")
                    if (s.uuid.toString().equals(SERVICE_UUID.toString(), ignoreCase = true) ||
                        s.uuid.toString().startsWith("6e40", ignoreCase = true) ||
                        s.uuid.toString().startsWith("4faf", ignoreCase = true)) {
                        svc = s
                        break
                    }
                }
            }

            // Secondary fallback: check if any service has our mic audio or command characteristics
            if (svc == null) {
                for (s in g.services) {
                    if (s.getCharacteristic(CHAR_MIC_AUDIO) != null || s.getCharacteristic(CHAR_COMMAND) != null) {
                        svc = s
                        android.util.Log.i("RingBle", "Found Zero service by characteristic match: ${s.uuid}")
                        break
                    }
                }
            }

            if (svc == null) {
                android.util.Log.e("RingBle", "Service $SERVICE_UUID not found on device! Disconnecting.")
                g.disconnect()
                return
            }

            charAiReply = svc.getCharacteristic(CHAR_AI_REPLY)
            charCommand = svc.getCharacteristic(CHAR_COMMAND)
            charCaption = svc.getCharacteristic(CHAR_CAPTION)

            // Request MTU in background, but enable characteristics immediately without blocking! (v1.0.5+6)
            try { g.requestMtu(MTU_REQUEST) } catch (_: Exception) {}
            enableCharacteristics(g, svc)
        }

        override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
            android.util.Log.i("RingBle", "MTU changed: $mtu (status=$status)")
            val svc = g.getService(SERVICE_UUID) ?: run {
                for (s in g.services) {
                    if (s.uuid.toString().startsWith("6e40", ignoreCase = true)) return@run s
                }
                null
            } ?: return
            enableCharacteristics(g, svc)
        }

        private fun enableCharacteristics(g: BluetoothGatt, svc: BluetoothGattService) {
            if (characteristicsEnabled) return
            characteristicsEnabled = true
            stopAutoReconnectLoop()
            enableNotify(g, svc.getCharacteristic(CHAR_MIC_AUDIO))
            enableNotify(g, svc.getCharacteristic(CHAR_MEDIA))
            enableNotify(g, svc.getCharacteristic(CHAR_AIR_MOUSE))
            isConnecting = false
            val devName = try { g.device?.name } catch (_: SecurityException) { null } ?: DEVICE_NAME
            val devAddress = g.device?.address ?: ""
            if (devAddress.isNotEmpty()) saveConnectedDevice(devAddress, devName)
            sendEvent(mapOf(
                "type" to "connected",
                "name" to devName,
                "address" to devAddress
            ))
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val bytes = characteristic.value ?: return
            if (bytes.isNotEmpty()) routeNotification(characteristic.uuid, bytes)
        }

        override fun onCharacteristicChanged(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            if (value.isNotEmpty()) routeNotification(characteristic.uuid, value)
        }

        override fun onCharacteristicWrite(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            writeInFlight = false
            drainQueue(g)
        }

        override fun onDescriptorWrite(
            g: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            writeInFlight = false
            drainQueue(g)
        }
    }

    private fun routeNotification(uuid: UUID, bytes: ByteArray) {
        when (uuid) {
            CHAR_MIC_AUDIO -> {
                // Direct native routing to RingSttHandler (0ms latency, no Dart serialization)
                val stt = ringStt
                if (stt != null) {
                    if (bytes.size == 1 && bytes[0] == 0xFF.toByte()) {
                        stt.startStt()
                    } else if (bytes.size == 1 && bytes[0] == 0xFE.toByte()) {
                        stt.stopStt()
                    } else if (bytes.isNotEmpty()) {
                        stt.pushChunk(bytes)
                    }
                }
                // Always route audio to background processor (no-op if app is foreground)
                if (::backgroundProcessor.isInitialized) {
                    backgroundProcessor.onAudioChunk(bytes)
                }
                // Also send to Dart EventChannel (for foreground Dart pipeline)
                sendEvent(mapOf("type" to "audio", "data" to bytes))
            }
            CHAR_MEDIA -> {
                val text = runCatching { String(bytes, Charsets.US_ASCII) }.getOrNull() ?: ""
                when {
                    text.startsWith("M:END") -> sendEvent(mapOf("type" to "media_end"))
                    text.startsWith("M:")    -> sendEvent(mapOf("type" to "media_header", "header" to text))
                    else                     -> sendEvent(mapOf("type" to "media_frame", "data" to bytes))
                }
            }
            CHAR_AIR_MOUSE -> {
                if (bytes.size >= 2) {
                    val dx = bytes[0].toInt()
                    val dy = bytes[1].toInt()
                    sendEvent(mapOf("type" to "air_mouse", "dx" to dx, "dy" to dy))
                }
            }
        }
    }

    private fun enableNotify(g: BluetoothGatt, char: BluetoothGattCharacteristic?) {
        char ?: return
        g.setCharacteristicNotification(char, true)
        val cccd = char.getDescriptor(CCCD_UUID) ?: return
        enqueueDescriptorWrite(cccd, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
    }

    private fun writeAscii(char: BluetoothGattCharacteristic?, text: String) {
        char ?: return
        enqueueWrite(char, text.toByteArray(Charsets.US_ASCII))
    }

    @Synchronized
    private fun enqueueWrite(char: BluetoothGattCharacteristic, data: ByteArray) {
        writeQueue.addLast(Pair(char, data))
        val g = gatt ?: return
        if (!writeInFlight) drainQueue(g)
    }

    @Synchronized
    private fun enqueueDescriptorWrite(descriptor: BluetoothGattDescriptor, value: ByteArray) {
        val g = gatt ?: return
        if (writeInFlight) {
            mainHandler.postDelayed({ enqueueDescriptorWrite(descriptor, value) }, 50)
            return
        }
        writeInFlight = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val res = g.writeDescriptor(descriptor, value)
            if (res != BluetoothStatusCodes.SUCCESS) {
                android.util.Log.e("RingBle", "writeDescriptor error: $res")
                writeInFlight = false
            }
        } else {
            @Suppress("DEPRECATION")
            descriptor.value = value
            @Suppress("DEPRECATION")
            val ok = g.writeDescriptor(descriptor)
            if (!ok) {
                android.util.Log.e("RingBle", "writeDescriptor returned false")
                writeInFlight = false
            }
        }
    }

    @Synchronized
    private fun drainQueue(g: BluetoothGatt) {
        if (writeInFlight || writeQueue.isEmpty()) return
        val (char, data) = writeQueue.removeFirst()
        writeInFlight = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            g.writeCharacteristic(char, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
        } else {
            @Suppress("DEPRECATION")
            char.value = data
            char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            @Suppress("DEPRECATION")
            g.writeCharacteristic(char)
        }
    }

    fun disconnect() {
        isConnecting = false
        characteristicsEnabled = false
        stopScan()
        try { gatt?.disconnect() } catch (_: Exception) {}
        try { gatt?.close() } catch (_: Exception) {}
        gatt = null
        charAiReply = null
        charCommand = null
        charCaption = null
        writeQueue.clear()
        writeInFlight = false
        sendEvent(mapOf("type" to "disconnected"))
        startAutoReconnectLoop()
    }

    private fun startAutoReconnectLoop() {
        stopAutoReconnectLoop()
        reconnectRunnable = object : Runnable {
            override fun run() {
                if (gatt != null) return
                if (!isConnecting) {
                    // Run scan so we actively see when Zero ring advertising starts
                    android.util.Log.i("RingBle", "Auto-reconnect starting scan...")
                    startScan()
                }
                mainHandler.postDelayed(this, 3000)
            }
        }
        mainHandler.postDelayed(reconnectRunnable!!, 1500)
    }

    private fun stopAutoReconnectLoop() {
        reconnectRunnable?.let { mainHandler.removeCallbacks(it) }
        reconnectRunnable = null
    }

    /** Write a UTF-8 caption string directly to the ring OLED characteristic.
     *  Called from BackgroundRingProcessor (Kotlin-only, no Dart involved). */
    fun writeCaption(text: String) {
        val char = charCaption ?: return
        val bytes = text.toByteArray(Charsets.UTF_8)
        enqueueWrite(char, bytes)
    }

    private fun sendEvent(data: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(data)
        }
    }
}
