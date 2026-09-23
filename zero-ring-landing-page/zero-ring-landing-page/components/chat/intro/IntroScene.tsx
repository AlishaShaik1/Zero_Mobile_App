'use client'

import { Canvas } from '@react-three/fiber'
import { Environment, Preload } from '@react-three/drei'
import { Suspense, useEffect, useState } from 'react'
import { ButterflySystem } from './ButterflySystem'
import { FlowerSystem } from './FlowerSystem'
import { ParticleSystem } from './ParticleSystem'
import { motion, AnimatePresence } from 'framer-motion'

interface IntroSceneProps {
  onComplete: () => void
}

export function IntroScene({ onComplete }: IntroSceneProps) {
  const [phase, setPhase] = useState<'initial' | 'blooming' | 'butterflies' | 'title' | 'ready' | 'transition'>('initial')

  useEffect(() => {
    // Cinematic Timeline
    const t1 = setTimeout(() => setPhase('blooming'), 500)
    const t2 = setTimeout(() => setPhase('butterflies'), 1200)
    const t3 = setTimeout(() => setPhase('title'), 2500)
    const t4 = setTimeout(() => setPhase('ready'), 3500)

    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
      clearTimeout(t3)
      clearTimeout(t4)
    }
  }, [])

  const handleEnter = () => {
    setPhase('transition')
    setTimeout(() => {
      onComplete()
    }, 800) // Reduced further so the chat starts fading in even earlier
  }

  return (
    <div className="fixed inset-0 z-50 bg-[#F8F7F3] overflow-hidden">
      <Canvas 
        camera={{ position: [0, 0, 10], fov: 45 }}
        dpr={[1, 2]}
        gl={{ alpha: false, antialias: true }}
      >
        <color attach="background" args={['#F8F7F3']} />
        <ambientLight intensity={1.5} />
        <directionalLight position={[10, 10, 5]} intensity={2} color="#ffffff" />
        <directionalLight position={[-10, -10, -5]} intensity={1} color="#22C8FF" />
        
        <Suspense fallback={null}>
          <ButterflySystem phase={phase} />
          {phase === 'transition' && <ParticleSystem />}
          <Environment preset="city" />
          <Preload all />
        </Suspense>
      </Canvas>

      <AnimatePresence>
        {(phase === 'title' || phase === 'ready') && (
          <motion.div 
            key="title-group"
            className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, filter: 'blur(10px)' }}
            transition={{ duration: 1.2, ease: [0.16, 1, 0.3, 1] }}
          >
            <img src="/logo.png?v=2" alt="Zero AI" className="w-64 md:w-80 h-auto object-contain mb-4" draggable="false" />
            <p 
              className="text-lg md:text-xl"
              style={{
                fontFamily: "var(--font-space-grotesk)",
                fontWeight: 800,
                color: "#00C8FF",
                letterSpacing: "-0.5px"
              }}
            >
              The AI that lives on your finger.
            </p>
          </motion.div>
        )}

        {phase === 'ready' && (
          <motion.div
            key="enter-button"
            className="absolute bottom-24 left-0 right-0 flex justify-center"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 1, delay: 0.5 }}
          >
            <button
              onClick={handleEnter}
              className="group px-8 py-4 bg-transparent border-none outline-none flex flex-col items-center gap-2 cursor-pointer pointer-events-auto"
            >
              <span className="text-[#111111] font-semibold text-sm tracking-[0.2em] uppercase group-hover:text-[#22C8FF] transition-colors">
                Enter Zero AI
              </span>
              <span className="w-8 h-[1px] bg-[#111111] opacity-20 group-hover:bg-[#22C8FF] group-hover:opacity-100 transition-all duration-300" />
            </button>
          </motion.div>
        )}

        {phase !== 'transition' && (
          <motion.button
            key="skip-button"
            onClick={() => { setPhase('transition'); onComplete(); }}
            className="absolute top-8 right-8 text-xs font-semibold uppercase tracking-widest text-[#111111] opacity-30 hover:opacity-100 transition-opacity z-10 pointer-events-auto"
            initial={{ opacity: 0 }}
            animate={{ opacity: 0.3 }}
            exit={{ opacity: 0 }}
          >
            Skip intro →
          </motion.button>
        )}
      </AnimatePresence>
    </div>
  )
}
