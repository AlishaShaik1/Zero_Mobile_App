'use client'

import { useState, useCallback, useEffect } from 'react'
import { ChatWindow } from './layout/ChatWindow'
import { ChatSidebar } from './layout/Sidebar'
import { PageNav } from './nav/PageNav'
import { useChat } from '@/hooks/useChat'
import { useChatHistory } from '@/hooks/useChatHistory'
import { AuthProvider, useAuth } from '@/hooks/useAuth'
import { AuthModal, AuthModalView } from '@/components/auth/AuthModal'
import { SoftGateModal } from '@/components/auth/SoftGateModal'

function ZeroChatContent() {
  const { user } = useAuth()
  const [chatSidebarOpen, setChatSidebarOpen] = useState(false)
  const [pageNavOpen, setPageNavOpen] = useState(false)
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null)

  // Auth Modals state
  const [authModalOpen, setAuthModalOpen] = useState(false)
  const [authModalView, setAuthModalView] = useState<AuthModalView>('login')
  const [softGateOpen, setSoftGateOpen] = useState(false)

  // Multi-session history
  const {
    sessions,
    groupedSessions,
    isLoading: isHistoryLoading,
    searchQuery,
    setSearchQuery,
    createSession,
    renameSession,
    deleteSession,
    updateSessionMetadata,
    refreshSessions,
  } = useChatHistory(user?.id)

  // Auto-detect password recovery in URL
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const urlParams = new URLSearchParams(window.location.search)
      const hashParams = new URLSearchParams(window.location.hash.substring(1))

      if (urlParams.get('view') === 'reset-password' || hashParams.get('type') === 'recovery') {
        setAuthModalView('reset-password')
        setAuthModalOpen(true)
      }
    }
  }, [])

  // Refetch sessions when user logs in or out
  useEffect(() => {
    refreshSessions()
  }, [user, refreshSessions])

  const handleSessionCreated = useCallback((newId: string, initialTitle: string) => {
    setActiveSessionId(newId)
    updateSessionMetadata(newId, { title: initialTitle, message_count: 1 })
  }, [updateSessionMetadata])

  const handleTitleGenerated = useCallback((targetId: string, title: string) => {
    updateSessionMetadata(targetId, { title })
  }, [updateSessionMetadata])

  const chatState = useChat({
    sessionId: activeSessionId,
    onSessionCreated: handleSessionCreated,
    onTitleGenerated: handleTitleGenerated,
  })

  // Intercept send to track 5-question soft gate for guest users
  const handleSendMessage = useCallback(async (text: string, modelName?: string, webSearch?: boolean) => {
    if (!user) {
      try {
        const rawCount = localStorage.getItem('zero_guest_msg_count') || '0'
        const count = parseInt(rawCount, 10) + 1
        localStorage.setItem('zero_guest_msg_count', count.toString())

        const isDismissed = localStorage.getItem('zero_soft_gate_dismissed') === 'true'

        if (count >= 5 && !isDismissed) {
          setSoftGateOpen(true)
        }
      } catch { }
    }

    return chatState.send(text, modelName, webSearch)
  }, [user, chatState])

  const handleNewChat = useCallback(async () => {
    const newId = await createSession('New Chat')
    setActiveSessionId(newId)
    chatState.setMessages([])
    chatState.setActiveArtifact(null)
  }, [createSession, chatState])

  const handleSelectSession = useCallback((sessionId: string) => {
    setActiveSessionId(sessionId)
  }, [])

  const handleDeleteSession = useCallback((id: string) => {
    deleteSession(id)
    if (activeSessionId === id) {
      setActiveSessionId(null)
      chatState.setMessages([])
      chatState.setActiveArtifact(null)
    }
  }, [deleteSession, activeSessionId, chatState])

  const handleSoftGateSignIn = () => {
    setSoftGateOpen(false)
    setAuthModalView('signup')
    setAuthModalOpen(true)
  }

  const handleSoftGateSignInLater = () => {
    setSoftGateOpen(false)
    try {
      localStorage.setItem('zero_soft_gate_dismissed', 'true')
    } catch { }
  }

  return (
    <div className="flex h-[100dvh] w-full bg-[#F8F7F3] overflow-hidden text-[#111111] font-sans selection:bg-[#22C8FF] selection:text-white">
      {/* Left: collapsible chat panel with full multi-session history & profile avatar */}
      <ChatSidebar
        open={chatSidebarOpen}
        onClose={() => setChatSidebarOpen(false)}
        activeSessionId={activeSessionId}
        onSessionSelect={handleSelectSession}
        onNewChat={handleNewChat}
        sessions={sessions}
        groupedSessions={groupedSessions}
        onRenameSession={renameSession}
        onDeleteSession={handleDeleteSession}
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        isLoading={isHistoryLoading}
        onOpenAuthModal={() => {
          setAuthModalView('login')
          setAuthModalOpen(true)
        }}
      />

      {/* Right: page navigation (Zero Ring, Cowork, API, Research) */}
      <PageNav open={pageNavOpen} onClose={() => setPageNavOpen(false)} />

      {/* Full-width chat window */}
      <ChatWindow
        sidebarOpen={chatSidebarOpen}
        onChatMenuClick={() => setChatSidebarOpen(prev => !prev)}
        onPageNavClick={() => setPageNavOpen(true)}
        chatState={{
          ...chatState,
          sendMessage: handleSendMessage,
          send: handleSendMessage,
        }}
        onNewChat={handleNewChat}
      />

      {/* ── Soft Gate Prompt (Appears on 5th question for guests) ── */}
      <SoftGateModal
        isOpen={softGateOpen}
        onSignIn={handleSoftGateSignIn}
        onSignInLater={handleSoftGateSignInLater}
      />

      {/* ── Production Authentication Modal (Login / Signup / Forgot Password) ── */}
      <AuthModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        initialView={authModalView}
        onSuccess={() => {
          refreshSessions()
        }}
      />
    </div>
  )
}

export function ZeroChat() {
  return (
    <AuthProvider>
      <ZeroChatContent />
    </AuthProvider>
  )
}
