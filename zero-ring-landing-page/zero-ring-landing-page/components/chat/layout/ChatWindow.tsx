'use client'

import { useState, useRef, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { PanelLeft, Menu, Square } from 'lucide-react'
import { MessageCard } from '../messages/MessageCard'
import { WelcomeScreen } from './WelcomeScreen'
import { InputBar } from '../input/InputBar'
import { useChat } from '@/hooks/useChat'
import { ArtifactViewer } from '../artifacts/ArtifactViewer'
import UniversalMascot, { MascotHandle } from '../UniversalMascot'
import { Message } from '@/types'

interface ChatWindowProps {
  onChatMenuClick: () => void
  onPageNavClick: () => void
  sidebarOpen?: boolean
  chatState?: ReturnType<typeof useChat>
  onNewChat?: () => void
}

export function ChatWindow({ onChatMenuClick, onPageNavClick, sidebarOpen, chatState: passedChatState, onNewChat }: ChatWindowProps) {
  const localChatState = useChat();
  const {
    messages,
    sendMessage,
    stop,
    isTyping,
    searchStatus,
    activeSkill,
    activeArtifact,
    setActiveArtifact,
    activeModelName,
    isLoadingSession,
  } = (passedChatState || localChatState) as any;
  const scrollContainerRef = useRef<HTMLDivElement>(null)
  const isAtBottomRef = useRef<boolean>(true)
  const chatBoxRef = useRef<HTMLDivElement>(null)
  const mascotRef = useRef<MascotHandle | null>(null)
  const [inputCollapsed, setInputCollapsed] = useState(false)
  const [isScrolled, setIsScrolled] = useState(false)

  // Automatically collapse composer into compact pill when messages are present
  useEffect(() => {
    if (messages.length > 0) {
      setInputCollapsed(true)
    }
  }, [messages.length])

  const handleScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const target = e.currentTarget
    const threshold = 120
    const isBottom = target.scrollHeight - target.scrollTop - target.clientHeight < threshold
    isAtBottomRef.current = isBottom

    if (messages.length > 0) {
      // Whenever user scrolls up or down, collapse the input into the single-line pill
      setInputCollapsed(true)
      setIsScrolled(target.scrollTop > 15)
    }
  }

  useEffect(() => {
    if (isAtBottomRef.current && scrollContainerRef.current) {
      scrollContainerRef.current.scrollTop = scrollContainerRef.current.scrollHeight
    }
    if (messages.length > 0) {
      const lastMsg = messages[messages.length - 1]
      if (lastMsg.role === 'assistant' || (lastMsg.role as string) === 'ai') {
        mascotRef.current?.reactToMessage(lastMsg.text)
      }
    }
  }, [messages, isTyping])

  const currentModelLabel = activeModelName || 'Titan Pro';
  const isUltraModel = currentModelLabel.toLowerCase().includes('ultra');

  return (
    <div ref={chatBoxRef} className="flex-1 flex flex-col h-[100dvh] w-full relative overflow-hidden bg-[#F8F7F3]">

      {/* ── Top floating bar (overlay, hides on scroll like ChatGPT) ── */}
      <div className={`absolute top-0 left-0 right-0 z-30 flex items-center justify-between px-4 sm:px-6 pointer-events-none transition-all duration-300 ${
        messages.length === 0 ? 'pt-4 pb-2' : 'pt-3 pb-2'
      }`}>
        {/* Left: Mobile sidebar menu (mobile only) */}
        <div className="flex items-center gap-1.5 pointer-events-auto">
          <button
            onClick={onChatMenuClick}
            className="md:hidden p-2 rounded-xl bg-white/80 backdrop-blur-md border border-[#E5E4DF]/60 hover:bg-[rgba(34,200,255,0.1)] text-[#111111]/60 hover:text-[#22C8FF] transition-all shadow-sm"
            aria-label="Open sidebar"
            title="Open sidebar"
          >
            <PanelLeft className="w-5 h-5" />
          </button>
        </div>

        {/* Centre: logo (welcome screen) or Zero Workspace (fades out on scroll) */}
        {messages.length === 0 ? (
          <a href="/" className="pointer-events-auto flex items-center justify-center hover:opacity-80 transition-opacity">
            <img src="/logo.png?v=2" alt="Zero AI" className="h-10 sm:h-12 md:h-13 object-contain" draggable="false" />
          </a>
        ) : (
          <div className={`transition-all duration-300 ${isScrolled ? 'opacity-0 -translate-y-2 pointer-events-none' : 'opacity-100 translate-y-0'}`}>
            <div className="flex items-center gap-2 text-xs font-semibold text-[#111111]/40 uppercase tracking-widest select-none bg-white/70 backdrop-blur-md px-3 py-1 rounded-full border border-black/5 shadow-xs">
              <span className={`w-1.5 h-1.5 rounded-full ${isUltraModel ? 'bg-[#9333EA]' : 'bg-[#00C8FF]'}`} />
              <span>{currentModelLabel} Workspace</span>
            </div>
          </div>
        )}

        {/* Right: Page navigation */}
        <div className="flex items-center gap-1.5 pointer-events-auto">
          <button
            onClick={onPageNavClick}
            className="p-2 rounded-xl bg-white/80 backdrop-blur-md border border-[#E5E4DF]/60 hover:bg-[rgba(34,200,255,0.1)] text-[#111111]/60 hover:text-[#22C8FF] transition-all shadow-sm cursor-pointer"
            aria-label="Navigation menu"
            title="Pages"
          >
            <Menu className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* ── Scrollable messages ───────────────────────────────────── */}
      <div
        ref={scrollContainerRef}
        onScroll={handleScroll}
        className="flex-1 overflow-y-auto overscroll-contain min-h-0"
      >
        <div className={`min-h-full flex flex-col ${messages.length === 0 ? 'justify-end' : 'justify-start'}`}>
          {isLoadingSession ? (
            /* ── Skeleton loader for smooth chat transitions ── */
            <div className="max-w-4xl xl:max-w-5xl 2xl:max-w-6xl w-full mx-auto px-4 sm:px-8 md:px-12 pt-16 pb-36 flex flex-col gap-6 animate-pulse">
              <div className="flex justify-end">
                <div className="w-48 h-10 bg-black/5 rounded-2xl" />
              </div>
              <div className="flex justify-start flex-col gap-2">
                <div className="w-24 h-4 bg-black/5 rounded" />
                <div className="w-full max-w-lg h-24 bg-black/5 rounded-2xl" />
              </div>
              <div className="flex justify-end">
                <div className="w-64 h-10 bg-black/5 rounded-2xl" />
              </div>
              <div className="flex justify-start flex-col gap-2">
                <div className="w-24 h-4 bg-black/5 rounded" />
                <div className="w-full max-w-xl h-32 bg-black/5 rounded-2xl" />
              </div>
            </div>
          ) : messages.length === 0 ? (
            <WelcomeScreen
              mascotRef={mascotRef}
              onSelectTask={(prompt, search) => sendMessage(prompt, activeModelName, !!search)}
            >
              <InputBar onSend={sendMessage} onStop={stop} isTyping={isTyping} />
            </WelcomeScreen>
          ) : (
            <div className="max-w-4xl xl:max-w-5xl 2xl:max-w-6xl w-full mx-auto px-4 sm:px-8 md:px-12 pt-12 pb-36 flex flex-col">
              <AnimatePresence>
                {(() => {
                  const visibleMessages = (messages || []).filter(
                    (msg: Message) => msg.role === 'user' || msg.text.trim() || (msg.artifacts && msg.artifacts.length > 0)
                  );
                  return visibleMessages.map((msg: Message, index: number) => {
                    const isLastAssistant = msg.role === 'assistant' && index === visibleMessages.length - 1;
                    return (
                      <MessageCard
                        key={msg.id}
                        message={msg}
                        isStreaming={isTyping && isLastAssistant}
                        onArtifactView={setActiveArtifact}
                      />
                    );
                  });
                })()}

                {isTyping && (
                  <motion.div
                    key="thinking-indicator"
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    transition={{ duration: 0.2 }}
                    className="flex w-full justify-start mb-6"
                  >
                    <div className="flex flex-col max-w-full">
                      <div className="flex items-center gap-2 mb-2 pl-0.5">
                        <span className={`w-1.5 h-1.5 rounded-full ${isUltraModel ? 'bg-[#9333EA]' : 'bg-[#00C8FF]'}`} />
                        <span className={`text-xs font-semibold uppercase tracking-widest ${
                          isUltraModel ? 'text-[#9333EA]' : 'text-[#111] opacity-50'
                        }`}>
                          {currentModelLabel}
                        </span>
                      </div>
                      <div className="flex items-center gap-3 bg-white/90 backdrop-blur-md border border-[#E5E4DF] rounded-2xl px-4 py-3 shadow-[0_4px_24px_rgba(0,0,0,0.04)]">
                        {/* Unified Zero Ring Electric Cyan / Ultra Purple Orbit Animation */}
                        <div className="relative flex items-center justify-center w-5 h-5 shrink-0">
                          <motion.div
                            animate={{ rotate: 360 }}
                            transition={{ duration: 1.3, repeat: Infinity, ease: 'linear' }}
                            className={`w-5 h-5 rounded-full border-[2px] ${
                              isUltraModel
                                ? 'border-[#9333EA]/20 border-t-[#9333EA] border-r-[#9333EA]'
                                : 'border-[#00C8FF]/20 border-t-[#00C8FF] border-r-[#00C8FF]'
                            }`}
                          />
                          <motion.div
                            animate={{ scale: [0.75, 1.2, 0.75], opacity: [0.4, 1, 0.4] }}
                            transition={{ duration: 1.3, repeat: Infinity, ease: 'easeInOut' }}
                            className={`absolute w-1.5 h-1.5 rounded-full ${
                              isUltraModel ? 'bg-[#9333EA] shadow-[0_0_8px_rgba(147,51,234,0.7)]' : 'bg-[#00C8FF] shadow-[0_0_8px_rgba(0,200,255,0.7)]'
                            }`}
                          />
                        </div>

                        {/* Fluid Wave Dots & Status Text */}
                        <div className="flex items-center gap-2.5 flex-wrap">
                          <div className="flex items-center gap-1">
                            {[0, 1, 2].map((i) => (
                              <motion.span
                                key={i}
                                animate={{
                                  y: [0, -4, 0],
                                  opacity: [0.35, 1, 0.35],
                                  scale: [0.85, 1.15, 0.85],
                                }}
                                transition={{
                                  duration: 0.9,
                                  repeat: Infinity,
                                  delay: i * 0.15,
                                  ease: 'easeInOut',
                                }}
                                className={`w-1.5 h-1.5 rounded-full ${isUltraModel ? 'bg-[#9333EA]' : 'bg-[#00C8FF]'}`}
                              />
                            ))}
                          </div>

                          {activeSkill && (
                            <span className="text-xs font-semibold px-2 py-0.5 rounded-md bg-sky-100 text-sky-800 border border-sky-200/80 animate-pulse flex items-center gap-1">
                              <span>⚡</span>
                              <span>Loading {activeSkill}…</span>
                            </span>
                          )}

                          <span className="text-sm font-medium text-[#111111]/70 tracking-tight">
                            {searchStatus || (activeSkill ? '' : `Thinking with ${currentModelLabel}…`)}
                          </span>
                        </div>
                      </div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
              <div className="h-4" />
            </div>
          )}
        </div>
      </div>

      {/* Artifact viewer */}
      {activeArtifact && (
        <ArtifactViewer artifact={activeArtifact} onClose={() => setActiveArtifact(null)} />
      )}

      {/* Floating glass bottom composer */}
      {messages.length > 0 && (
        <div id="composer" className="absolute bottom-0 left-0 right-0 z-20 pointer-events-none pb-4 pt-3 bg-gradient-to-t from-[#F8F7F3]/50 via-[#F8F7F3]/20 to-transparent">
          <div className="max-w-4xl xl:max-w-5xl 2xl:max-w-6xl mx-auto px-4 sm:px-8 md:px-12 pointer-events-auto">
            <InputBar
              onSend={sendMessage}
              onStop={stop}
              isTyping={isTyping}
              collapsed={inputCollapsed}
              onExpand={() => setInputCollapsed(false)}
            />
          </div>
        </div>
      )}
    </div>
  )
}
