'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { Mic, ArrowUp, Square, Plus, ChevronDown, Globe } from 'lucide-react'
import { useState, useRef, useEffect, useCallback } from 'react'
import { useSTT } from '@/hooks/useSTT'
import { useMicAmplitude } from '@/hooks/useMicAmplitude'

interface InputBarProps {
  onSend: (message: string, model: string, webSearch: boolean) => void
  onStop?: () => void
  isTyping: boolean
  collapsed?: boolean
  onExpand?: () => void
}

export function InputBar({ onSend, onStop, isTyping, collapsed = false, onExpand }: InputBarProps) {
  // Committed text (typed or finalised STT segments)
  const [committed, setCommitted] = useState('')
  // Live interim text from STT (not yet finalised)
  const [interim, setInterim] = useState('')
  const [isFocused, setIsFocused] = useState(false)

  const textareaRef = useRef<HTMLTextAreaElement>(null)

  // Called for each new finalised STT segment — append to committed
  const handleNewSegment = useCallback((segment: string) => {
    setCommitted(prev => prev ? `${prev} ${segment}` : segment)
    setInterim('')
  }, [])

  // Called on every interim update — just replace interim display
  const handleLiveUpdate = useCallback((live: string) => {
    setInterim(live)
  }, [])

  const { status, startRecording, stopRecording } = useSTT(handleNewSegment, handleLiveUpdate)
  const isRecording = status === 'recording'

  // Real-time mic amplitude — 3 frequency bands
  const micLevels = useMicAmplitude(isRecording, 3)

  const [webSearchEnabled, setWebSearchEnabled] = useState(false)
  const models = ['Titan Pro', 'Titan Ultra']
  const [selectedModel, setSelectedModel] = useState('Titan Pro')
  const [showModels, setShowModels] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)

  // Auto-resize textarea
  useEffect(() => {
    const ta = textareaRef.current
    if (!ta) return
    ta.style.height = 'auto'
    ta.style.height = `${Math.min(ta.scrollHeight, 220)}px`
  }, [committed, interim])

  // Close dropdown outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setShowModels(false)
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  // The full text to display (committed + live interim italicised)
  const displayValue = interim
    ? committed ? `${committed} ${interim}` : interim
    : committed

  const isCollapsed = collapsed && !isFocused && !displayValue.trim() && !isRecording

  // Sync collapsed state from parent (e.g. on scroll)
  useEffect(() => {
    if (collapsed && !displayValue.trim()) {
      setIsFocused(false)
      textareaRef.current?.blur()
    }
  }, [collapsed, displayValue])

  const handleExpand = () => {
    setIsFocused(true)
    onExpand?.()
    setTimeout(() => {
      textareaRef.current?.focus()
    }, 40)
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (isTyping) {
      onStop?.()
      return
    }
    const text = committed.trim() || interim.trim()
    if (!text) return
    // Stop STT if active
    if (isRecording) stopRecording()
    onSend(text, selectedModel, webSearchEnabled)
    setCommitted('')
    setInterim('')
  }

  const handleVoiceToggle = (e: React.MouseEvent) => {
    e.stopPropagation()
    handleExpand()
    if (isRecording) {
      stopRecording()
      if (interim.trim()) {
        setCommitted(prev => prev ? `${prev} ${interim.trim()}` : interim.trim())
        setInterim('')
      }
    } else {
      setInterim('')
      startRecording()
    }
  }

  return (
    <div className="w-full max-w-4xl xl:max-w-5xl mx-auto px-2 sm:px-4 pb-4 pt-1 transition-all duration-300">
      <form
        onSubmit={handleSubmit}
        onClick={handleExpand}
        className={`relative flex transition-all duration-300 cursor-text rounded-[24px] backdrop-blur-xl ${
          isCollapsed
            ? 'flex-row items-center justify-between px-3.5 py-2 bg-white/80 hover:bg-white/92 border border-white/60 shadow-[0_4px_20px_rgba(0,0,0,0.05),0_0_8px_rgba(255,255,255,0.45)] hover:shadow-[0_4px_24px_rgba(0,0,0,0.07),0_0_12px_rgba(255,255,255,0.65)] min-h-[54px]'
            : 'flex-col p-3.5 pt-4 bg-white/95 focus-within:bg-white border border-[#111]/15 focus-within:border-[#00C8FF]/50 shadow-[0_6px_24px_rgba(0,0,0,0.06)]'
        }`}
      >
        {isCollapsed ? (
          /* ── Single-Line Collapsed Mode (matching Image 2 rounded rectangle shape) ── */
          <div className="flex items-center justify-between w-full gap-2.5 px-0.5">
            {/* Left actions: Plus + Globe */}
            <div className="flex items-center gap-1.5 shrink-0" onClick={e => e.stopPropagation()}>
              <button
                type="button"
                onClick={handleExpand}
                className="p-1.5 text-[#111]/50 hover:text-[#111] bg-[#F0F0F0] hover:bg-[#E0E0E0] rounded-full transition-all"
                title="Add attachment"
              >
                <Plus className="w-4 h-4" />
              </button>

              <button
                type="button"
                onClick={() => setWebSearchEnabled(v => !v)}
                className={`flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold transition-all ${
                  webSearchEnabled
                    ? 'bg-[#00C8FF]/10 text-[#00C8FF] border border-[#00C8FF]/30'
                    : 'text-[#111]/50 hover:text-[#111] hover:bg-[#F0F0F0]'
                }`}
                title="Toggle Web Search"
              >
                <Globe className="w-3.5 h-3.5" />
                {webSearchEnabled && <span>Web</span>}
              </button>
            </div>

            {/* Center: Placeholder input */}
            <div className="flex-1 min-w-0">
              <input
                type="text"
                readOnly
                placeholder="How can I help you today?"
                className="w-full bg-transparent outline-none text-[#111] text-[15px] placeholder:text-[#111]/40 cursor-pointer font-sans"
              />
            </div>

            {/* Right actions: Model picker + Mic + Arrow */}
            <div className="flex items-center gap-2 shrink-0" onClick={e => e.stopPropagation()}>
              <div className="relative" ref={dropdownRef}>
                <button
                  type="button"
                  onClick={() => setShowModels(v => !v)}
                  className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-[#111] opacity-75 hover:opacity-100 hover:bg-[#F0F0F0] text-xs font-semibold tracking-wide transition-all"
                >
                  <span className={`w-1.5 h-1.5 rounded-full ${selectedModel.includes('Ultra') ? 'bg-[#9333EA]' : 'bg-[#00C8FF]'}`} />
                  {selectedModel}
                  <ChevronDown className="w-3 h-3 opacity-60" />
                </button>
                <AnimatePresence>
                  {showModels && (
                    <motion.div
                      initial={{ opacity: 0, y: 8, scale: 0.95 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{ opacity: 0, y: 8, scale: 0.95 }}
                      transition={{ duration: 0.15 }}
                      className="absolute bottom-full right-0 mb-2 w-48 bg-white rounded-xl shadow-[0_4px_24px_rgba(0,0,0,0.12)] border border-[#E0E0E0] overflow-hidden z-50 py-1"
                    >
                      {models.map(m => (
                        <button
                          key={m}
                          type="button"
                          onClick={() => {
                            setSelectedModel(m)
                            setShowModels(false)
                          }}
                          className={`w-full text-left px-3.5 py-2 text-xs font-medium hover:bg-[#F8F7F3] transition-colors flex items-center justify-between ${
                            selectedModel === m ? 'text-[#00C8FF] font-semibold bg-[#00C8FF]/5' : 'text-[#111]'
                          }`}
                        >
                          <div className="flex items-center gap-2">
                            <span className={`w-2 h-2 rounded-full ${m.includes('Ultra') ? 'bg-[#9333EA]' : 'bg-[#00C8FF]'}`} />
                            <span>{m}</span>
                          </div>
                          {selectedModel === m && <span className="text-[10px] text-[#00C8FF] font-bold">Selected</span>}
                        </button>
                      ))}
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>

              <button
                type="button"
                onClick={handleVoiceToggle}
                className="p-1.5 text-[#111]/50 hover:text-[#111] hover:bg-[#F0F0F0] rounded-full transition-all"
                title="Voice input"
              >
                <Mic className="w-4 h-4" />
              </button>

              <button
                type="button"
                onClick={handleExpand}
                className="p-1.5 text-[#111]/40 hover:text-[#111] hover:bg-[#F0F0F0] rounded-full transition-all"
                title="Open chat input"
              >
                <ArrowUp className="w-4 h-4" />
              </button>
            </div>
          </div>
        ) : (
          /* ── Full Expanded Chat Section (when typing/active) ── */
          <>
            <textarea
              ref={textareaRef}
              value={displayValue}
              onFocus={() => {
                setIsFocused(true)
                onExpand?.()
              }}
              onBlur={() => setIsFocused(false)}
              onChange={(e) => {
                setCommitted(e.target.value)
                setInterim('')
              }}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault()
                  handleSubmit(e)
                }
              }}
              placeholder={isRecording ? 'Speak now… text appears here in real time' : 'How can I help you today?'}
              rows={1}
              className="w-full max-h-[220px] min-h-[44px] bg-transparent resize-none outline-none px-2 text-[#111] text-[15px] sm:text-[15.5px] tracking-tight placeholder:text-[#111]/40 leading-relaxed"
              style={{ fontFamily: 'var(--font-space-grotesk), sans-serif' }}
              autoFocus
            />

            {/* Toolbar */}
            <div className="flex items-center justify-between mt-2.5 px-1" onClick={e => e.stopPropagation()}>
              {/* Left */}
              <div className="flex items-center gap-2">
                <motion.button
                  type="button"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="p-2 text-[#111] opacity-50 hover:opacity-100 bg-[#F0F0F0] hover:bg-[#E0E0E0] rounded-full transition-opacity"
                >
                  <Plus className="w-4 h-4" />
                </motion.button>

                <motion.button
                  type="button"
                  onClick={() => setWebSearchEnabled(v => !v)}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-full text-xs font-semibold transition-all ${
                    webSearchEnabled
                      ? 'bg-[#00C8FF]/10 text-[#00C8FF] border border-[#00C8FF]/30'
                      : 'text-[#111] opacity-60 hover:opacity-100 hover:bg-[#F0F0F0]'
                  }`}
                >
                  <Globe className="w-3.5 h-3.5" />
                  {webSearchEnabled && <span>Web</span>}
                </motion.button>
              </div>

              {/* Right */}
              <div className="flex items-center gap-2">
                {/* Model picker */}
                <div className="relative" ref={dropdownRef}>
                  <button
                    type="button"
                    onClick={() => setShowModels(v => !v)}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[#111] opacity-75 hover:opacity-100 hover:bg-[#F0F0F0] text-xs font-semibold tracking-wide transition-all"
                  >
                    <span className={`w-1.5 h-1.5 rounded-full ${selectedModel.includes('Ultra') ? 'bg-[#9333EA]' : 'bg-[#00C8FF]'}`} />
                    {selectedModel}
                    <ChevronDown className="w-3 h-3 opacity-60" />
                  </button>
                  <AnimatePresence>
                    {showModels && (
                      <motion.div
                        initial={{ opacity: 0, y: 8, scale: 0.95 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        exit={{ opacity: 0, y: 8, scale: 0.95 }}
                        transition={{ duration: 0.15 }}
                        className="absolute bottom-full right-0 mb-2 w-52 bg-white rounded-xl shadow-[0_4px_24px_rgba(0,0,0,0.12)] border border-[#E0E0E0] overflow-hidden z-50 py-1"
                      >
                        {models.map(m => (
                          <button
                            key={m}
                            type="button"
                            onClick={() => {
                              setSelectedModel(m)
                              setShowModels(false)
                            }}
                            className={`w-full text-left px-3.5 py-2.5 text-xs font-medium hover:bg-[#F8F7F3] transition-colors flex items-center justify-between ${
                              selectedModel === m ? 'text-[#00C8FF] font-semibold bg-[#00C8FF]/5' : 'text-[#111]'
                            }`}
                          >
                            <div className="flex items-center gap-2">
                              <span className={`w-2 h-2 rounded-full ${m.includes('Ultra') ? 'bg-[#9333EA]' : 'bg-[#00C8FF]'}`} />
                              <span>{m}</span>
                            </div>
                            {selectedModel === m && <span className="text-[10px] text-[#00C8FF] font-bold">Selected</span>}
                          </button>
                        ))}
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>

                {/* Mic + amplitude visualizer */}
                <div className="flex items-center gap-1.5">
                  <AnimatePresence>
                    {isRecording && (
                      <motion.span
                        key="wave"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        transition={{ duration: 0.2 }}
                        className="flex items-center gap-[3px]"
                        style={{ height: 16 }}
                      >
                        {micLevels.map((level, i) => {
                          const h = Math.max(2, Math.round(2 + level * 12))
                          return (
                            <span
                              key={i}
                              style={{
                                display: 'block',
                                width: 2,
                                height: h,
                                borderRadius: 99,
                                background: '#00C8FF',
                                transition: 'height 60ms ease-out',
                              }}
                            />
                          )
                        })}
                      </motion.span>
                    )}
                  </AnimatePresence>

                  <motion.button
                    type="button"
                    onClick={handleVoiceToggle}
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    className={`p-2 rounded-full transition-all ${
                      isRecording ? 'text-[#00C8FF]' : 'text-[#111] opacity-50 hover:opacity-100'
                    }`}
                    title={isRecording ? 'Stop recording' : 'Start voice input'}
                  >
                    <Mic className="w-4 h-4" />
                  </motion.button>
                </div>

                {/* Send / Stop Action Button */}
                <AnimatePresence mode="wait" initial={false}>
                  {isTyping ? (
                    <motion.button
                      key="stop-button"
                      type="button"
                      onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        onStop?.();
                      }}
                      onPointerDown={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        onStop?.();
                      }}
                      initial={{ scale: 0.8, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1 }}
                      exit={{ scale: 0.8, opacity: 0 }}
                      whileHover={{ scale: 1.08 }}
                      whileTap={{ scale: 0.92 }}
                      className="ml-1.5 w-8 h-8 rounded-lg bg-[#EF4444] hover:bg-[#DC2626] active:bg-[#B91C1C] text-white flex items-center justify-center shadow-[0_2px_10px_rgba(239,68,68,0.4)] transition-colors cursor-pointer border border-red-400/50 shrink-0"
                      title="Stop generating"
                    >
                      {/* Red square stop button with curly rounded edges and solid white square stop glyph */}
                      <Square className="w-3.5 h-3.5 fill-current text-white" />
                    </motion.button>
                  ) : (
                    <motion.button
                      key="send-button"
                      type="submit"
                      disabled={!displayValue.trim() || isRecording}
                      initial={{ scale: 0.8, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1 }}
                      exit={{ scale: 0.8, opacity: 0 }}
                      whileHover={{ scale: displayValue.trim() ? 1.06 : 1 }}
                      whileTap={{ scale: displayValue.trim() ? 0.94 : 1 }}
                      className={`ml-1 p-2 rounded-full flex items-center justify-center transition-all duration-200 shrink-0 ${
                        displayValue.trim()
                          ? 'bg-[#111] text-white hover:bg-black shadow-md cursor-pointer'
                          : 'bg-transparent text-[#111] opacity-30 cursor-not-allowed'
                      }`}
                      title="Send message"
                    >
                      <ArrowUp className="w-4 h-4" />
                    </motion.button>
                  )}
                </AnimatePresence>
              </div>
            </div>
          </>
        )}
      </form>
    </div>
  )
}
