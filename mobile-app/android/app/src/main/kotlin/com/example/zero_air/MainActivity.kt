package com.example.zero_air

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.AlarmClock
import android.system.Os
import android.app.role.RoleManager
import android.app.SearchManager
import android.os.Bundle
import android.view.WindowManager
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.Settings
import android.bluetooth.BluetoothAdapter
import android.telephony.SmsManager
import android.view.accessibility.AccessibilityManager
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.zero_air/tools"
    private var methodChannel: MethodChannel? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val REQUEST_CODE_ASSISTANT = 1001

    // ── Zero Ring BLE handler ──────────────────────────────────────────────
    private val ringBle by lazy { RingBleHandler(this) }

    // ── Zero Ring on-device STT handler (ring PCM → SpeechRecognizer pipe) ──
    private val ringStt by lazy { RingSttHandler(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Screen wake triggers
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        
        try {
            Os.setenv("GGML_VK_DISABLE_COOPMAT", "1", true)
            Os.setenv("GGML_VK_DISABLE_COOPMAT2", "1", true)
        } catch (_: Exception) { /* API level fallback: no-op, native lib will use its own defaults */ }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("wake_live_voice", false)) {
            methodChannel?.invokeMethod("wake_live_voice", null)
            intent.removeExtra("wake_live_voice")
        }
    }

    override fun onResume() {
        super.onResume()
        // Signal to background processor: Dart pipeline is active, hands off
        if (ringBle.isBackgroundProcessorInitialized()) ringBle.backgroundProcessor.onAppForeground()
        // Acquire PARTIAL_WAKE_LOCK to prevent CPU throttling during inference
        try {
            if (wakeLock == null || wakeLock?.isHeld == false) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ZeroAir:InferenceLock")
                wakeLock?.acquire(30 * 60 * 1000L) // 30 min max
            }
        } catch (_: Exception) {}
    }

    override fun onPause() {
        super.onPause()
        // Signal to background processor: app going to background, take over
        if (ringBle.isBackgroundProcessorInitialized()) ringBle.backgroundProcessor.onAppBackground()
        wakeLock?.release()
        wakeLock = null
    }

    override fun onDestroy() {
        ringBle.disconnect()
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // ── Wire Zero Ring BLE Channels ─────────────────────────────────────────
        val bleMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.zero_ring/ble")
        val bleEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.zero_ring/ble_events")
        ringBle.setupChannels(bleMethodChannel, bleEventChannel)

        // ── Wire Ring STT Channels (ring PCM → ParcelFD pipe → SpeechRecognizer) ──
        val sttMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.zero_ring/stt")
        val sttEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.zero_ring/stt_events")
        ringStt.setupMethodChannel(sttMethodChannel)
        ringStt.setupEventChannel(sttEventChannel)

        // ── Init background ring processor (handles pipeline when screen is off) ──
        ringBle.backgroundProcessor = BackgroundRingProcessor(this, ringBle)
        ringBle.ringStt = ringStt

        // Handle cold boot trigger
        if (intent?.getBooleanExtra("wake_live_voice", false) == true) {
            methodChannel?.invokeMethod("wake_live_voice", null)
            intent?.removeExtra("wake_live_voice")
        }
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // ─── HARDWARE ─────────────────────────────────────────────
                "toggle_torch" -> {
                    val state = call.argument<Boolean>("state") ?: false
                    toggleTorch(state, result)
                }
                "toggle_wifi" -> openWifiSettings(result)
                "toggle_bluetooth" -> openBluetoothSettings(result)
                "set_bluetooth" -> {
                    val state = call.argument<String>("state") ?: "on"
                    setBluetooth(state, result)
                }
                "set_brightness" -> {
                    val level = call.argument<Int>("level") ?: 128
                    setBrightness(level, result)
                }
                "set_volume" -> {
                    val level = call.argument<Int>("level") ?: 7
                    setVolume(level, result)
                }
                "take_screenshot" -> takeScreenshot(result)
                "take_photo" -> {
                    val front = call.argument<Boolean>("front") ?: false
                    takePhoto(front, result)
                }
                "take_photo_timed" -> {
                    val front = call.argument<Boolean>("front") ?: false
                    val delayMs = call.argument<Int>("delay_ms") ?: 2000
                    takePhotoTimed(front, delayMs.toLong(), result)
                }
                "start_recording" -> startRecording(result)
                "stop_recording" -> stopRecording(result)
                // ─── TIMERS / ALARMS ──────────────────────────────────────
                "set_timer" -> {
                    val duration = call.argument<Int>("duration_minutes") ?: 1
                    setTimer(duration, result)
                }
                "set_alarm" -> {
                    val title = call.argument<String>("title") ?: "Alarm"
                    val hour = call.argument<Int>("hour") ?: 8
                    val minute = call.argument<Int>("minute") ?: 0
                    setAlarm(title, hour, minute, result)
                }
                "set_reminder" -> {
                    val title = call.argument<String>("title") ?: "Reminder"
                    val offset = call.argument<Int>("time_offset_minutes") ?: 10
                    setReminder(title, offset, result)
                }

                // ─── COMMUNICATION ────────────────────────────────────────
                "send_email" -> {
                    val to = call.argument<String>("to") ?: ""
                    val subject = call.argument<String>("subject") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    sendEmail(to, subject, body, result)
                }
                "send_whatsapp_message" -> {
                    val contact = call.argument<String>("contact_name") ?: ""
                    val message = call.argument<String>("message_body") ?: ""
                    sendWhatsAppMessage(contact, message, result)
                }
                "make_call" -> {
                    val contact = call.argument<String>("contact") ?: ""
                    makeCall(contact, result)
                }
                "send_sms" -> {
                    val contact = call.argument<String>("contact") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    sendSms(contact, message, result)
                }

                // ─── BROWSER / NAVIGATION ─────────────────────────────────
                "open_browser" -> {
                    val url = call.argument<String>("url") ?: "https://google.com"
                    openBrowser(url, result)
                }
                "open_maps" -> {
                    val query = call.argument<String>("query") ?: ""
                    openMaps(query, result)
                }

                // ─── APP LAUNCHER ─────────────────────────────────────────
                "launch_app" -> {
                    val appName = call.argument<String>("app_name") ?: ""
                    launchApp(appName, result)
                }
                "request_assistant_role" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
                        if (roleManager.isRoleAvailable(RoleManager.ROLE_ASSISTANT)) {
                            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_ASSISTANT)
                            startActivityForResult(intent, REQUEST_CODE_ASSISTANT)
                            result.success(true)
                        } else {
                            result.error("UNAVAILABLE", "Assistant role not available", null)
                        }
                    } else {
                        // On Android 9 and below, this requires manual intent to settings
                        val intent = Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    }
                }

                // ─── SYSTEM ───────────────────────────────────────────────
                "airplane_mode_status" -> {
                    try {
                        val isAirplaneModeOn = Settings.Global.getInt(
                            contentResolver,
                            Settings.Global.AIRPLANE_MODE_ON, 0
                        ) != 0
                        result.success(isAirplaneModeOn)
                    } catch (e: Exception) {
                        result.error("AIRPLANE_MODE_ERROR", e.message, null)
                    }
                }
                "open_settings" -> {
                    val setting = call.argument<String>("setting") ?: "main"
                    openSettings(setting, result)
                }
                "share_text" -> {
                    val text = call.argument<String>("text") ?: ""
                    shareText(text, result)
                }
                "open_calendar" -> {
                    val title = call.argument<String>("title") ?: ""
                    openCalendar(title, result)
                }
                "open_contacts" -> openContacts(result)
                
                "save_document" -> {
                    val filename = call.argument<String>("filename") ?: "document.txt"
                    val content = call.argument<String>("content") ?: ""
                    saveDocument(filename, content, result)
                }

                // ─── UI AUTOMATE ──────────────────────────────────────────
                "ui_automate_dump_tree" -> {
                    val service = AccessibilityBridge.service
                    if (service != null) {
                        result.success(service.dumpTree())
                    } else {
                        result.error("NO_SERVICE", "Accessibility service not running/enabled", null)
                    }
                }
                "ui_automate_perform_action" -> {
                    val service = AccessibilityBridge.service
                    val action = call.argument<String>("action") ?: ""
                    if (service != null) {
                        val success = service.performAction(action)
                        result.success(success)
                    } else {
                        result.error("NO_SERVICE", "Accessibility service not running/enabled", null)
                    }
                }

                // ─── MUSIC / MEDIA ────────────────────────────────────────
                "play_spotify" -> {
                    val query = call.argument<String>("query") ?: ""
                    playSpotify(query, result)
                }
                "play_youtube" -> {
                    val query = call.argument<String>("query") ?: ""
                    playYouTube(query, result)
                }

                // ─── FILE SHARE ───────────────────────────────────────────
                "share_file" -> {
                    val path = call.argument<String>("path") ?: ""
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    shareFile(path, mime, result)
                }

                // ─── HTML RENDER (signals Flutter UI to open WebView) ─────
                "render_html" -> {
                    // The actual rendering is handled by the Flutter layer.
                    // This just acknowledges the call; channel is used as a
                    // signal path from the tool back to the UI.
                    result.success(true)
                }

                // ─── PERMISSIONS HELPERS ──────────────────────────────────
                "check_write_settings" -> {
                    result.success(Settings.System.canWrite(this))
                }
                "open_write_settings" -> {
                    val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                }
                "open_dnd_settings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "check_accessibility_enabled" -> {
                    val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
                    val services = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
                    val enabled = services.any { it.id.contains(packageName) }
                    result.success(enabled)
                }
                "open_accessibility_settings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }

                // ── PERFORMANCE ──────────────────────────────────────────
                "force_performance_mode" -> {
                    try {
                        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
                        if (wakeLock?.isHeld == false) {
                            wakeLock?.acquire(30 * 60 * 1000L)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // Zero Ring BLE channels wired above in configureFlutterEngine
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HARDWARE
    // ═══════════════════════════════════════════════════════════════════════════

    private fun toggleTorch(state: Boolean, result: MethodChannel.Result) {
        try {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList[0]
            cameraManager.setTorchMode(cameraId, state)
            result.success(true)
        } catch (e: Exception) {
            result.error("TORCH_ERROR", e.message, null)
        }
    }

    private fun openWifiSettings(result: MethodChannel.Result) {
        try {
            // Android 10+ — use settings panel (cannot silently toggle)
            val intent = Intent(Settings.Panel.ACTION_WIFI)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                startActivity(intent)
                result.success(true)
            } catch (e2: Exception) {
                result.error("WIFI_ERROR", e2.message, null)
            }
        }
    }

    private fun openBluetoothSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("BT_ERROR", e.message, null)
        }
    }

    private fun setBluetooth(state: String, result: MethodChannel.Result) {
        try {
            if (state.lowercase() == "on") {
                val intent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                startActivity(intent)
                result.success(true)
            } else {
                // Programmatic bluetooth disable is highly restricted on modern Android.
                // Fallback to settings.
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                startActivity(intent)
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("BT_ERROR", e.message, null)
        }
    }

    private fun setBrightness(level: Int, result: MethodChannel.Result) {
        try {
            // Check if we have WRITE_SETTINGS permission
            if (!Settings.System.canWrite(this)) {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                result.success(false) // User needs to grant permission first
                return
            }
            Settings.System.putInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
            )
            Settings.System.putInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
                level.coerceIn(0, 255)
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("BRIGHTNESS_ERROR", e.message, null)
        }
    }

    private fun setVolume(level: Int, result: MethodChannel.Result) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val targetVol = (level.coerceIn(0, 15) * maxVol / 15)
            audioManager.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                targetVol,
                AudioManager.FLAG_SHOW_UI
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("VOLUME_ERROR", e.message, null)
        }
    }

    private fun takeScreenshot(result: MethodChannel.Result) {
        try {
            // On Android 9+ with Accessibility Service active, we can use
            // GLOBAL_ACTION_TAKE_SCREENSHOT via the accessibility service
            val service = AccessibilityBridge.service
            if (service != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    service.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_TAKE_SCREENSHOT)
                    result.success(true)
                    return
                }
            }
            // Fallback: tell user to use hardware buttons
            result.success(false)
        } catch (e: Exception) {
            result.error("SCREENSHOT_ERROR", "Use power + volume down to take a screenshot", null)
        }
    }

    private fun takePhotoTimed(front: Boolean, delayMs: Long, result: MethodChannel.Result) {
        try {
            val intent = Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
            if (front) {
                intent.putExtra("android.intent.extras.CAMERA_FACING", 1)
                intent.putExtra("android.intent.extra.USE_FRONT_CAMERA", true)
            }
            startActivity(intent)
            result.success(true)
            // After camera opens, click shutter via Accessibility after delay
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    val service = AccessibilityBridge.service
                    if (service != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        // Find and click shutter button using accessibility
                        val root = service.rootInActiveWindow
                        if (root != null) {
                            val shutterIds = listOf(
                                "com.google.android.GoogleCamera:id/shutter_button",
                                "com.android.camera:id/shutter_button",
                                "com.android.camera2:id/shutter_button",
                                "com.samsung.android.camera:id/shutter_button",
                                "com.oneplus.camera:id/shutter_button"
                            )
                            var clicked = false
                            for (id in shutterIds) {
                                val nodes = root.findAccessibilityNodeInfosByViewId(id)
                                if (nodes != null && nodes.isNotEmpty()) {
                                    nodes[0].performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK)
                                    clicked = true
                                    break
                                }
                            }
                            if (!clicked) {
                                // Fallback: try finding any clickable button labelled "shutter" or with camera description
                                // Do nothing extra — camera stays open for user
                            }
                        }
                    }
                } catch (_: Exception) { /* silent — camera stays open */ }
            }, delayMs)
        } catch (e: Exception) {
            result.error("CAMERA_ERROR", e.message, null)
        }
    }

    private fun takePhoto(front: Boolean, result: MethodChannel.Result) {
        try {
            val intent = Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
            if (front) {
                // Best-effort hints for front camera
                intent.putExtra("android.intent.extras.CAMERA_FACING", 1)
                intent.putExtra("android.intent.extra.USE_FRONT_CAMERA", true)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CAMERA_ERROR", e.message, null)
        }
    }

    private var mediaRecorder: android.media.MediaRecorder? = null
    private var recordingFile: File? = null

    private fun startRecording(result: MethodChannel.Result) {
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(android.Manifest.permission.RECORD_AUDIO), 101)
            result.error("PERMISSION_DENIED", "Please try again after granting microphone permission", null)
            return
        }
        try {
            if (mediaRecorder != null) {
                result.success(true)
                return
            }
            recordingFile = File(cacheDir, "zero_recording_${System.currentTimeMillis()}.3gp")
            mediaRecorder = android.media.MediaRecorder().apply {
                setAudioSource(android.media.MediaRecorder.AudioSource.MIC)
                setOutputFormat(android.media.MediaRecorder.OutputFormat.THREE_GPP)
                setOutputFile(recordingFile!!.absolutePath)
                setAudioEncoder(android.media.MediaRecorder.AudioEncoder.AMR_NB)
                prepare()
                start()
            }
            result.success(true)
        } catch (e: Exception) {
            mediaRecorder?.release()
            mediaRecorder = null
            result.error("RECORD_ERROR", e.message, null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        try {
            if (mediaRecorder != null) {
                mediaRecorder?.stop()
                mediaRecorder?.release()
                mediaRecorder = null
            }
            result.success(recordingFile?.absolutePath)
        } catch (e: Exception) {
            mediaRecorder = null
            result.error("RECORD_ERROR", e.message, null)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // TIMERS / ALARMS
    // ═══════════════════════════════════════════════════════════════════════════

    private fun setTimer(durationMinutes: Int, result: MethodChannel.Result) {
        try {
            val seconds = durationMinutes * 60
            val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
                putExtra(AlarmClock.EXTRA_MESSAGE, "Zero Timer")
                putExtra(AlarmClock.EXTRA_LENGTH, seconds)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("TIMER_ERROR", e.message, null)
        }
    }

    private fun setAlarm(title: String, hour: Int, minute: Int, result: MethodChannel.Result) {
        try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_MESSAGE, title)
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ALARM_ERROR", e.message, null)
        }
    }

    private fun setReminder(title: String, offsetMinutes: Int, result: MethodChannel.Result) {
        try {
            val cal = java.util.Calendar.getInstance()
            cal.add(java.util.Calendar.MINUTE, offsetMinutes)
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_MESSAGE, title)
                putExtra(AlarmClock.EXTRA_HOUR, cal.get(java.util.Calendar.HOUR_OF_DAY))
                putExtra(AlarmClock.EXTRA_MINUTES, cal.get(java.util.Calendar.MINUTE))
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("REMINDER_ERROR", e.message, null)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // COMMUNICATION
    // ═══════════════════════════════════════════════════════════════════════════

    private fun sendEmail(to: String, subject: String, body: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("mailto:$to")
                putExtra(Intent.EXTRA_SUBJECT, subject)
                putExtra(Intent.EXTRA_TEXT, body)
            }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                // Fallback: ACTION_SEND targeting email apps
                val fallback = Intent(Intent.ACTION_SEND).apply {
                    type = "message/rfc822"
                    putExtra(Intent.EXTRA_EMAIL, arrayOf(to))
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                    putExtra(Intent.EXTRA_TEXT, body)
                }
                startActivity(Intent.createChooser(fallback, "Send email via"))
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("EMAIL_ERROR", e.message, null)
        }
    }

    private fun resolveContactNumber(name: String): String? {
        if (checkSelfPermission(android.Manifest.permission.READ_CONTACTS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            return null
        }
        try {
            val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
            val projection = arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
            val selectionArgs = arrayOf("%$name%")
            contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val numIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    if (numIndex != -1) {
                        return cursor.getString(numIndex)
                    }
                }
            }
        } catch (e: Exception) { }
        return null
    }

    private fun sendWhatsAppMessage(contact: String, message: String, result: MethodChannel.Result) {
        try {
            var numberToDial = contact
            val initialClean = contact.replace(Regex("[^0-9+]"), "")
            if (initialClean.length < 7) {
                val resolvedNumber = resolveContactNumber(contact)
                if (resolvedNumber != null) numberToDial = resolvedNumber
            }
            
            // Try wa.me link first if contact looks like a phone number
            val cleanNumber = numberToDial.replace(Regex("[^0-9+]"), "")
            if (cleanNumber.length >= 10) {
                val number = if (cleanNumber.startsWith("+")) cleanNumber else "+91$cleanNumber"
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    data = Uri.parse("https://wa.me/${number.replace("+", "")}?text=${Uri.encode(message)}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } else {
                // Generic share to WhatsApp
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    setPackage("com.whatsapp")
                    putExtra(Intent.EXTRA_TEXT, message)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("WHATSAPP_ERROR", "WhatsApp not installed or error: ${e.message}", null)
        }
    }

    private fun makeCall(contact: String, result: MethodChannel.Result) {
        try {
            var numberToDial = contact
            val initialClean = contact.replace(Regex("[^0-9+]"), "")
            if (initialClean.length < 7) {
                val resolvedNumber = resolveContactNumber(contact)
                if (resolvedNumber != null) numberToDial = resolvedNumber
            }

            val cleanNumber = numberToDial.replace(Regex("[^0-9+]"), "")
            val uri = if (cleanNumber.length >= 7) {
                Uri.parse("tel:$cleanNumber")
            } else {
                Uri.parse("tel:$numberToDial")
            }
            // ACTION_CALL requires CALL_PHONE permission — directly dials without user
            // confirmation if permission was granted at startup.
            val intent = Intent(Intent.ACTION_CALL, uri)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            // Fallback to ACTION_DIAL (shows dialer UI) if permission denied
            try {
                val uri = Uri.parse("tel:$contact")
                startActivity(Intent(Intent.ACTION_DIAL, uri))
                result.success(false) // false = required user to confirm
            } catch (e2: Exception) {
                result.error("CALL_ERROR", e2.message, null)
            }
        }
    }

    private fun sendSms(contact: String, message: String, result: MethodChannel.Result) {
        try {
            var numberToDial = contact
            val initialClean = contact.replace(Regex("[^0-9+]"), "")
            if (initialClean.length < 7) {
                val resolvedNumber = resolveContactNumber(contact)
                if (resolvedNumber != null) numberToDial = resolvedNumber
            }
            
            val cleanNumber = numberToDial.replace(Regex("[^0-9+]"), "")
            if (cleanNumber.length >= 7) {
                // Direct send via SmsManager (no user confirmation needed if SEND_SMS granted)
                @Suppress("DEPRECATION")
                val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    this.getSystemService(SmsManager::class.java)
                } else {
                    SmsManager.getDefault()
                }
                // Split long messages automatically
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(cleanNumber, null, parts, null, null)
                result.success(true)
            } else {
                // Contact name — open SMS app pre-filled
                val intent = Intent(Intent.ACTION_SENDTO).apply {
                    data = Uri.parse("smsto:$cleanNumber")
                    putExtra("sms_body", message)
                }
                startActivity(intent)
                result.success(false) // false = user still needs to tap send
            }
        } catch (e: Exception) {
            // Fallback to SMS app
            try {
                val intent = Intent(Intent.ACTION_SENDTO).apply {
                    data = Uri.parse("smsto:$contact")
                    putExtra("sms_body", message)
                }
                startActivity(intent)
                result.success(false)
            } catch (e2: Exception) {
                result.error("SMS_ERROR", e2.message, null)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BROWSER / NAVIGATION
    // ═══════════════════════════════════════════════════════════════════════════

    private fun openBrowser(url: String, result: MethodChannel.Result) {
        try {
            var fixedUrl = url.trim()
            if (!fixedUrl.startsWith("http://") && !fixedUrl.startsWith("https://") && !fixedUrl.startsWith("spotify:")) {
                fixedUrl = "https://$fixedUrl"
            }
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(fixedUrl)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("BROWSER_ERROR", e.message, null)
        }
    }

    private fun openMaps(query: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse("geo:0,0?q=${Uri.encode(query)}")
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage("com.google.android.apps.maps")
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
            } else {
                // Fallback: open in browser
                val webIntent = Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://maps.google.com/maps?q=${Uri.encode(query)}"))
                startActivity(webIntent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("MAPS_ERROR", e.message, null)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // APP LAUNCHER
    // ═══════════════════════════════════════════════════════════════════════════

    private fun launchApp(appName: String, result: MethodChannel.Result) {
        try {
            val pm = packageManager
            val lowerName = appName.lowercase().trim()

            // 0. Well-known package mappings for 100% reliability
            val wellKnown = mapOf(
                "youtube" to "com.google.android.youtube",
                "yt" to "com.google.android.youtube",
                "whatsapp" to "com.whatsapp",
                "spotify" to "com.spotify.music",
                "chrome" to "com.android.chrome",
                "google" to "com.google.android.googlequicksearchbox",
                "maps" to "com.google.android.apps.maps",
                "google maps" to "com.google.android.apps.maps",
                "gmail" to "com.google.android.gm",
                "instagram" to "com.instagram.android",
                "insta" to "com.instagram.android",
                "camera" to "com.google.android.GoogleCamera",
                "photos" to "com.google.android.apps.photos",
                "gallery" to "com.google.android.apps.photos",
                "settings" to "com.android.settings",
                "calculator" to "com.google.android.calculator",
                "clock" to "com.google.android.deskclock",
                "calendar" to "com.google.android.calendar",
                "contacts" to "com.google.android.contacts",
                "telegram" to "org.telegram.messenger",
                "netflix" to "com.netflix.ninja",
                "facebook" to "com.facebook.katana",
                "twitter" to "com.twitter.android",
                "x" to "com.twitter.android"
            )

            val knownPkg = wellKnown[lowerName]
            if (knownPkg != null) {
                val intent = pm.getLaunchIntentForPackage(knownPkg)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                    return
                }
            }

            // 1. Search all installed applications
            val allApps = pm.getInstalledApplications(android.content.pm.PackageManager.GET_META_DATA)

            // 1a. Exact match
            var found = allApps.firstOrNull {
                pm.getApplicationLabel(it).toString().equals(lowerName, ignoreCase = true)
            }
            // 1b. Starts-with match
            if (found == null) {
                found = allApps.firstOrNull {
                    pm.getApplicationLabel(it).toString().lowercase().startsWith(lowerName)
                }
            }
            // 1c. Contains match
            if (found == null) {
                found = allApps.firstOrNull {
                    pm.getApplicationLabel(it).toString().lowercase().contains(lowerName)
                }
            }

            if (found != null) {
                val intent = pm.getLaunchIntentForPackage(found.packageName)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                    return
                }
            }

            // 2. Website detection: if name contains a domain extension (.com, .org, etc.) or starts with http
            val domainRegex = Regex("""([a-zA-Z0-9\-]+\.(?:com|org|net|io|in|co|gov|edu|ai|app|me))""", RegexOption.IGNORE_CASE)
            val domainMatch = domainRegex.find(lowerName)
            if (domainMatch != null || lowerName.startsWith("http://") || lowerName.startsWith("https://")) {
                val rawUrl = if (domainMatch != null) domainMatch.value else lowerName
                val fixedUrl = if (rawUrl.startsWith("http://") || rawUrl.startsWith("https://")) rawUrl else "https://$rawUrl"
                val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse(fixedUrl)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(webIntent)
                result.success(true)
                return
            }

            // 3. Fallback: Search Google for the requested term
            val browserUrl = "https://www.google.com/search?q=${Uri.encode(appName)}"
            val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse(browserUrl)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(webIntent)
            result.success(true)
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SYSTEM
    // ═══════════════════════════════════════════════════════════════════════════

    private fun openSettings(setting: String, result: MethodChannel.Result) {
        try {
            // Tethering: handled separately because it needs early return
            if (setting.lowercase() == "tethering") {
                try {
                    val intent = Intent()
                    intent.setClassName("com.android.settings", "com.android.settings.TetherSettings")
                    startActivity(intent)
                } catch (_: Exception) {
                    val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                    startActivity(intent)
                }
                result.success(true)
                return
            }

            val action = when (setting.lowercase()) {
                "wifi" -> Settings.ACTION_WIFI_SETTINGS
                "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                "display" -> Settings.ACTION_DISPLAY_SETTINGS
                "sound" -> Settings.ACTION_SOUND_SETTINGS
                "battery" -> Settings.ACTION_BATTERY_SAVER_SETTINGS
                "storage" -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS
                "apps" -> Settings.ACTION_APPLICATION_SETTINGS
                "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
                "security" -> Settings.ACTION_SECURITY_SETTINGS
                "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
                "date" -> Settings.ACTION_DATE_SETTINGS
                "language" -> Settings.ACTION_LOCALE_SETTINGS
                "developer" -> Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS
                "nfc" -> Settings.ACTION_NFC_SETTINGS
                "airplane" -> Settings.ACTION_AIRPLANE_MODE_SETTINGS
                "data" -> Settings.ACTION_DATA_USAGE_SETTINGS
                "notification" -> Settings.ACTION_APP_NOTIFICATION_SETTINGS
                else -> Settings.ACTION_SETTINGS
            }
            val intent = Intent(action)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SETTINGS_ERROR", e.message, null)
        }
    }

    private fun shareText(text: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(intent, "Share via"))
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE_ERROR", e.message, null)
        }
    }

    private fun openCalendar(title: String, result: MethodChannel.Result) {
        try {
            if (title.isNotEmpty()) {
                // Create new event
                val intent = Intent(Intent.ACTION_INSERT).apply {
                    data = CalendarContract.Events.CONTENT_URI
                    putExtra(CalendarContract.Events.TITLE, title)
                }
                startActivity(intent)
            } else {
                // Just open calendar
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    data = CalendarContract.CONTENT_URI
                }
                startActivity(intent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("CALENDAR_ERROR", e.message, null)
        }
    }

    private fun openContacts(result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = ContactsContract.Contacts.CONTENT_URI
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CONTACTS_ERROR", e.message, null)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // MUSIC / MEDIA — spec §6.1
    // ═══════════════════════════════════════════════════════════════════════════

    private fun playYouTube(query: String, result: MethodChannel.Result) {
        try {
            val ytIntent = Intent(Intent.ACTION_SEARCH).apply {
                setPackage("com.google.android.youtube")
                putExtra("query", query)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (ytIntent.resolveActivity(packageManager) != null) {
                startActivity(ytIntent)
                result.success(true)
            } else {
                val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=${Uri.encode(query)}")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(webIntent)
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("YOUTUBE_ERROR", e.message, null)
        }
    }

    private fun playSpotify(query: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH)
            intent.putExtra(MediaStore.EXTRA_MEDIA_FOCUS, "vnd.android.cursor.item/*")
            intent.putExtra(SearchManager.QUERY, query)
            intent.setPackage("com.spotify.music")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                playYouTube(query, result)
            }
        } catch (e: Exception) {
            result.error("SPOTIFY_ERROR", e.message, null)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FILE SHARE — spec §7.2/7.3 (FileProvider for Android 7+ content:// URI)
    // ═══════════════════════════════════════════════════════════════════════════

    private fun shareFile(path: String, mimeType: String, result: MethodChannel.Result) {
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "File not found: $path", null)
                return
            }
            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Share file via"))
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE_ERROR", e.message, null)
        }
    }

    private fun saveDocument(filename: String, content: String, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = contentResolver
                val contentValues = android.content.ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, filename)
                    put(MediaStore.Downloads.MIME_TYPE, "text/markdown")
                    put(MediaStore.Downloads.RELATIVE_PATH, android.os.Environment.DIRECTORY_DOWNLOADS + "/ZeroSearch")
                }
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { 
                        it.write(content.toByteArray())
                    }
                    val path = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS).absolutePath + "/ZeroSearch/" + filename
                    result.success(path)
                } else {
                    result.error("SAVE_FAILED", "Failed to insert into MediaStore", null)
                }
            } else {
                val downloads = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
                val dir = File(downloads, "ZeroSearch")
                if (!dir.exists()) dir.mkdirs()
                val file = File(dir, filename)
                file.writeText(content)
                result.success(file.absolutePath)
            }
        } catch (e: Exception) {
            result.error("SAVE_ERROR", e.message, null)
        }
    }
}
