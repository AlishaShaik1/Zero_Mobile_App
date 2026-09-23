'use client'

import { motion, AnimatePresence } from 'framer-motion'
import {
  SquarePen,
  Search,
  Folder,
  Brain,
  FileText,
  Settings,
  X,
  MessageSquare,
  Trash2,
  Edit2,
  Check,
  Download,
  Loader2,
  User,
  LogOut,
  Sparkles,
  ShieldCheck,
  ChevronDown
} from 'lucide-react'
import Link from 'next/link'
import { useState, useRef, useEffect } from 'react'
import { ChatSession, GroupedSessions } from '@/types'
import { getOrCreateUserUid } from '@/lib/storage/identity'
import { useAuth } from '@/hooks/useAuth'

interface ChatSidebarProps {
  open?: boolean
  onClose?: () => void
  activeSessionId?: string | null
  onSessionSelect?: (sessionId: string) => void
  onNewChat?: () => void
  sessions?: ChatSession[]
  groupedSessions?: GroupedSessions
  onRenameSession?: (id: string, newTitle: string) => void
  onDeleteSession?: (id: string) => void
  searchQuery?: string
  onSearchChange?: (q: string) => void
  isLoading?: boolean
  onOpenAuthModal?: () => void
}

const navTools = [
  { icon: Search, label: 'Search', id: 'search' },
  { icon: Folder, label: 'Projects', id: 'projects' },
  { icon: Brain, label: 'Memory', id: 'memory' },
  { icon: FileText, label: 'Files', id: 'files' },
  { icon: Settings, label: 'Settings', id: 'settings' },
]

