package com.example.zero_air

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.FileOutputStream

/**
 * RingSttHandler v3 — Rate-Paced Pipe STT
 *
 * PROBLEM with file-based PFD: SpeechRecognizer reads the file too fast
 * (not at 16kHz real-time rate), so it sees a burst of audio with no temporal
 * context → ERROR_NO_MATCH or ERROR_SPEECH_TIMEOUT → empty transcript.
 *
 * SOLUTION — Rate-paced pipe:
 *   1. Dart sends full accumulated PCM bytes via stt_transcribe_pcm.
 *   2. Kotlin creates a ParcelFileDescriptor pipe.
 *   3. SpeechRecognizer gets the READ end via EXTRA_AUDIO_SOURCE.
 *   4. A background thread writes PCM to the WRITE end at exactly 16kHz
 *      real-time rate (3200 bytes per 100ms chunk with Thread.sleep(100ms)).
 *   5. SpeechRecognizer processes audio as if it were a live mic stream.
 *   6. onResults fires → transcript sent back to Dart via EventChannel.
 *
 * Web-confirmed: this rate-paced pipe approach is the ONLY reliable way
 * to feed custom PCM into Android SpeechRecognizer without a phone mic.
 * (Source: Android developer reports, GitHub issues, SO research 2024-2026)
 */
class RingSttHandler(private val context: Context) {

    companion object {
        private const val TAG = "RingSttHandler"
        private const val SAMPLE_RATE = 16000
        private const val BYTES_PER_SAMPLE = 2
        // 100ms worth of 16kHz 16-bit mono PCM
        private const val CHUNK_BYTES = SAMPLE_RATE * BYTES_PER_SAMPLE * 100 / 1000  // = 3200
        private const val CHUNK_MS = 100L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var speechRecognizer: SpeechRecognizer? = null
    private var pipeWriteEnd: ParcelFileDescriptor? = null
    @Volatile private var writingCancelled = false

    // Callbacks to Dart (wired up by EventChannel)
    var onTranscript: ((String, Boolean) -> Unit)? = null
    var onError: ((String) -> Unit)? = null
    var onReady: (() -> Unit)? = null

    // ── MethodChannel + EventChannel wiring ──────────────────────────────────

    fun setupMethodChannel(methodChannel: MethodChannel) {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Legacy no-op stubs — Dart may still call these
                "stt_start"      -> result.success(null)
                "stt_push_chunk" -> result.success(null)
                "stt_stop"       -> result.success(null)

                // Primary v3 method: Dart sends full raw PCM bytes
                "stt_transcribe_pcm" -> {
                    val pcm = call.argument<ByteArray>("pcm")
                    if (pcm != null && pcm.isNotEmpty()) {
                        transcribeFromPcm(pcm)
                    } else {
                        Log.w(TAG, "stt_transcribe_pcm called with empty/null PCM")
                        onError?.invoke("No PCM data provided")
                        onTranscript?.invoke("", true)
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── No-op stubs called by RingBleHandler (native BLE routing, now unused) ─
    fun startStt() { Log.d(TAG, "startStt() no-op — rate-paced pipe STT active") }
    fun stopStt()  { Log.d(TAG, "stopStt() no-op — rate-paced pipe STT active")  }
    fun pushChunk(pcm: ByteArray) { /* no-op */ }

    fun setupEventChannel(eventChannel: EventChannel) {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                onTranscript = { text, isFinal ->
                    mainHandler.post {
                        events?.success(mapOf("type" to "transcript", "text" to text, "final" to isFinal))
                    }
                }
                onError = { err ->
                    mainHandler.post {
                        events?.success(mapOf("type" to "error", "message" to err))
                    }
                }
                onReady = {
                    mainHandler.post {
                        events?.success(mapOf("type" to "ready"))
                    }
                }
            }
            override fun onCancel(arguments: Any?) {
                onTranscript = null
                onError = null
                onReady = null
            }
        })
    }

    // ── Core: rate-paced pipe → SpeechRecognizer ─────────────────────────────

    fun transcribeFromPcm(pcmBytes: ByteArray) {
        mainHandler.post {
            cleanup()
            writingCancelled = false

            Log.i(TAG, "transcribeFromPcm: ${pcmBytes.size} bytes (${pcmBytes.size / (SAMPLE_RATE * BYTES_PER_SAMPLE).toFloat()}s)")

            val onDeviceAvailable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
            } else false

            Log.i(TAG, "On-device STT: $onDeviceAvailable (SDK=${Build.VERSION.SDK_INT})")

            // Create pipe: read-end → SpeechRecognizer, write-end → our background thread
            val pipe = try {
                ParcelFileDescriptor.createPipe()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create pipe: ${e.message}")
                onError?.invoke("Pipe creation failed: ${e.message}")
                onTranscript?.invoke("", true)
                return@post
            }
            val readEnd  = pipe[0]
            val writeEnd = pipe[1]
            pipeWriteEnd = writeEnd

            // Create recognizer — on-device preferred for EXTRA_AUDIO_SOURCE support
            val recognizer: SpeechRecognizer = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && onDeviceAvailable) {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Recognizer creation failed: ${e.message}")
                closePipe(readEnd, writeEnd)
                onError?.invoke("Recognizer creation failed: ${e.message}")
                onTranscript?.invoke("", true)
                return@post
            }

            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: android.os.Bundle?) {
                    Log.i(TAG, "STT ready — pipe stream active")
                    onReady?.invoke()
                }
                override fun onBeginningOfSpeech() { Log.d(TAG, "STT: speech began in pipe") }
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() { Log.d(TAG, "STT: end of speech in pipe") }

