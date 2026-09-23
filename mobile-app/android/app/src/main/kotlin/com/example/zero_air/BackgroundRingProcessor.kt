package com.example.zero_air

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.content.Intent
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * BackgroundRingProcessor — Handles the full ring pipeline entirely in Kotlin/native
 * when the Flutter app is backgrounded (screen off, app minimized).
 *
 * Flow: Ring double-click (0xFF BLE marker)
 *   → collect PCM chunks from BLE
 *   → feed into Android SpeechRecognizer via ParcelFileDescriptor pipe (Android 13+)
 *   → NO phone mic, NO speaker output
 *   → transcript text → Fireworks GLM-5P3-Flash REST API (OkHttp)
 *   → short reply caption → write to ring OLED via BLE
 *   → optionally wake Flutter app to display in chat screen
 *
 * When app is in FOREGROUND: this class defers to Dart pipeline (does nothing).
 * When app is in BACKGROUND: this class handles everything natively.
 */
class BackgroundRingProcessor(
    private val context: Context,
    private val ringBle: RingBleHandler
) {
    companion object {
        private const val TAG = "BgRingProc"
        private const val SAMPLE_RATE = 16000
        private const val BYTES_PER_SAMPLE = 2
        private const val MIN_SPEECH_BYTES = 16000   // 0.5s minimum
        private const val MAX_SPEECH_BYTES = 480000  // 15s maximum
        private const val SILENCE_TIMEOUT_MS = 2500L

        private const val FW_API_KEY = "fw_3iUKfhBn2vryacJynHPsUU"
        private const val FW_MODEL   = "accounts/fireworks/models/glm-5p3-flash"
        private const val FW_URL     = "https://api.fireworks.ai/inference/v1/chat/completions"
        private const val SYSTEM_PROMPT =
            "You are Zero, a fast AI voice assistant on a smart ring. " +
            "Keep replies under 2 short sentences — it shows on a 64x32 OLED. " +
            "Be direct, no markdown, no emojis."
    }

    private val mainHandler  = Handler(Looper.getMainLooper())
    private val executor     = Executors.newSingleThreadExecutor()
    private val httpClient   = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    // ── State ─────────────────────────────────────────────────────────────────
    @Volatile var isAppForeground = true  // set by MainActivity lifecycle
    @Volatile private var isCollecting  = false
    @Volatile private var isProcessing  = false

    private val pcmBuffer = java.io.ByteArrayOutputStream()
    private var silenceTimer: Runnable? = null

    // STT (Android 13+)
    private var speechRecognizer: SpeechRecognizer? = null
    private var pipeFds: Array<ParcelFileDescriptor>? = null
    private var pipeOut: FileOutputStream? = null
    private var finalTranscript = ""
    private var partialTranscript = ""
    private val transcriptLock = Object()

    // Wake lock to keep CPU alive during background processing
    private var wakeLock: PowerManager.WakeLock? = null

    // ── App foreground/background tracking ───────────────────────────────────

    fun onAppForeground() { isAppForeground = true }
    fun onAppBackground()  { isAppForeground = false }

    // ── Called by RingBleHandler for every audio chunk ───────────────────────

    /**
     * Route a BLE audio notification.
     * Called from RingBleHandler.routeNotification when uuid == CHAR_MIC_AUDIO.
     * If app is foreground → Dart pipeline handles it (return immediately).
     * If app is background → we handle it natively here.
     */
    fun onAudioChunk(bytes: ByteArray) {
        if (isAppForeground) return  // Dart handles it

        // 0xFF = double-click start marker
        if (bytes.size == 1 && bytes[0] == 0xFF.toByte()) {
            if (!isCollecting && !isProcessing) {
                Log.i(TAG, "🔴 Background double-click: starting ring mic STT pipeline")
                startBackgroundListening()
            }
            return
        }

        // 0xFE = single-click stop marker
        if (bytes.size == 1 && bytes[0] == 0xFE.toByte()) {
            if (isCollecting) {
                Log.i(TAG, "🟡 Background single-click: finalizing speech")
                triggerFinalize()
            }
            return
        }

        if (!isCollecting || bytes.isEmpty()) return

        synchronized(pcmBuffer) {
            pcmBuffer.write(bytes)
        }

        // Feed into STT pipe at real-time rate
        feedPipe(bytes)

        // Push PCM to pipe for STT (real-time paced in executor)
        resetSilenceTimer()

        // Stop if exceeded max
        val buffered = synchronized(pcmBuffer) { pcmBuffer.size() }
        if (buffered >= MAX_SPEECH_BYTES) {
            Log.w(TAG, "Max speech length reached — finalizing")
            triggerFinalize()
        }
    }

    // ── Background pipeline ───────────────────────────────────────────────────

    private fun startBackgroundListening() {
        acquireWakeLock()
        isCollecting  = true
        isProcessing  = false
        finalTranscript   = ""
        partialTranscript = ""
        synchronized(pcmBuffer) { pcmBuffer.reset() }

        // Write THINKING status to ring OLED immediately
        ringBle.writeCaption("Listening...")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            startSttPipe()
        } else {
            // Android < 13: ParcelFD not supported; just collect PCM, skip STT
            Log.w(TAG, "Android < 13: skipping on-device STT, will use transcript from silence")
        }
    }

    private fun startSttPipe() {
        mainHandler.post {
            try {
                val fds = ParcelFileDescriptor.createPipe()
                pipeFds = fds
                pipeOut = FileOutputStream(fds[1].fileDescriptor)

                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                    setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(p: android.os.Bundle?) {
                            Log.d(TAG, "STT ready (background pipe)")
                        }
                        override fun onBeginningOfSpeech() {}
                        override fun onRmsChanged(rms: Float) {}
                        override fun onBufferReceived(buf: ByteArray?) {}
                        override fun onEndOfSpeech() { isCollecting = false }
                        override fun onError(err: Int) {
                            Log.e(TAG, "Background STT error: $err")
                            // Finalize with whatever partial we have
                            synchronized(transcriptLock) {
                                if (finalTranscript.isEmpty()) finalTranscript = partialTranscript
                            }
                            processTranscript()
                        }
                        override fun onResults(bundle: android.os.Bundle?) {
                            val list = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = list?.firstOrNull() ?: ""
                            Log.i(TAG, "Background STT final: \"$text\"")
                            synchronized(transcriptLock) { finalTranscript = text }
                            cleanupStt()
                            processTranscript()
                        }
                        override fun onPartialResults(bundle: android.os.Bundle?) {
                            val list = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = list?.firstOrNull() ?: ""
                            if (text.isNotEmpty()) {
                                Log.d(TAG, "Background STT partial: \"$text\"")
                                synchronized(transcriptLock) { partialTranscript = text }
                            }
                        }
                        override fun onEvent(t: Int, p: android.os.Bundle?) {}
                        override fun onSegmentResults(b: android.os.Bundle) {}
                        override fun onEndOfSegmentedSession() {}
                        override fun onLanguageDetection(b: android.os.Bundle) {}
                    })
                }

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, fds[0])
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, android.media.AudioFormat.ENCODING_PCM_16BIT)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, SAMPLE_RATE)
                }
                speechRecognizer?.startListening(intent)
                Log.d(TAG, "Background STT pipe started")
            } catch (e: Exception) {
                Log.e(TAG, "Background STT start failed: ${e.message}", e)
            }
        }
    }

    private fun feedPipe(pcm: ByteArray) {
        executor.submit {
            try {
                pipeOut?.write(pcm)
                pipeOut?.flush()
                // Real-time pacing
                val ms = (pcm.size.toLong() * 1000) / (SAMPLE_RATE * BYTES_PER_SAMPLE)
                if (ms > 0) Thread.sleep(ms)
            } catch (_: Exception) {}
        }
    }

    private fun resetSilenceTimer() {
        mainHandler.removeCallbacks(silenceTimerRunnable)
        mainHandler.postDelayed(silenceTimerRunnable, SILENCE_TIMEOUT_MS)
    }

    private val silenceTimerRunnable = Runnable {
        val buffered = synchronized(pcmBuffer) { pcmBuffer.size() }
        if (buffered >= MIN_SPEECH_BYTES) {
            Log.i(TAG, "Background silence detected → finalizing ($buffered bytes)")
            triggerFinalize()
        }
    }

    private fun triggerFinalize() {
        isCollecting = false
        mainHandler.removeCallbacks(silenceTimerRunnable)

        // Close write end → SpeechRecognizer sees EOF → fires onResults
        executor.submit {
            try {
                pipeOut?.close()
                pipeOut = null
                pipeFds?.getOrNull(1)?.close()
            } catch (_: Exception) {}
        }

        // Fallback: if no STT results in 6s, process with whatever partial we have
        mainHandler.postDelayed({
            val transcript = synchronized(transcriptLock) {
                if (finalTranscript.isEmpty()) partialTranscript else ""
            }
            if (transcript.isNotEmpty() && !isProcessing) {
                Log.w(TAG, "STT timeout fallback — using partial: \"$transcript\"")
                synchronized(transcriptLock) { finalTranscript = transcript }
                cleanupStt()
                processTranscript()
            }
        }, 6000)
    }

    private fun cleanupStt() {
        try { pipeOut?.close() } catch (_: Exception) {}
        try { pipeFds?.get(0)?.close() } catch (_: Exception) {}
        try { pipeFds?.get(1)?.close() } catch (_: Exception) {}
        pipeOut  = null
        pipeFds  = null
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }

    // ── GLM API call + caption write ─────────────────────────────────────────

    private fun processTranscript() {
        if (isProcessing) return
        isProcessing = true

        val transcript = synchronized(transcriptLock) { finalTranscript.trim() }
        if (transcript.isEmpty()) {
            Log.w(TAG, "Background: empty transcript — skipping")
            releaseWakeLock()
            isProcessing = false
            return
        }

        Log.i(TAG, "Background 🎤 Transcript: \"$transcript\"")
        ringBle.writeCaption("Thinking...")

        executor.submit {
            try {
                val reply = callFireworksGlm(transcript)
                Log.i(TAG, "Background 🤖 GLM reply: \"$reply\"")

                // Send caption to ring OLED (max 20 chars visible)
                val caption = if (reply.length > 60) reply.substring(0, 57) + "..." else reply
                ringBle.writeCaption(caption)

            } catch (e: Exception) {
                Log.e(TAG, "Background processing error: ${e.message}", e)
                ringBle.writeCaption("Error: try again")
            } finally {
                isProcessing = false
                releaseWakeLock()
            }
        }
    }

    private fun callFireworksGlm(query: String): String {
        val body = JSONObject().apply {
            put("model", FW_MODEL)
            put("max_tokens", 100)
            put("temperature", 0.7)
            put("presence_penalty", 0)
            put("frequency_penalty", 0)
            put("messages", org.json.JSONArray().apply {
                put(JSONObject().apply {
                    put("role", "system")
                    put("content", SYSTEM_PROMPT)
                })
                put(JSONObject().apply {
                    put("role", "user")
                    put("content", query)
                })
            })
        }.toString()

        val request = Request.Builder()
            .url(FW_URL)
            .addHeader("Authorization", "Bearer $FW_API_KEY")
            .addHeader("Content-Type", "application/json")
            .addHeader("Accept", "application/json")
            .post(body.toRequestBody("application/json".toMediaType()))
            .build()

        val resp = httpClient.newCall(request).execute()
        val respBody = resp.body?.string() ?: ""
        if (!resp.isSuccessful) {
            Log.e(TAG, "GLM API error ${resp.code}: $respBody")
            return "I couldn't process that."
        }

        val json = JSONObject(respBody)
        return json.getJSONArray("choices")
            .getJSONObject(0)
            .getJSONObject("message")
            .getString("content")
            .trim()
    }

    // ── Wake lock ─────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (wakeLock == null || wakeLock?.isHeld == false) {
                wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ZeroRing:BackgroundSTT")
                wakeLock?.acquire(30_000L) // 30s max for one utterance
            }
        } catch (e: Exception) { Log.w(TAG, "WakeLock acquire failed: ${e.message}") }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {}
    }
}
