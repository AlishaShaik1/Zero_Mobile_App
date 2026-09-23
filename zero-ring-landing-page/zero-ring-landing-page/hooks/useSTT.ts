'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import SpeechRecognition, { useSpeechRecognition } from 'react-speech-recognition';

export type STTStatus = 'idle' | 'loading' | 'ready' | 'recording' | 'transcribing' | 'error';

interface STTHookReturn {
    status: STTStatus;
    /** Full accumulated transcript so far (final segments only) */
    accumulatedText: string;
    /** Live interim word stream (not yet confirmed) */
    interimText: string;
    progress: number;
    device: string;
    startRecording: () => Promise<void>;
    stopRecording: () => void;
    clearTranscript: () => void;
}

/**
 * Robust STT hook using react-speech-recognition.
 *
 * Design goals:
 * - Accumulate ALL final segments for the full session (up to 4 min+)
 * - Stream interim (in-progress) words live via `onLiveUpdate`
 * - Call `onTranscript` on each NEW final segment so the InputBar can append it
 * - Never wipe accumulated text mid-session; only clear on explicit stop or reset
 */
export function useSTT(
    /** Called with each newly-finalised segment so InputBar can append it */
    onNewSegment?: (segment: string) => void,
    /** Called on every interim update with the live in-progress text */
    onLiveUpdate?: (text: string) => void
): STTHookReturn {
    const {
        interimTranscript,
        finalTranscript,
        resetTranscript,
        listening,
        browserSupportsSpeechRecognition,
        isMicrophoneAvailable,
    } = useSpeechRecognition();

    // Stable accumulation buffer – survives re-renders without stale closure issues
    const accBufferRef = useRef('');
    const [accumulatedText, setAccumulatedText] = useState('');

    // Keep callbacks stable
    const onNewSegmentRef = useRef(onNewSegment);
    const onLiveUpdateRef = useRef(onLiveUpdate);
    useEffect(() => { onNewSegmentRef.current = onNewSegment; }, [onNewSegment]);
    useEffect(() => { onLiveUpdateRef.current = onLiveUpdate; }, [onLiveUpdate]);

    // Track last finalTranscript we processed to avoid duplicate handling
    const lastFinalRef = useRef('');

    /* ── Accumulate final segments ─────────────────────────────── */
    useEffect(() => {
        if (!finalTranscript || finalTranscript === lastFinalRef.current) return;

        // Extract only the NEW text since the last final
        const newText = lastFinalRef.current
            ? finalTranscript.replace(lastFinalRef.current, '').trim()
            : finalTranscript.trim();

        lastFinalRef.current = finalTranscript;

        if (!newText) return;

        // Append to persistent buffer
        accBufferRef.current = accBufferRef.current
            ? `${accBufferRef.current} ${newText}`
            : newText;
        setAccumulatedText(accBufferRef.current);

        // Notify InputBar to append this segment
        onNewSegmentRef.current?.(newText);
    }, [finalTranscript]);

    /* ── Stream interim text ───────────────────────────────────── */
    useEffect(() => {
        onLiveUpdateRef.current?.(interimTranscript);
    }, [interimTranscript]);

    /* ── Auto-restart on silence to support 4-min+ sessions ───── */
    // Chrome's Web Speech API hard-stops after ~60 s of silence.
    // We detect when listening drops while we intended to keep recording
    // and immediately restart.
    const intentListening = useRef(false);
    useEffect(() => {
        if (intentListening.current && !listening) {
            // Restart immediately; finalTranscript has already been committed
            SpeechRecognition.startListening({ continuous: true, language: 'en-IN' });
        }
    }, [listening]);

    /* ── Public API ────────────────────────────────────────────── */
    const startRecording = useCallback(async () => {
        if (!browserSupportsSpeechRecognition) {
            console.error('Browser does not support Speech Recognition');
            return;
        }
        // Reset accumulation for fresh session
        accBufferRef.current = '';
        setAccumulatedText('');
        lastFinalRef.current = '';
        resetTranscript();
        intentListening.current = true;
        SpeechRecognition.startListening({ continuous: true, language: 'en-IN' });
    }, [browserSupportsSpeechRecognition, resetTranscript]);

    const stopRecording = useCallback(() => {
        intentListening.current = false;
        SpeechRecognition.stopListening();
    }, []);

    const clearTranscript = useCallback(() => {
        accBufferRef.current = '';
        setAccumulatedText('');
        lastFinalRef.current = '';
        resetTranscript();
    }, [resetTranscript]);

    let status: STTStatus = 'ready';
    if (!browserSupportsSpeechRecognition || isMicrophoneAvailable === false) {
        status = 'error';
    } else if (listening) {
        status = 'recording';
    }

    return {
        status,
        accumulatedText,
        interimText: interimTranscript,
        progress: 100,
        device: 'native',
        startRecording,
        stopRecording,
        clearTranscript,
    };
}
