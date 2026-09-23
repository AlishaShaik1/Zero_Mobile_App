'use client'

import { motion } from 'framer-motion'
import { ReactNode, RefObject, useState, useEffect } from 'react'
import UniversalMascot, { MascotHandle } from '../UniversalMascot'

interface WelcomeScreenProps {
  children?: ReactNode
  mascotRef?: RefObject<MascotHandle | null>
  onSelectTask?: (prompt: string, webSearch?: boolean) => void
}

export function WelcomeScreen({ children, mascotRef, onSelectTask }: WelcomeScreenProps) {
  const [greeting, setGreeting] = useState('Good morning')

  useEffect(() => {
    const h = new Date().getHours()
    if (h < 12) setGreeting('Good morning')
    else if (h < 17) setGreeting('Good afternoon')
    else if (h < 21) setGreeting('Good evening')
    else setGreeting('Good night')
  }, [])

  return (
    <div className="flex-1 flex flex-col items-center justify-center h-full min-h-0 px-4 py-8">
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1] }}
        className="flex flex-col items-center text-center w-full max-w-3xl"
      >
        {/* Greeting row — On Mobile: Mascot top centered, text centered below. On Desktop (md:): Mascot on left beside text */}
        <div className="flex flex-col md:flex-row items-center justify-center gap-3.5 md:gap-6 mb-8 md:mb-12">
          {/* Inline mascot */}
          <div className="shrink-0 flex items-center justify-center">
            <UniversalMascot
              ref={mascotRef}
              size={72}
              enableDebugPanel={false}
              autoTimeOfDay
            />
          </div>

          <div className="flex flex-col items-center md:items-start text-center md:text-left gap-1.5 md:gap-2">
            <h1 className="text-3xl sm:text-5xl md:text-[56px] font-bold tracking-tight text-[#111111] leading-none">
              {greeting}<span className="text-[#111111]/30">.</span>
            </h1>
            <p className="text-lg sm:text-2xl md:text-[28px] font-bold tracking-tight text-[#22C8FF] leading-none">
              What should we build today?
            </p>
          </div>
        </div>

        {/* Composer */}
        <motion.div
          className="w-full"
          id="composer"
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.35, duration: 0.8 }}
        >
          {children}
        </motion.div>

        {/* Quick action chips */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.45, duration: 0.6 }}
          className="flex items-center justify-center gap-3 mt-4 flex-wrap"
        >
          {[
            {
              icon: '⚡',
              label: 'Build',
              prompt: 'Build a modern, interactive single-page web application with real-time UI components and animations',
              webSearch: false,
            },
            {
              icon: '💻',
              label: 'Code',
              prompt: 'Write a complete, runnable algorithm in Python with step-by-step logic breakdown and complexity analysis',
              webSearch: false,
            },
            {
              icon: '🔍',
              label: 'Research',
              prompt: 'Search the live web for the latest breakthroughs in AI and robotics, and provide a synthesized analysis with citations',
              webSearch: true,
            },
            {
              icon: '📝',
              label: 'Plan',
              prompt: 'Create a comprehensive technical specification and architectural roadmap for a scalable cloud platform',
              webSearch: false,
            },
          ].map((chip) => (
            <button
              key={chip.label}
              type="button"
              onClick={() => onSelectTask?.(chip.prompt, chip.webSearch)}
              className="flex items-center gap-2 px-4 py-2 bg-white text-[#111111] border-2 border-[#111111] rounded-xl font-bold text-xs sm:text-sm tracking-tight shadow-[3px_3px_0px_#111111] hover:shadow-[1px_1px_0px_#111111] hover:translate-x-[2px] hover:translate-y-[2px] active:translate-x-[3px] active:translate-y-[3px] active:shadow-none transition-all duration-150 cursor-pointer"
            >
              <span className="text-sm">{chip.icon}</span>
              <span>{chip.label}</span>
            </button>
          ))}
        </motion.div>
      </motion.div>
    </div>
  )
}
