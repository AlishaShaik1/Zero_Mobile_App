// /workers/stt.worker.ts
import {
    pipeline,
    AutomaticSpeechRecognitionPipeline,
    env,
} from '@huggingface/transformers';

// Allow model files to load from HF CDN + cache in browser
env.allowLocalModels = false;
env.useBrowserCache = true;

let transcriber: AutomaticSpeechRecognitionPipeline | null = null;

self.addEventListener('message', async (event: MessageEvent) => {
    const { type } = event.data;

    if (type === 'ping') {
        const device = typeof navigator !== 'undefined' && 'gpu' in navigator ? 'webgpu' : 'wasm';
        if (transcriber) {
            self.postMessage({ type: 'status', status: 'ready', device });
        }
        return;
    }

    // ---- INIT: download + cache model ----
    if (type === 'init') {
        try {
            self.postMessage({ type: 'status', status: 'loading' });

            const device = typeof navigator !== 'undefined' && 'gpu' in navigator
                ? 'webgpu'
                : 'wasm';

            transcriber = await pipeline(
                'automatic-speech-recognition',
                'onnx-community/whisper-tiny',    // ~39MB hybrid quant
                {
                    device: device as "webgpu" | "wasm",
                    dtype: {
                        encoder_model: 'fp32',         // better quality encoder
                        decoder_model_merged: 'q4',    // small decoder
                    },
                    progress_callback: (info: any) => {
                        if (info.status === 'progress') {
                            self.postMessage({
                                type: 'progress',
                                file: info.file,
                                loaded: info.loaded,
                                total: info.total,
                            });
                        }
                    },
                }
            );

            self.postMessage({ type: 'status', status: 'ready', device });
        } catch (err: any) {
            self.postMessage({ type: 'error', message: err.message });
        }
    }

    // ---- TRANSCRIBE ----
    if (type === 'transcribe') {
        if (!transcriber) {
            self.postMessage({ type: 'error', message: 'Model not loaded' });
            return;
        }

        try {
            self.postMessage({ type: 'status', status: 'transcribing' });

            const { audio } = event.data as { audio: Float32Array };

            // Silence guard: skip if audio is near-silent
            const rms = Math.sqrt(audio.reduce((s, x) => s + x * x, 0) / audio.length);
            if (rms < 0.005) {
                self.postMessage({ type: 'result', text: '' });
                return;
            }

            const result = await transcriber(audio, {
                language: 'english',
                task: 'transcribe',
                chunk_length_s: 30,
                return_timestamps: false,
            }) as { text: string };

            self.postMessage({ type: 'result', text: result.text.trim() });
        } catch (err: any) {
            self.postMessage({ type: 'error', message: err.message });
        }
    }
});