export function ChatSidebar({
  open = false,
  onClose,
  activeSessionId,
  onSessionSelect,
  onNewChat,
  groupedSessions,
  onRenameSession,
  onDeleteSession,
  searchQuery = '',
  onSearchChange,
  isLoading = false,
  onOpenAuthModal,
}: ChatSidebarProps) {
  const { user, signOut } = useAuth()
  const [isHovered, setIsHovered] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editTitle, setEditTitle] = useState('')
  const [isExporting, setIsExporting] = useState(false)
  const [profileMenuOpen, setProfileMenuOpen] = useState(false)
  const editInputRef = useRef<HTMLInputElement>(null)
  const profileMenuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (editingId && editInputRef.current) {
      editInputRef.current.focus()
      editInputRef.current.select()
    }
  }, [editingId])

  // Close profile menu on outside click
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (profileMenuRef.current && !profileMenuRef.current.contains(e.target as Node)) {
        setProfileMenuOpen(false)
      }
    }
    if (profileMenuOpen) {
      document.addEventListener('mousedown', handleClickOutside)
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [profileMenuOpen])

  const handleStartRename = (session: ChatSession, e: React.MouseEvent) => {
    e.stopPropagation()
    setEditingId(session.id)
    setEditTitle(session.title)
  }

  const handleSaveRename = (id: string, e?: React.FormEvent) => {
    if (e) e.preventDefault()
    if (onRenameSession && editTitle.trim()) {
      onRenameSession(id, editTitle.trim())
    }
    setEditingId(null)
  }

  const handleDelete = (id: string, e: React.MouseEvent) => {
    e.stopPropagation()
    if (onDeleteSession) {
      onDeleteSession(id)
    }
  }

  const handleExportTrainingData = async (e: React.MouseEvent) => {
    e.stopPropagation()
    try {
      setIsExporting(true)
      const uid = user?.id || getOrCreateUserUid()
      window.open(`/api/export/training-data?uid=${encodeURIComponent(uid)}`, '_blank')
    } catch (err) {
      console.error('Export failed:', err)
    } finally {
      setTimeout(() => setIsExporting(false), 1500)
    }
  }

  const userInitial = user?.email ? user.email.charAt(0).toUpperCase() : 'U'
  const userName = user?.user_metadata?.full_name || (user?.email ? user.email.split('@')[0] : 'Guest User')
  const userAvatarUrl = user?.user_metadata?.avatar_url

  const renderSessionGroup = (title: string, groupList?: ChatSession[]) => {
    if (!groupList || groupList.length === 0) return null

    return (
      <div className="mb-3">
        <div className="px-2.5 mb-1.5 text-[10.5px] font-semibold tracking-wider text-[#111111]/45 uppercase">
          {title}
        </div>
        <div className="flex flex-col gap-0.5">
          {groupList.map((session) => {
            const isActive = activeSessionId === session.id
            const isEditing = editingId === session.id

            return (
              <div
                key={session.id}
                onClick={() => {
                  if (!isEditing && onSessionSelect) {
                    onSessionSelect(session.id)
                    if (onClose) onClose()
                  }
                }}
                className={`
                  group relative flex items-center justify-between px-2.5 py-1.5 rounded-xl text-left text-[13px] font-medium transition-all cursor-pointer select-none
                  ${isActive
                    ? 'bg-[#ECEAE4] text-[#111111] font-semibold shadow-xs'
                    : 'text-[#111111]/70 hover:bg-[#EAE8E2] hover:text-[#111111]'
                  }
                `}
              >
                {/* Active Indicator Accent */}
                {isActive && (
                  <span className="absolute left-0 top-1.5 bottom-1.5 w-1 bg-[#00C8FF] rounded-r-full" />
                )}

                {isEditing ? (
                  <form
                    onSubmit={(e) => handleSaveRename(session.id, e)}
                    className="flex items-center gap-1.5 w-full"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <input
                      ref={editInputRef}
                      type="text"
                      value={editTitle}
                      onChange={(e) => setEditTitle(e.target.value)}
                      onBlur={() => handleSaveRename(session.id)}
                      onKeyDown={(e) => {
                        if (e.key === 'Escape') setEditingId(null)
                      }}
                      className="w-full bg-white border border-[#00C8FF] rounded px-2 py-0.5 text-xs text-[#111] outline-none"
                    />
                    <button
                      type="submit"
                      className="p-1 text-[#00C8FF] hover:bg-white rounded"
                    >
                      <Check className="w-3.5 h-3.5" />
                    </button>
                  </form>
                ) : (
                  <>
                    <div className="flex items-center gap-2 truncate flex-1 min-w-0 pr-1">
                      <MessageSquare className={`w-3.5 h-3.5 shrink-0 ${isActive ? 'text-[#00C8FF]' : 'text-[#111111]/40'}`} />
                      <span className="truncate tracking-tight text-xs">{session.title}</span>
                    </div>

                    {/* Action buttons on hover */}
                    <div className="flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button
                        type="button"
                        onClick={(e) => handleStartRename(session, e)}
                        className="p-1 rounded-md text-[#111]/50 hover:text-[#111] hover:bg-black/5"
                        title="Rename chat"
                      >
                        <Edit2 className="w-3 h-3" />
                      </button>
                      <button
                        type="button"
                        onClick={(e) => handleDelete(session.id, e)}
                        className="p-1 rounded-md text-[#111]/50 hover:text-rose-500 hover:bg-rose-50"
                        title="Delete chat"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </>
                )}
              </div>
            )
          })}
        </div>
      </div>
    )
  }

  const renderHistoryContent = () => {
    const hasAnySessions =
      groupedSessions &&
      (groupedSessions.today.length > 0 ||
        groupedSessions.yesterday.length > 0 ||
        groupedSessions.week.length > 0 ||
        groupedSessions.older.length > 0)

    if (isLoading) {
      return (
        <div className="flex flex-col gap-2 p-2">
          <div className="h-3.5 bg-black/5 rounded animate-pulse w-16 mb-1" />
          <div className="h-7 bg-black/5 rounded-xl animate-pulse" />
          <div className="h-7 bg-black/5 rounded-xl animate-pulse" />
        </div>
      )
    }

    if (!hasAnySessions) {
      return (
        <div className="px-3 py-3 text-left text-xs text-[#111111]/40 select-none">
          No previous chats yet
        </div>
      )
    }

    return (
      <div className="space-y-1">
        {renderSessionGroup('Today', groupedSessions?.today)}
        {renderSessionGroup('Yesterday', groupedSessions?.yesterday)}
        {renderSessionGroup('Previous 7 Days', groupedSessions?.week)}
        {renderSessionGroup('Older', groupedSessions?.older)}
      </div>
    )
  }

  return (
    <>
      {/* ── Mobile Backdrop (High z-index to block background items) ── */}
      <AnimatePresence>
        {open && (
          <motion.div
            key="mobile-backdrop"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="md:hidden fixed inset-0 z-[190] bg-black/60 backdrop-blur-[3px]"
            onClick={onClose}
          />
        )}
      </AnimatePresence>

      {/* ── Desktop Hover-Expandable Sidebar Rail ──────────────────── */}
      <motion.aside
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        initial={false}
        animate={{
          width: isHovered ? 250 : 68,
        }}
        transition={{
          type: 'spring',
          stiffness: 380,
          damping: 32,
        }}
        className={`
          hidden md:flex flex-col shrink-0 h-[100dvh] z-30
          bg-[#F8F7F3] border-r border-[#E5E4DF] overflow-hidden
          ${isHovered ? 'shadow-[8px_0_32px_rgba(0,0,0,0.06)]' : ''}
          transition-shadow duration-300 relative
        `}
      >
        <div className="w-[250px] h-full flex flex-col justify-between py-3.5">
          {/* TOP SECTION: Logo + New Chat + Primary Tools (ChatGPT Layout) */}
          <div className="flex flex-col shrink-0">
            {/* Logo */}
            <div className="pb-2 flex items-center h-13 overflow-visible shrink-0">
              <motion.div
                initial={false}
                animate={{
                  width: isHovered ? 250 : 68,
                }}
                transition={{
                  type: 'spring',
                  stiffness: 380,
                  damping: 32,
                }}
                className="flex items-center justify-center shrink-0"
              >
                <Link href="/" className="flex items-center justify-center group">
                  <motion.img
                    src="/logo.png?v=2"
                    alt="Zero"
                    initial={false}
                    animate={{
                      height: isHovered ? 42 : 28,
                      scale: isHovered ? 1.15 : 1,
                    }}
                    transition={{
                      type: 'spring',
                      stiffness: 380,
                      damping: 30,
                    }}
                    className="object-contain shrink-0 filter drop-shadow-sm group-hover:opacity-90"
                    draggable="false"
                  />
                </Link>
              </motion.div>
            </div>

            {/* New Chat Primary Action Button */}
            <div className="px-3 mb-1 shrink-0">
              <button
                type="button"
                onClick={() => {
                  if (onNewChat) onNewChat()
                }}
                className="w-full flex items-center gap-3.5 h-10 px-2.5 rounded-xl text-left text-[#111111]/75 hover:text-[#111111] hover:bg-[#ECEAE4] transition-all group cursor-pointer"
                title={!isHovered ? 'New Chat' : undefined}
              >
                <div className="w-8 h-8 flex items-center justify-center shrink-0">
                  <SquarePen className="w-5 h-5 text-[#111111]/70 group-hover:text-[#111111] group-hover:scale-110 transition-all stroke-[1.8]" />
                </div>
                <motion.span
                  initial={false}
                  animate={{
                    opacity: isHovered ? 1 : 0,
                    x: isHovered ? 0 : -6,
                  }}
                  transition={{ duration: 0.18 }}
                  className="text-[13.5px] font-semibold tracking-tight whitespace-nowrap overflow-hidden"
                >
                  New Chat
                </motion.span>
              </button>
            </div>

            {/* Top Navigation Tools: Search, Projects, Memory, Files, Settings */}
            <nav className="flex flex-col gap-0.5 px-3 pb-2 border-b border-[#E5E4DF]/70">
              {navTools.map((item) => {
                const Icon = item.icon
                return (
                  <button
                    key={item.id}
                    type="button"
                    className="w-full flex items-center gap-3.5 h-9 px-2.5 rounded-xl text-left text-[#111111]/70 hover:text-[#111111] hover:bg-[#ECEAE4] transition-all group cursor-pointer"
                    title={!isHovered ? item.label : undefined}
                  >
                    <div className="w-8 h-8 flex items-center justify-center shrink-0">
                      <Icon className="w-4.5 h-4.5 text-[#111111]/70 group-hover:text-[#111111] group-hover:scale-110 transition-all stroke-[1.8]" />
                    </div>

                    <motion.span
                      initial={false}
                      animate={{
                        opacity: isHovered ? 1 : 0,
                        x: isHovered ? 0 : -6,
                      }}
                      transition={{ duration: 0.18 }}
                      className="text-[13px] font-medium tracking-tight whitespace-nowrap overflow-hidden"
                    >
                      {item.label}
                    </motion.span>
                  </button>
                )
              })}
            </nav>
          </div>

          {/* MIDDLE SECTION: Recents (Previous Chats) seamlessly below top tools */}
          <div className="flex-1 min-h-0 overflow-y-auto px-2 pt-2.5">
            {isHovered ? (
              <div>
                <div className="px-2.5 mb-2 flex items-center justify-between text-[11px] font-bold text-[#111]/50 uppercase tracking-wider">
                  <span>Recents</span>
                  <ChevronDown className="w-3.5 h-3.5 text-[#111]/40" />
                </div>
                {renderHistoryContent()}
              </div>
            ) : (
              <div className="flex flex-col items-center gap-2 pt-2">
                <div className="w-2 h-2 rounded-full bg-[#111]/20" />
              </div>
            )}
          </div>

          {/* BOTTOM SECTION: User Profile / Sign In + Status */}
          <div className="pt-2 px-3 border-t border-[#E5E4DF] flex flex-col gap-1.5 shrink-0 relative">
            {/* Export Dataset Button */}
            {isHovered && (
              <button
                type="button"
                onClick={handleExportTrainingData}
                disabled={isExporting}
                className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-lg text-xs font-medium text-[#111]/60 hover:text-[#111] hover:bg-[#ECEAE4] transition-all cursor-pointer"
                title="Download JSONL dataset"
              >
                {isExporting ? (
                  <Loader2 className="w-3.5 h-3.5 animate-spin text-[#00C8FF]" />
                ) : (
                  <Download className="w-3.5 h-3.5 text-[#00C8FF]" />
                )}
                <span>Export Training Data</span>
              </button>
            )}

            {/* Profile Bar / Sign In */}
            <div className="relative" ref={profileMenuRef}>
              {user ? (
                <button
                  type="button"
                  onClick={() => setProfileMenuOpen((p) => !p)}
                  className="w-full flex items-center gap-3.5 h-10 px-2 rounded-xl hover:bg-[#ECEAE4] transition-all cursor-pointer text-left"
                >
                  <div className="w-8 h-8 flex items-center justify-center shrink-0">
                    {userAvatarUrl ? (
                      <img src={userAvatarUrl} alt={userName} className="w-7 h-7 rounded-full object-cover border border-[#E5E4DF]" />
                    ) : (
                      <div className="w-7 h-7 rounded-full bg-gradient-to-tr from-[#00C8FF] to-[#3B82F6] text-white font-bold text-xs flex items-center justify-center shadow-xs">
                        {userInitial}
                      </div>
                    )}
                  </div>

                  <motion.div
                    initial={false}
                    animate={{
                      opacity: isHovered ? 1 : 0,
                      x: isHovered ? 0 : -6,
                    }}
                    transition={{ duration: 0.18 }}
                    className="flex flex-col truncate min-w-0 flex-1 overflow-hidden"
                  >
                    <span className="text-[13px] font-semibold text-[#111] truncate">{userName}</span>
                    <span className="text-[10.5px] text-[#111]/50 truncate">{user.email}</span>
                  </motion.div>
                </button>
              ) : (
                <button
                  type="button"
                  onClick={() => {
                    if (onOpenAuthModal) onOpenAuthModal()
                  }}
                  className="w-full flex items-center gap-3.5 h-10 px-2 rounded-xl hover:bg-[#ECEAE4] transition-all cursor-pointer text-left text-[#111]"
                >
                  <div className="w-8 h-8 flex items-center justify-center shrink-0">
                    <div className="w-7 h-7 rounded-full bg-[#EAE8E2] border border-[#E5E4DF] flex items-center justify-center text-[#111]/70 relative">
                      <User className="w-3.5 h-3.5" />
                      <span className="absolute -top-0.5 -right-0.5 w-2 h-2 bg-[#00C8FF] rounded-full" />
                    </div>
                  </div>

                  <motion.div
                    initial={false}
                    animate={{
                      opacity: isHovered ? 1 : 0,
                      x: isHovered ? 0 : -6,
                    }}
                    transition={{ duration: 0.18 }}
                    className="flex flex-col min-w-0 overflow-hidden"
                  >
                    <span className="text-[13px] font-semibold text-[#111]">Sign In</span>
                    <span className="text-[10.5px] text-[#111]/50">Sync chats</span>
                  </motion.div>
                </button>
              )}

              {/* Profile Popover */}
              <AnimatePresence>
                {profileMenuOpen && user && (
                  <motion.div
                    initial={{ opacity: 0, y: 10, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    exit={{ opacity: 0, y: 10, scale: 0.95 }}
                    transition={{ duration: 0.15 }}
                    className="absolute bottom-12 left-0 w-60 bg-white border border-[#E5E4DF] rounded-2xl shadow-[0_12px_36px_rgba(0,0,0,0.12)] p-3 z-50 font-sans"
                  >
                    <div className="flex items-center gap-3 pb-3 border-b border-[#E5E4DF]/70">
                      {userAvatarUrl ? (
                        <img src={userAvatarUrl} alt={userName} className="w-9 h-9 rounded-full object-cover shrink-0" />
                      ) : (
                        <div className="w-9 h-9 rounded-full bg-gradient-to-tr from-[#00C8FF] to-[#3B82F6] text-white font-bold text-xs flex items-center justify-center shrink-0">
                          {userInitial}
                        </div>
                      )}
                      <div className="truncate min-w-0">
                        <div className="text-xs font-bold text-[#111] truncate">{userName}</div>
                        <div className="text-[11px] text-[#111]/50 truncate">{user.email}</div>
                      </div>
                    </div>

                    <div className="my-2 px-2.5 py-1.5 rounded-xl bg-[#00C8FF]/[0.08] border border-[#00C8FF]/20 flex items-center justify-between text-xs">
                      <div className="flex items-center gap-1.5 text-[#00C8FF] font-semibold">
                        <Sparkles className="w-3.5 h-3.5" />
                        <span>Zero Free Tier</span>
                      </div>
                      <span className="text-[10.5px] text-[#111]/50 font-medium">Active</span>
                    </div>

                    <div className="flex flex-col gap-1 pt-1">
                      <button
                        type="button"
                        onClick={() => {
                          setProfileMenuOpen(false)
                          if (onOpenAuthModal) onOpenAuthModal()
                        }}
                        className="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-xs font-medium text-[#111]/70 hover:bg-[#F8F7F3] hover:text-[#111] transition-all"
                      >
                        <ShieldCheck className="w-3.5 h-3.5 text-[#00C8FF]" />
                        <span>Account & Security</span>
                      </button>

                      <button
                        type="button"
                        onClick={async () => {
                          setProfileMenuOpen(false)
                          await signOut()
                        }}
                        className="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-xs font-medium text-rose-600 hover:bg-rose-50 transition-all"
                      >
                        <LogOut className="w-3.5 h-3.5" />
                        <span>Sign Out</span>
                      </button>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>

            {/* Status dot */}
            <div className="py-0.5 flex items-center gap-3 overflow-hidden px-1">
              <span className="w-2 h-2 rounded-full bg-[#22C8FF] animate-pulse shrink-0 ml-2" />
              <motion.span
                initial={false}
                animate={{ opacity: isHovered ? 1 : 0 }}
                transition={{ duration: 0.15 }}
                className="text-[11px] text-[#111111]/50 font-medium whitespace-nowrap"
              >
                Zero Ring Online
              </motion.span>
            </div>
          </div>
        </div>
      </motion.aside>

      {/* ── Mobile Sidebar Drawer (Solid background, z-[200] to fully hide robot mascot) ── */}
      <AnimatePresence>
        {open && (
          <motion.aside
            key="mobile-drawer"
            initial={{ x: '-100%' }}
            animate={{ x: 0 }}
            exit={{ x: '-100%' }}
            transition={{ type: 'spring', stiffness: 360, damping: 34 }}
            className="md:hidden fixed top-0 bottom-0 left-0 z-[200] w-[285px] max-w-[85vw] flex flex-col bg-[#F8F7F3] border-r border-[#E5E4DF] shadow-[16px_0_48px_rgba(0,0,0,0.25)] py-3 font-sans"
            style={{ fontFamily: 'var(--font-space-grotesk), sans-serif' }}
          >
            {/* Header: Logo + Close */}
            <div className="flex items-center justify-between px-4 pb-3 border-b border-[#E5E4DF]">
              <Link href="/" className="flex items-center" onClick={onClose}>
                <img src="/logo.png?v=2" alt="Zero" className="h-8 object-contain" draggable="false" />
              </Link>
              <button
                onClick={onClose}
                className="p-1.5 rounded-lg text-[#111]/50 hover:text-[#111] hover:bg-[#EAE8E3]"
                aria-label="Close sidebar"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Top: New Chat + Primary Tools (ChatGPT Layout) */}
            <div className="px-3 pt-3 pb-2 flex flex-col gap-1 border-b border-[#E5E4DF]/70">
              <button
                type="button"
                onClick={() => {
                  if (onNewChat) onNewChat()
                  if (onClose) onClose()
                }}
                className="w-full flex items-center gap-3 h-10 px-3 bg-white border border-[#E5E4DF] rounded-xl text-[13.5px] font-semibold text-[#111] shadow-xs mb-1"
              >
                <SquarePen className="w-4 h-4 text-[#00C8FF]" />
                <span>New Chat</span>
              </button>

              {navTools.map((item) => {
                const Icon = item.icon
                return (
                  <button
                    key={item.id}
                    type="button"
                    className="w-full flex items-center gap-3 h-8.5 px-2.5 rounded-lg text-left text-xs font-medium text-[#111]/75 hover:bg-[#ECEAE4]"
                  >
                    <Icon className="w-4 h-4 text-[#111]/60" />
                    <span>{item.label}</span>
                  </button>
                )
              })}
            </div>

            {/* Middle: Recents List (Previous Chats) without gap */}
            <div className="flex-1 min-h-0 overflow-y-auto px-3 py-3">
              <div className="px-1 mb-2 text-[11px] font-bold text-[#111]/45 uppercase tracking-wider">
                Recents
              </div>
              {renderHistoryContent()}
            </div>

            {/* Bottom: User Auth / Sign In Bar */}
            <div className="p-3 border-t border-[#E5E4DF] bg-white/50 flex flex-col gap-2">
              {user ? (
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2 min-w-0">
                    {userAvatarUrl ? (
                      <img src={userAvatarUrl} alt={userName} className="w-7 h-7 rounded-full object-cover border border-[#E5E4DF]" />
                    ) : (
                      <div className="w-7 h-7 rounded-full bg-[#00C8FF] text-white font-bold text-xs flex items-center justify-center shrink-0">
                        {userInitial}
                      </div>
                    )}
                    <span className="text-xs font-semibold text-[#111] truncate">{userName}</span>
                  </div>
                  <button
                    type="button"
                    onClick={async () => {
                      await signOut()
                      if (onClose) onClose()
                    }}
                    className="text-xs font-medium text-rose-600 hover:underline"
                  >
                    Sign Out
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => {
                    if (onOpenAuthModal) onOpenAuthModal()
                    if (onClose) onClose()
                  }}
                  className="w-full flex items-center justify-center gap-2 h-9 rounded-xl bg-white border border-[#E5E4DF] text-xs font-semibold text-[#111] shadow-xs cursor-pointer"
                >
                  <User className="w-3.5 h-3.5 text-[#00C8FF]" />
                  <span>Sign In / Create Account</span>
                </button>
              )}

              <div className="flex items-center justify-between pt-1 text-[11px] text-[#111]/50 font-medium">
                <button
                  type="button"
                  onClick={handleExportTrainingData}
                  className="flex items-center gap-1.5 hover:text-[#111] transition-colors"
                >
                  <Download className="w-3 h-3 text-[#00C8FF]" />
                  <span>Export Dataset</span>
                </button>
                <div className="flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#22C8FF] animate-pulse" />
                  <span>Zero Online</span>
                </div>
              </div>
            </div>
          </motion.aside>
        )}
      </AnimatePresence>
    </>
  )
}
