'use client'

import { motion, type Variants } from 'framer-motion'
import { useState } from 'react'
import { Smartphone, MonitorSmartphone, Monitor, ArrowRight, CheckCircle2, Menu, Sparkles, Mic, Eye, Terminal, Clock, ShieldCheck, Zap } from 'lucide-react'
import { PageNav } from '@/components/chat/nav/PageNav'

const sectionVariants: Variants = {
  hidden: { opacity: 0, y: 30 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: [0.16, 1, 0.3, 1] as const } },
}

export default function CoworkPage() {
  const [navOpen, setNavOpen] = useState(false)

  return (
    <div className="min-h-screen bg-[#F8F7F3] selection:bg-[#22C8FF] selection:text-white" style={{ fontFamily: 'var(--font-space-grotesk), sans-serif' }}>
      {/* ── HEADER ── */}
      <header className="absolute top-0 left-0 right-0 h-24 flex items-center justify-between px-6 md:px-12 z-50">
        <a href="/" className="flex items-center hover:opacity-80 transition-opacity">
          <img src="/logo.png?v=2" alt="Zero AI" className="h-11 sm:h-12 md:h-14 object-contain" draggable="false" />
        </a>
        <button
          onClick={() => setNavOpen(true)}
          className="p-2.5 rounded-xl bg-white/90 border border-[#E5E4DF] hover:bg-[rgba(34,200,255,0.1)] text-[#111111]/70 hover:text-[#00C8FF] transition-all shadow-xs cursor-pointer"
          aria-label="Open menu"
        >
          <Menu className="w-6 h-6" />
        </button>
      </header>

      {/* Sleek Side Drawer */}
      <PageNav open={navOpen} onClose={() => setNavOpen(false)} />

      {/* ── MAIN HERO SECTION ── */}
      <main className="pt-36 pb-28 px-4 sm:px-8 md:px-12 max-w-6xl mx-auto flex flex-col items-center text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="w-full max-w-3xl flex flex-col items-center"
        >
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#00C8FF]/10 border border-[#00C8FF]/30 text-[#00C8FF] text-xs font-bold tracking-widest uppercase mb-6">
            <MonitorSmartphone className="w-4 h-4" />
            Zero Co-work Ecosystem
          </div>
          <h1 className="text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tighter text-[#111111] mb-6 leading-[0.95]">
            Your personal <br className="hidden md:block" />
            <span className="text-[#00C8FF]">AI work buddy.</span>
          </h1>
          <p className="text-lg md:text-xl text-[#111111]/65 max-w-2xl mx-auto leading-relaxed mb-16">
            The Co-work Ring connects seamlessly to your phone and Windows PC. Speak a command into the ring, and watch Zero observe your screen, write code, and execute workflows in real time.
          </p>
        </motion.div>

        {/* ── THE TWO APPS (WITH COMING SOON THEME BUTTONS) ── */}
        <div className="grid md:grid-cols-2 gap-8 w-full max-w-4xl mx-auto mb-24">
          {/* Zero Mobile App Card */}
          <motion.div
            variants={sectionVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            className="bg-white rounded-[32px] p-8 sm:p-9 border border-[#E5E4DF] shadow-[0_12px_40px_rgba(0,0,0,0.04)] text-left flex flex-col justify-between relative overflow-hidden"
          >
            <div>
              <div className="flex items-center justify-between mb-6">
                <div className="w-14 h-14 bg-[#F8F7F3] rounded-2xl flex items-center justify-center border border-[#E5E4DF]">
                  <Smartphone className="w-7 h-7 text-[#111111]" />
                </div>
                <span className="text-xs font-mono font-bold tracking-wider text-[#00C8FF] uppercase bg-[#00C8FF]/10 px-3 py-1 rounded-full border border-[#00C8FF]/20">
                  Mobile Control
                </span>
              </div>
              <h3 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-[#111111] mb-3">Zero App</h3>
              <p className="text-[#111111]/65 leading-relaxed mb-6 text-[15px]">
                The command hub in your pocket. Manages your ring's ultra-low latency Bluetooth 5.3 connection and handles on-the-go mobile tasks instantly.
              </p>
              <ul className="space-y-3.5 mb-8">
                {["iOS & Android Native Support", "Instant Zero-Lag Voice Processing", "Encrypted Background Relay Network"].map(f => (
                  <li key={f} className="flex items-center gap-3 text-sm font-semibold text-[#111111]/80">
                    <CheckCircle2 className="w-4 h-4 text-[#00C8FF] shrink-0" /> {f}
                  </li>
                ))}
              </ul>
            </div>

            {/* Theme Coming Soon Button */}
            <div className="pt-4 border-t border-[#E5E4DF]">
              <button
                type="button"
                className="w-full py-3.5 px-4 rounded-xl bg-[#0A0A0A] text-white font-bold text-xs uppercase tracking-wider border-2 border-[#0A0A0A] shadow-[4px_4px_0_#00C8FF] flex items-center justify-center gap-2 transition-all cursor-default"
              >
                <Smartphone className="w-4 h-4" />
                <span>iOS & Android App</span>
                <span className="text-[10px] bg-[#00C8FF] text-[#0A0A0A] font-extrabold px-2.5 py-0.5 rounded-full tracking-normal ml-1">
                  Coming Soon
                </span>
              </button>
            </div>
          </motion.div>

          {/* Zero Desktop Agent Card */}
          <motion.div
            variants={sectionVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            className="bg-[#0D0D0D] rounded-[32px] p-8 sm:p-9 shadow-[0_20px_60px_rgba(0,0,0,0.18)] text-left flex flex-col justify-between relative overflow-hidden border border-white/10"
          >
            <div>
              <div className="flex items-center justify-between mb-6">
                <div className="w-14 h-14 bg-white/10 rounded-2xl flex items-center justify-center border border-white/10">
                  <Monitor className="w-7 h-7 text-[#00C8FF]" />
                </div>
                <span className="text-xs font-mono font-bold tracking-wider text-[#00C8FF] uppercase bg-[#00C8FF]/10 px-3 py-1 rounded-full border border-[#00C8FF]/30">
                  Windows 11 Native
                </span>
              </div>
              <h3 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-white mb-3">Zero Desktop</h3>
              <p className="text-white/65 leading-relaxed mb-6 text-[15px]">
                Your powerful autonomous companion. Zero Desktop reads your active screen context, manipulates IDEs and files, and completes complex PC workflows.
              </p>
              <ul className="space-y-3.5 mb-8">
                {["Windows 11 Hardware Acceleration", "60fps Screen Vision Awareness", "Autonomous File & CLI Automation"].map(f => (
                  <li key={f} className="flex items-center gap-3 text-sm font-semibold text-white/85">
                    <CheckCircle2 className="w-4 h-4 text-[#00C8FF] shrink-0" /> {f}
                  </li>
                ))}
              </ul>
            </div>

            {/* Theme Coming Soon Button */}
            <div className="pt-4 border-t border-white/10">
              <button
                type="button"
                className="w-full py-3.5 px-4 rounded-xl bg-white text-[#0A0A0A] font-bold text-xs uppercase tracking-wider border-2 border-white shadow-[4px_4px_0_#00C8FF] flex items-center justify-center gap-2 transition-all cursor-default"
              >
                <Monitor className="w-4 h-4" />
                <span>Windows 11 Agent</span>
                <span className="text-[10px] bg-[#00C8FF] text-[#0A0A0A] font-extrabold px-2.5 py-0.5 rounded-full tracking-normal ml-1">
                  Coming Soon
                </span>
              </button>
            </div>
          </motion.div>
        </div>

        {/* ── PREMIUM DETAILED "HOW IT WORKS" WORKFLOW SECTION ── */}
        <motion.div
          variants={sectionVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true }}
          className="w-full max-w-5xl bg-white border border-[#E5E4DF] rounded-[36px] p-8 sm:p-12 md:p-14 shadow-[0_16px_48px_rgba(0,0,0,0.04)] text-left relative overflow-hidden"
        >
          {/* Section Header */}
          <div className="text-center max-w-2xl mx-auto mb-14">
            <div className="inline-flex items-center gap-2 px-3.5 py-1 rounded-full bg-[#00C8FF]/10 text-[#00C8FF] text-xs font-mono font-bold tracking-widest uppercase mb-3 border border-[#00C8FF]/20">
              <Zap className="w-3.5 h-3.5" />
              Autonomous Pipeline
            </div>
            <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-[#111111] mb-3">
              How Zero Co-work operates
            </h2>
            <p className="text-[#111111]/60 text-[15px] leading-relaxed">
              From a whispered thought into your ring to zero-touch execution on your desktop.
            </p>
          </div>

          {/* 3 Step Connected Cards */}
          <div className="grid md:grid-cols-3 gap-6 lg:gap-8 relative">
            {/* Step 1 */}
            <div className="bg-[#FAF9F5] border border-[#E5E4DF] rounded-3xl p-6 flex flex-col justify-between hover:shadow-md transition-all">
              <div>
                <div className="flex items-center justify-between mb-4">
                  <span className="w-10 h-10 rounded-xl bg-[#111111] text-white font-extrabold text-sm flex items-center justify-center shadow-xs">
                    01
                  </span>
                  <div className="flex items-center gap-1 text-[#00C8FF]">
                    <Mic className="w-4 h-4" />
                    <span className="text-[11px] font-mono font-bold tracking-wider uppercase">Voice Capture</span>
                  </div>
                </div>
                <h4 className="font-bold text-[#111111] text-lg mb-2">Speak to the Ring</h4>
                <p className="text-xs sm:text-[13px] text-[#111111]/60 leading-relaxed mb-4">
                  Dual beamforming MEMS microphones capture natural speech with instant on-device wake.
                </p>
              </div>

              <div className="bg-white border border-[#E5E4DF] rounded-2xl p-3.5 shadow-xs">
                <p className="text-[11px] text-[#111111]/40 font-mono mb-1 uppercase tracking-wider">Spoken Prompt</p>
                <p className="text-xs text-[#111111] font-semibold italic">
                  "Open my laptop and send the PPT file in WhatsApp to Mohedin."
                </p>
              </div>
            </div>

            {/* Step 2 */}
            <div className="bg-[#FAF9F5] border border-[#E5E4DF] rounded-3xl p-6 flex flex-col justify-between hover:shadow-md transition-all">
              <div>
                <div className="flex items-center justify-between mb-4">
                  <span className="w-10 h-10 rounded-xl bg-[#00C8FF] text-[#0A0A0A] font-extrabold text-sm flex items-center justify-center shadow-xs">
                    02
                  </span>
                  <div className="flex items-center gap-1 text-[#00C8FF]">
                    <Eye className="w-4 h-4" />
                    <span className="text-[11px] font-mono font-bold tracking-wider uppercase">Screen Vision</span>
                  </div>
                </div>
                <h4 className="font-bold text-[#111111] text-lg mb-2">Zero Vision Relays</h4>
                <p className="text-xs sm:text-[13px] text-[#111111]/60 leading-relaxed mb-4">
                  Zero App securely relays encrypted intent; Desktop vision observes active windows and finds target files.
                </p>
              </div>

              <div className="bg-white border border-[#00C8FF]/30 rounded-2xl p-3.5 shadow-xs">
                <div className="flex items-center gap-2 mb-1">
                  <span className="w-2 h-2 rounded-full bg-[#00C8FF] animate-pulse" />
                  <span className="text-[11px] font-mono font-bold text-[#00C8FF] uppercase">60fps Screen Stream</span>
                </div>
                <p className="text-xs text-[#111111]/75 font-medium">
                  Located <code className="text-[#00C8FF] bg-black/5 px-1 py-0.5 rounded font-mono text-[11px]">presentation.pptx</code> in workspace.
                </p>
              </div>
            </div>

            {/* Step 3 */}
            <div className="bg-[#FAF9F5] border border-[#E5E4DF] rounded-3xl p-6 flex flex-col justify-between hover:shadow-md transition-all">
              <div>
                <div className="flex items-center justify-between mb-4">
                  <span className="w-10 h-10 rounded-xl bg-[#111111] text-white font-extrabold text-sm flex items-center justify-center shadow-xs">
                    03
                  </span>
                  <div className="flex items-center gap-1 text-[#22C55E]">
                    <Terminal className="w-4 h-4" />
                    <span className="text-[11px] font-mono font-bold tracking-wider uppercase">Executed</span>
                  </div>
                </div>
                <h4 className="font-bold text-[#111111] text-lg mb-2">Desktop Executes</h4>
                <p className="text-xs sm:text-[13px] text-[#111111]/60 leading-relaxed mb-4">
                  Zero Desktop launches applications, attaches payload, and delivers confirmation back to your ring.
                </p>
              </div>

              <div className="bg-[#0A0A0A] rounded-2xl p-3.5 text-white font-mono text-xs shadow-[0_4px_16px_rgba(0,0,0,0.15)] border border-white/10">
                <div className="flex items-center gap-1.5 mb-1.5 opacity-40">
                  <span className="w-2 h-2 rounded-full bg-[#FF5F56]" />
                  <span className="w-2 h-2 rounded-full bg-[#FFBD2E]" />
                  <span className="w-2 h-2 rounded-full bg-[#27C93F]" />
                </div>
                <p className="text-white/60 text-[11px]">&gt; Launching WhatsApp...</p>
                <p className="text-white/60 text-[11px]">&gt; Attaching presentation.pptx</p>
                <p className="text-[#00C8FF] text-[11px] font-bold">&gt; Sent to Mohedin ✓ (1.2s)</p>
              </div>
            </div>
          </div>

          {/* Bottom Security & Guarantee Banner */}
          <div className="mt-10 pt-8 border-t border-[#E5E4DF] flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-[#111111]/60 font-medium">
            <div className="flex items-center gap-2">
              <ShieldCheck className="w-4 h-4 text-[#00C8FF]" />
              <span>End-to-end encrypted device pairing over local network</span>
            </div>
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-[#00C8FF]" />
              <span>Average voice-to-action execution latency: &lt;1.5s</span>
            </div>
          </div>
        </motion.div>
      </main>
    </div>
  )
}
