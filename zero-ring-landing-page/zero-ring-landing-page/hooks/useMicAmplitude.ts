'use client'
import { useEffect, useRef, useState } from 'react'

/**
 * Reads real-time microphone amplitude using the Web Audio API.
 * Returns an array of `bands` normalised values [0..1] derived from
 * frequency-domain data, one per visual bar.
 */
export function useMicAmplitude(active: boolean, bands = 3) {
    const [levels, setLevels] = useState<number[]>(Array(bands).fill(0))
    const rafRef = useRef<number>(0)
    const streamRef = useRef<MediaStream | null>(null)
    const ctxRef = useRef<AudioContext | null>(null)
    const analyserRef = useRef<AnalyserNode | null>(null)

    useEffect(() => {
        if (!active) {
            // Zero out bars when not recording
            setLevels(Array(bands).fill(0))
            cancelAnimationFrame(rafRef.current)
            // Clean up audio context
            ctxRef.current?.close()
            ctxRef.current = null
            streamRef.current?.getTracks().forEach(t => t.stop())
            streamRef.current = null
            return
        }

        let cancelled = false

        async function start() {
            try {
                const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false })
                if (cancelled) { stream.getTracks().forEach(t => t.stop()); return }
                streamRef.current = stream

                const ctx = new AudioContext()
                ctxRef.current = ctx
                const analyser = ctx.createAnalyser()
                analyser.fftSize = 64           // small = fast, 32 frequency bins
                analyserRef.current = analyser

                ctx.createMediaStreamSource(stream).connect(analyser)

                const buf = new Uint8Array(analyser.frequencyBinCount) // 32 bins

                const binPerBand = Math.floor(buf.length / bands)

                function tick() {
                    if (cancelled) return
                    analyser.getByteFrequencyData(buf)

                    const result: number[] = []
                    for (let b = 0; b < bands; b++) {
                        let sum = 0
                        const start = b * binPerBand
                        const end = start + binPerBand
                        for (let i = start; i < end; i++) sum += buf[i]
                        const avg = sum / binPerBand / 255   // normalise 0-1
                        // Boost low values so silence is really quiet
                        result.push(Math.pow(avg, 0.6))
                    }
                    setLevels(result)
                    rafRef.current = requestAnimationFrame(tick)
                }
                tick()
            } catch {
                // Permission denied or no mic — leave bars at 0
            }
        }

        start()

        return () => {
            cancelled = true
            cancelAnimationFrame(rafRef.current)
            ctxRef.current?.close()
            ctxRef.current = null
            streamRef.current?.getTracks().forEach(t => t.stop())
            streamRef.current = null
        }
    }, [active, bands])

    return levels
}
