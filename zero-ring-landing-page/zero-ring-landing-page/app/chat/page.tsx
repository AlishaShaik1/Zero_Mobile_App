'use client'

import { ZeroChat } from '@/components/chat/ZeroChat'
import { useState, useEffect, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Volume2, VolumeX } from 'lucide-react'

export default function ChatPage() {
    const [showVideo, setShowVideo] = useState(true)
    const [isMuted, setIsMuted] = useState(false)
    const videoRef = useRef<HTMLVideoElement>(null)

    useEffect(() => {
        // Auto-close after 11 seconds
        const t = setTimeout(() => {
            setShowVideo(false)
        }, 11000)
        return () => clearTimeout(t)
    }, [])

    useEffect(() => {
        // Attempt to play with sound immediately
        const video = videoRef.current
        if (!video) return

        video.muted = false
        const playPromise = video.play()

        if (playPromise !== undefined) {
            playPromise.then(() => {
                // Sound autoplay succeeded
                setIsMuted(false)
            }).catch(() => {
                // Browser blocked unmuted autoplay -> fall back to muted and prompt user
                video.muted = true
                setIsMuted(true)
                video.play().catch(() => {})
            })
        }
    }, [])

    const toggleSound = (e?: React.MouseEvent) => {
        if (e) e.stopPropagation()
        const video = videoRef.current
        if (!video) return

        const nextMuted = !video.muted
        video.muted = nextMuted
        setIsMuted(nextMuted)
        video.play().catch(() => {})
    }

    return (
        <div className="w-full h-[100dvh]">
            {/* The main chat app preloads in background */}
            <ZeroChat />

            {/* Video Overlay */}
            <AnimatePresence>
                {showVideo && (
                    <motion.div
                        initial={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        transition={{ duration: 0.8 }}
                        className="fixed inset-0 z-[100] bg-black/40 backdrop-blur-2xl flex items-center justify-center p-4 sm:p-8 cursor-default"
                        style={{ pointerEvents: 'auto' }}
                        onClick={isMuted ? () => toggleSound() : undefined}
                    >
                        {/* Video card: compact & small on desktop, responsive on mobile */}
                        <div
                            className="relative w-full max-w-[92vw] sm:max-w-lg md:max-w-xl lg:max-w-2xl aspect-video rounded-2xl md:rounded-3xl overflow-hidden bg-black shadow-[0_20px_60px_rgba(0,0,0,0.6)] border border-white/15"
                            onClick={(e) => e.stopPropagation()}
                        >
                            <video
                                ref={videoRef}
                                src="/intro.mp4"
                                autoPlay
                                playsInline
                                className="w-full h-full object-cover"
                                onEnded={() => setShowVideo(false)}
                            />

                            {/* Sound Toggle — top left */}
                            <button
                                type="button"
                                onClick={toggleSound}
                                className="absolute top-3.5 left-3.5 sm:top-4 sm:left-4 flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-black/60 hover:bg-black/90 text-white/90 hover:text-white backdrop-blur-md transition-all font-sans text-[11px] font-medium tracking-wide shadow-lg border border-white/20 z-20 cursor-pointer"
                                title={isMuted ? 'Click to unmute sound' : 'Mute sound'}
                            >
                                {isMuted ? (
                                    <>
                                        <VolumeX className="w-3.5 h-3.5 text-[#22C8FF] animate-pulse" />
                                        <span>Tap to Unmute 🔊</span>
                                    </>
                                ) : (
                                    <>
                                        <Volume2 className="w-3.5 h-3.5 text-emerald-400" />
                                        <span>Sound ON</span>
                                    </>
                                )}
                            </button>

                            {/* Skip — top right */}
                            <button
                                type="button"
                                onClick={() => setShowVideo(false)}
                                className="absolute top-3.5 right-3.5 sm:top-4 sm:right-4 flex items-center gap-1.5 px-3.5 py-1.5 rounded-full bg-black/60 hover:bg-black/90 text-white/80 hover:text-white backdrop-blur-md transition-all font-sans text-[11px] font-medium tracking-[0.12em] uppercase shadow-lg border border-white/10 z-20 cursor-pointer"
                            >
                                Skip ✕
                            </button>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    )
}
