'use client'

import { useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X, ArrowUpRight } from 'lucide-react'
import { usePathname } from 'next/navigation'

interface PageNavProps {
    open: boolean
    onClose: () => void
}

const rawSections = [
    {
        heading: 'Products',
        links: [
            { label: 'Zero Ring', sub: 'The AI that lives on your finger', href: '/' },
            { label: 'Zero AI', sub: 'High-performance AI chat & sandbox', href: '/chat' },
            { label: 'Zero Co-work', sub: 'Screen vision & autonomous PC agent', href: '/cowork' },
        ],
    },
    {
        heading: 'Developers & Research',
        links: [
            { label: 'Research', sub: 'Architectures, papers & benchmarks', href: '/research' },
        ],
    },
]

export function PageNav({ open, onClose }: PageNavProps) {
    const pathname = usePathname()

    // Close on Escape key
    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if (e.key === 'Escape' && open) onClose()
        }
        window.addEventListener('keydown', handleKeyDown)
        return () => window.removeEventListener('keydown', handleKeyDown)
    }, [open, onClose])

    return (
        <AnimatePresence>
            {open && (
                <>
                    {/* Backdrop */}
                    <motion.div
                        key="pn-backdrop"
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        transition={{ duration: 0.2 }}
                        className="fixed inset-0 z-[190] bg-black/40 backdrop-blur-[4px]"
                        onClick={onClose}
                    />

                    {/* Side Drawer Panel */}
                    <motion.nav
                        key="pn-panel"
                        initial={{ x: '100%' }}
                        animate={{ x: 0 }}
                        exit={{ x: '100%' }}
                        transition={{ type: 'spring', stiffness: 360, damping: 36 }}
                        className="fixed right-0 top-0 bottom-0 z-[200] w-[340px] sm:w-[420px] max-w-[90vw] flex flex-col bg-[#F8F7F3] border-l border-[#E5E4DF] shadow-[-20px_0_60px_rgba(0,0,0,0.15)] font-sans"
                        style={{ fontFamily: 'var(--font-space-grotesk), sans-serif' }}
                    >
                        {/* Header */}
                        <div className="flex items-center justify-between px-6 pt-6 pb-4 border-b border-[#E5E4DF]">
                            <a href="/" onClick={onClose} className="flex items-center">
                                <img
                                    src="/logo.png?v=2"
                                    alt="Zero AI"
                                    className="h-8 object-contain"
                                    draggable="false"
                                />
                            </a>
                            <button
                                onClick={onClose}
                                className="p-2 rounded-xl bg-white border border-[#E5E4DF] hover:bg-[#111]/5 text-[#111]/70 hover:text-[#111] transition-all shadow-xs cursor-pointer"
                                aria-label="Close menu"
                                title="Close"
                            >
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        {/* Navigation Sections */}
                        <div className="flex-1 overflow-y-auto px-5 py-6 space-y-7">
                            {rawSections.map((section, si) => (
                                <div key={section.heading}>
                                    <p className="px-3 mb-3 text-[11px] font-mono font-bold tracking-[0.14em] uppercase text-[#00C8FF]">
                                        {section.heading}
                                    </p>
                                    <div className="flex flex-col gap-1.5">
                                        {section.links.map((link, li) => {
                                            const isActive = pathname === link.href
                                            return (
                                                <motion.a
                                                    key={link.label}
                                                    href={link.href}
                                                    onClick={onClose}
                                                    initial={{ opacity: 0, y: 10 }}
                                                    animate={{ opacity: 1, y: 0 }}
                                                    transition={{ delay: si * 0.08 + li * 0.05 + 0.05, duration: 0.25 }}
                                                    className={`group flex items-center justify-between px-4 py-3.5 rounded-2xl transition-all border ${
                                                        isActive
                                                            ? 'bg-white border-[#00C8FF]/40 shadow-[0_4px_16px_rgba(0,200,255,0.1)]'
                                                            : 'bg-white/60 hover:bg-white border-transparent hover:border-[#E5E4DF] shadow-xs'
                                                    }`}
                                                >
                                                    <div className="flex flex-col">
                                                        <div className="flex items-center gap-2">
                                                            {isActive && (
                                                                <span className="w-1.5 h-1.5 rounded-full bg-[#00C8FF]" />
                                                            )}
                                                            <span className={`text-[15px] font-bold tracking-tight ${
                                                                isActive ? 'text-[#111]' : 'text-[#111]/85 group-hover:text-[#111]'
                                                            }`}>
                                                                {link.label}
                                                            </span>
                                                        </div>
                                                        <span className="text-[12.5px] text-[#111]/50 mt-0.5 font-normal">
                                                            {link.sub}
                                                        </span>
                                                    </div>

                                                    <ArrowUpRight className={`w-4 h-4 transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5 ${
                                                        isActive ? 'text-[#00C8FF]' : 'text-[#111]/30 group-hover:text-[#111]'
                                                    }`} />
                                                </motion.a>
                                            )
                                        })}
                                    </div>
                                </div>
                            ))}
                        </div>

                        {/* Footer */}
                        <div className="px-6 py-4 border-t border-[#E5E4DF] bg-white/40 flex items-center justify-between text-[11px] text-[#111]/40 font-mono">
                            <span>Zero Labs Inc.</span>
                            <span>© 2026</span>
                        </div>
                    </motion.nav>
                </>
            )}
        </AnimatePresence>
    )
}
