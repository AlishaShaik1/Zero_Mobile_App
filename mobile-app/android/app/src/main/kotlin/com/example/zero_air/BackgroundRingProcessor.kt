package com.example.zero_air

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * BackgroundRingProcessor — rebuilt FROM SCRATCH (voice transfer only).
 *
 * Handles the full ring → phone voice pipeline entirely in Kotlin/native when
 * the Flutter app is backgrounded (screen off, app minimized):
 *
 *   Ring mic audio (0xFF marker, PCM chunks, 0xFE marker) via BLE
 *     → collect PCM natively
 *     → cloud STT (Deepgram REST — NO Android SpeechRecognizer, so there is
 *       no "speech service not installed" failure mode)
 *     → Fireworks GLM-5P3-Flash REST (OkHttp)
 *     → short reply caption → ring OLED via BLE
 *
 * When the app is in FOREGROUND: this class does nothing — the Dart
 * RingAudioPipeline owns the voice transfer (same protocol, same STT).
 *
 * Everything else (BLE connection, camera, captions) is untouched.
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
        private const val MAX_SPEECH_BYTES = 960000  // 30s maximum
        private const val SILENCE_TIMEOUT_MS = 2500L

        // Deepgram cloud STT — two keys tried in order (same as Dart side),
        // so one expired key cannot kill the feature.
        private val DEEPGRAM_KEYS = listOf(
            "bf8e5c0fbe1d38a88cda424c00213dc8e0e70fc0",
            "36dd865f774bfe84b2044e54f9b7c3f175a10634"
        )
        private val DEEPGRAM_MODELS = listOf("nova-3", "nova-2")

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
        .readTimeout(25, TimeUnit.SECONDS)
        .build()

    // ── State ─────────────────────────────────────────────────────────────────
    @Volatile var isAppForeground = true  // set by MainActivity lifecycle
    @Volatile private var isCollecting  = false
    @Volatile private var isProcessing  = false

    private val pcmBuffer = java.io.ByteArrayOutputStream()
    private var silenceTimer: Runnable? = null
    private var finalTranscript = ""
    private val transcriptLock = Object()

    // Wake lock to keep CPU alive during background processing
    private var wakeLock: PowerManager.WakeLock? = null

    // ── App foreground/background tracking ────────────────────────────────────

    fun onAppForeground() { isAppForeground = true }
    fun onAppBackground()  { isAppForeground = false }

    // ── Called by RingBleHandler for every ring mic chunk ─────────────────────

    /**
     * Route a BLE audio notification.
     * If app is foreground → Dart pipeline handles it (return immediately).
     * If app is background → we handle the whole voice transfer natively here.
     */
    fun onAudioChunk(bytes: ByteArray) {
        if (isAppForeground) return  // Dart handles it

        // 0xFF = start marker
        if (bytes.size == 1 && bytes[0] == 0xFF.toByte()) {
            if (!isCollecting && !isProcessing) {
                Log.i(TAG, "Background: ring mic START — collecting PCM")
                startBackgroundListening()
            }
            return
        }

        // 0xFE = stop marker
        if (bytes.size == 1 && bytes[0] == 0xFE.toByte()) {
            if (isCollecting) {
                Log.i(TAG, "Background: ring mic STOP — transcribing")
                triggerFinalize()
            }
            return
        }

        if (!isCollecting || bytes.isEmpty()) return

        synchronized(pcmBuffer) { pcmBuffer.write(bytes) }
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
        finalTranscript = ""
        synchronized(pcmBuffer) { pcmBuffer.reset() }

        // Immediate feedback on the ring OLED
        ringBle.writeCaption("Listening...")
    }

    private fun resetSilenceTimer() {
        silenceTimer?.let { mainHandler.removeCallbacks(it) }
        val r = Runnable {
            val buffered = synchronized(pcmBuffer) { pcmBuffer.size() }
            if (isCollecting && buffered >= MIN_SPEECH_BYTES) {
                Log.i(TAG, "Background silence detected → finalizing ($buffered bytes)")
                triggerFinalize()
            }
        }
        silenceTimer = r
        mainHandler.postDelayed(r, SILENCE_TIMEOUT_MS)
    }

    private fun triggerFinalize() {
        if (!isCollecting) return  // idempotent
        isCollecting = false
        silenceTimer?.let { mainHandler.removeCallbacks(it) }
        silenceTimer = null

        val pcm = synchronized(pcmBuffer) { pcmBuffer.toByteArray() }
        if (pcm.size < MIN_SPEECH_BYTES) {
            Log.i(TAG, "Background: only ${pcm.size} bytes — too short, ignoring")
            releaseWakeLock()
            return
        }

        Log.i(TAG, "Background: ${pcm.size} bytes PCM → Deepgram REST")
        executor.submit {
            try {
                val transcript = transcribeWithDeepgram(pcm)
                synchronized(transcriptLock) { finalTranscript = transcript }
                processTranscript()
            } catch (e: Exception) {
                Log.e(TAG, "Background pipeline error: ${e.message}", e)
                ringBle.writeCaption("Error: try again")
                isProcessing = false
                releaseWakeLock()
            }
        }
    }

    // ── Cloud STT (no on-device speech service needed) ────────────────────────

    /** Wrap raw 16 kHz mono 16-bit LE PCM in a 44-byte WAV header. */
    private fun buildWav(pcm: ByteArray): ByteArray {
        val dataSize = pcm.size
        val out = ByteArray(44 + dataSize)
        out[0] = 'R'.code.toByte(); out[1] = 'I'.code.toByte()
        out[2] = 'F'.code.toByte(); out[3] = 'F'.code.toByte()
        val bb = ByteBuffer.wrap(out).order(ByteOrder.LITTLE_ENDIAN)
        bb.putInt(4, 36 + dataSize)
        out[8] = 'W'.code.toByte(); out[9] = 'A'.code.toByte()
        out[10] = 'V'.code.toByte(); out[11] = 'E'.code.toByte()
        out[12] = 'f'.code.toByte(); out[13] = 'm'.code.toByte()
        out[14] = 't'.code.toByte(); out[15] = ' '.code.toByte()
        bb.putInt(16, 16)                     // fmt chunk size
        bb.putShort(20, 1.toShort())          // PCM format
        bb.putShort(22, 1.toShort())          // mono
        bb.putInt(24, SAMPLE_RATE)
        bb.putInt(28, SAMPLE_RATE * BYTES_PER_SAMPLE)
        bb.putShort(32, BYTES_PER_SAMPLE.toShort())
        bb.putShort(34, 16.toShort())         // bits per sample
        out[36] = 'd'.code.toByte(); out[37] = 'a'.code.toByte()
        out[38] = 't'.code.toByte(); out[39] = 'a'.code.toByte()
        bb.putInt(40, dataSize)
        pcm.copyInto(out, 44)
        return out
    }

    /** POST WAV to Deepgram; tries keys × models in order. Empty on failure. */
    private fun transcribeWithDeepgram(pcm: ByteArray): String {
        val wav = buildWav(pcm)
        for (key in DEEPGRAM_KEYS) {
            for (model in DEEPGRAM_MODELS) {
                try {
                    val request = Request.Builder()
                        .url(
                            "https://api.deepgram.com/v1/listen?model=${model}" +
                                "&smart_format=true&language=en-US"
                        )
                        .addHeader("Authorization", "Token $key")
                        .addHeader("Content-Type", "audio/wav")
                        .post(wav.toRequestBody("audio/wav".toMediaType()))
                        .build()
                    val resp = httpClient.newCall(request).execute()
                    val body = resp.body?.string() ?: ""
                    if (resp.isSuccessful) {
                        val text = JSONObject(body)
                            .optJSONObject("results")
                            ?.optJSONArray("channels")?.optJSONObject(0)
                            ?.optJSONArray("alternatives")?.optJSONObject(0)
                            ?.optString("transcript")?.trim() ?: ""
                        Log.i(TAG, "Deepgram transcript (key ok, $model): \"$text\"")
                        return text
                    }
                    Log.w(TAG, "Deepgram HTTP ${resp.code}: ${body.take(200)}")
                } catch (e: Exception) {
                    Log.w(TAG, "Deepgram error: ${e.message}")
                }
            }
        }
        return ""
    }

    // ── GLM API call + caption write ──────────────────────────────────────────

    private fun processTranscript() {
        if (isProcessing) return
        isProcessing = true

        val transcript = synchronized(transcriptLock) { finalTranscript.trim() }
        if (transcript.isEmpty()) {
            Log.w(TAG, "Background: empty transcript — skipping")
            ringBle.writeCaption("Did not hear you")
            isProcessing = false
            releaseWakeLock()
            return
        }

        Log.i(TAG, "Background Transcript: \"$transcript\"")
        ringBle.writeCaption("Thinking...")

        executor.submit {
            try {
                val reply = callFireworksGlm(transcript)
                Log.i(TAG, "Background GLM reply: \"$reply\"")

                // Send caption to ring OLED
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
                wakeLock?.acquire(60_000L) // 60s max for one utterance
            }
        } catch (e: Exception) { Log.w(TAG, "WakeLock acquire failed: ${e.message}") }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }
}