                override fun onError(error: Int) {
                    val msg = sttErrorString(error)
                    Log.w(TAG, "STT Error: $msg (code=$error)")
                    writingCancelled = true
                    closePipe(readEnd, writeEnd)
                    onError?.invoke(msg)
                    onTranscript?.invoke("", true)
                    cleanup()
                }

                override fun onResults(bundle: android.os.Bundle?) {
                    val results = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = results?.firstOrNull()?.trim() ?: ""
                    Log.i(TAG, "STT Final: \"$text\"")
                    writingCancelled = true
                    closePipe(readEnd, writeEnd)
                    onTranscript?.invoke(text, true)
                    cleanup()
                }

                override fun onPartialResults(bundle: android.os.Bundle?) {
                    val results = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = results?.firstOrNull()?.trim() ?: ""
                    if (text.isNotEmpty()) {
                        Log.d(TAG, "STT Partial: \"$text\"")
                        onTranscript?.invoke(text, false)
                    }
                }

                override fun onEvent(eventType: Int, params: android.os.Bundle?) {}
                override fun onSegmentResults(segmentResults: android.os.Bundle) {}
                override fun onEndOfSegmentedSession() {}
                override fun onLanguageDetection(results: android.os.Bundle) {}
            })

            speechRecognizer = recognizer

            // Intent with EXTRA_AUDIO_SOURCE pointing to our pipe's read end
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                // Feed our rate-paced pipe as the audio source — NOT the phone mic
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, readEnd)
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, SAMPLE_RATE)
            }

            try {
                recognizer.startListening(intent)
                Log.i(TAG, "SpeechRecognizer started — beginning rate-paced PCM write")
            } catch (e: Exception) {
                Log.e(TAG, "startListening failed: ${e.message}")
                closePipe(readEnd, writeEnd)
                onError?.invoke("startListening failed: ${e.message}")
                onTranscript?.invoke("", true)
                cleanup()
                return@post
            }

            // Background thread: write PCM at exactly 16kHz real-time rate
            // This is the KEY fix — SpeechRecognizer needs real-time paced audio,
            // not a burst read from a file.
            Thread {
                try {
                    val fos = FileOutputStream(writeEnd.fileDescriptor)
                    var offset = 0
                    while (offset < pcmBytes.size && !writingCancelled) {
                        val end = minOf(offset + CHUNK_BYTES, pcmBytes.size)
                        val bytesToWrite = end - offset
                        fos.write(pcmBytes, offset, bytesToWrite)
                        fos.flush()
                        offset = end
                        // Sleep to maintain 16kHz real-time pacing
                        if (offset < pcmBytes.size && !writingCancelled) {
                            Thread.sleep(CHUNK_MS)
                        }
                    }
                    // Close write end → signals EOF to SpeechRecognizer → triggers onResults
                    Log.i(TAG, "PCM write complete (${pcmBytes.size} bytes) — closing write end")
                    fos.close()
                    writeEnd.close()
                } catch (e: Exception) {
                    Log.e(TAG, "PCM write error: ${e.message}")
                    try { writeEnd.close() } catch (_: Exception) {}
                }
            }.start()
        }
    }

    private fun closePipe(vararg fds: ParcelFileDescriptor) {
        for (fd in fds) {
            try { fd.close() } catch (_: Exception) {}
        }
    }

    fun cleanup() {
        writingCancelled = true
        mainHandler.post {
            try { speechRecognizer?.destroy() } catch (_: Exception) {}
            speechRecognizer = null
        }
        try { pipeWriteEnd?.close() } catch (_: Exception) {}
        pipeWriteEnd = null
    }

    private fun sttErrorString(error: Int) = when (error) {
        SpeechRecognizer.ERROR_AUDIO                -> "Audio stream error"
        SpeechRecognizer.ERROR_CLIENT               -> "Client error"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Permissions error"
        SpeechRecognizer.ERROR_NETWORK              -> "Network error"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT      -> "Network timeout"
        SpeechRecognizer.ERROR_NO_MATCH             -> "No speech recognized"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY      -> "Recognizer busy"
        SpeechRecognizer.ERROR_SERVER               -> "Server error"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT       -> "Speech timeout"
        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS    -> "Too many requests"
        else                                        -> "Error ($error)"
    }
}
