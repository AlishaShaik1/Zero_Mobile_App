'use client';

import React from 'react';
import { motion } from 'framer-motion';
import { TitanLogo } from './BrandLogos';
import { Sparkles, Zap, Shield, Bot, ArrowUpRight, Terminal, Cpu } from 'lucide-react';
import Link from 'next/link';

export function ModelComparisonHero() {
  return (
    <div className="w-full max-w-6xl mx-auto mb-16">
      {/* Badge */}
      <div className="flex justify-center mb-6">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/5 border border-white/10 backdrop-blur-md text-white/80 text-xs font-mono">
          <Sparkles className="w-3.5 h-3.5 text-[#00C8FF] animate-pulse" />
          <span>Zero Labs · Titan Research & Benchmark Report 2026</span>
        </div>
      </div>

      {/* Main Title */}
      <div className="text-center max-w-3xl mx-auto mb-12">
        <h1 className="text-3xl sm:text-5xl md:text-6xl font-bold tracking-tight text-white mb-6 leading-tight">
          Next-Generation Native <br className="hidden sm:inline" />
          <span className="bg-gradient-to-r from-[#00C8FF] via-[#A855F7] to-[#F59E0B] bg-clip-text text-transparent">
            Agentic & Reasoning Intelligence
          </span>
        </h1>
        <p className="text-base sm:text-lg text-white/70 leading-relaxed max-w-2xl mx-auto">
          Titan is a dual-tier foundation architecture engineered for autonomous agent trajectories, verifiable multi-hop code reasoning, and sub-second tool execution.
        </p>

        {/* Action buttons */}
        <div className="flex items-center justify-center gap-4 mt-8 flex-wrap">
          <Link
            href="/chat"
            className="px-6 py-3 rounded-full bg-[#00C8FF] text-black font-semibold text-sm hover:bg-[#38BDF8] transition-all shadow-[0_0_25px_rgba(0,200,255,0.4)] flex items-center gap-2"
          >
            <span>Try Titan in Zero Chat</span>
            <ArrowUpRight className="w-4 h-4" />
          </Link>
          <a
            href="#benchmarks"
            className="px-6 py-3 rounded-full bg-white/10 hover:bg-white/15 text-white font-semibold text-sm border border-white/10 transition-all backdrop-blur-md"
          >
            Explore 12 Benchmarks ↓
          </a>
        </div>
      </div>

      {/* Dual Tier Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-8">
        {/* Titan Pro Thinking */}
        <motion.div
          whileHover={{ y: -4 }}
          transition={{ duration: 0.2 }}
          className="relative bg-gradient-to-b from-[#141414] to-[#0A0A0A] border border-[#00C8FF]/30 rounded-3xl p-6 sm:p-8 shadow-2xl flex flex-col justify-between overflow-hidden"
        >
          <div className="absolute top-0 right-0 w-64 h-64 bg-[#00C8FF]/10 rounded-full blur-3xl pointer-events-none" />

          <div>
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-2xl bg-[#00C8FF]/10 border border-[#00C8FF]/30 flex items-center justify-center">
                  <TitanLogo className="w-6 h-5" />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-white tracking-tight">Zero Titan Pro Thinking</h3>
                  <span className="text-[11px] font-mono text-[#00C8FF]">High-Efficiency Agentic Engine by Zero</span>
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-full bg-[#00C8FF]/10 border border-[#00C8FF]/30 text-[#00C8FF] text-[10px] font-mono font-bold">
                ZERO PRO TIER
              </span>
            </div>

            <p className="text-xs sm:text-sm text-white/70 leading-relaxed mb-6">
              Trained by Zero Labs for rapid interactive coding, streaming shell commands, instant tool dispatch, and step-by-step verified chain-of-thought with ultra-low latency.
            </p>

            {/* Spec Matrix */}
            <div className="grid grid-cols-2 gap-3 mb-6 font-mono text-xs">
              <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5">
                <span className="text-white/40 text-[10px] block mb-1">Context Window</span>
                <span className="text-white font-bold">128,000 Tokens</span>
              </div>
              <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5">
                <span className="text-white/40 text-[10px] block mb-1">Reasoning Style</span>
                <span className="text-[#00C8FF] font-bold">Self-Verified CoT</span>
              </div>
              <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5">
                <span className="text-white/40 text-[10px] block mb-1">SWE-bench Verified</span>
                <span className="text-[#00C8FF] font-bold">71.6% Resolved</span>
              </div>
              <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5">
                <span className="text-white/40 text-[10px] block mb-1">AIME 2026 Score</span>
                <span className="text-[#00C8FF] font-bold">83.8% Pass@1</span>
              </div>
            </div>
          </div>

          <div className="pt-4 border-t border-white/10 flex items-center justify-between text-xs text-white/50">
            <span className="flex items-center gap-1.5">
              <Zap className="w-3.5 h-3.5 text-[#00C8FF]" />
              Sub-30ms Time to First Token
            </span>
            <span className="text-[#00C8FF] font-mono font-semibold">Active in Zero Chat</span>
          </div>
        </motion.div>

        {/* Titan Ultra Thinking */}
        <motion.div
          whileHover={{ y: -4 }}
          transition={{ duration: 0.2 }}
          className="relative bg-gradient-to-b from-[#171124] to-[#0D0814] border border-purple-500/40 rounded-3xl p-6 sm:p-8 shadow-2xl flex flex-col justify-between overflow-hidden"
        >
          <div className="absolute top-0 right-0 w-64 h-64 bg-purple-500/15 rounded-full blur-3xl pointer-events-none" />

          <div>
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-2xl bg-purple-500/20 border border-purple-500/40 flex items-center justify-center">
                  <TitanLogo className="w-6 h-5" />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-white tracking-tight">Zero Titan Ultra Thinking</h3>
                  <span className="text-[11px] font-mono text-purple-300">Frontier Flagship Reasoning by Zero</span>
                </div>
              </div>
              <span className="px-2.5 py-1 rounded-full bg-purple-500/20 border border-purple-500/40 text-purple-300 text-[10px] font-mono font-bold">
                ZERO FLAGSHIP SOTA
              </span>
            </div>

            <p className="text-xs sm:text-sm text-white/70 leading-relaxed mb-6">
              Zero Labs flagship multi-modal reasoning engine equipped with comprehensive deep trajectory planning, competitive Olympiad mathematics, polyglot software engineering, and multi-tool orchestration.
            </p>

            {/* Spec Matrix */}
            <div className="grid grid-cols-2 gap-3 mb-6 font-mono text-xs">
              <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5">
                <span className="text-white/40 text-[10px] block mb-1">Context Window</span>
                <span className="text-white font-bold">128,000 Tokens</span>
              </div>
              <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5">
                <span className="text-white/40 text-[10px] block mb-1">Reasoning Style</span>
                <span className="text-purple-300 font-bold">Deep Verification Hop</span>
              </div>
              <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5">
                <span className="text-white/40 text-[10px] block mb-1">SWE-bench Verified</span>
                <span className="text-purple-300 font-bold">79.3% Resolved</span>
              </div>
              <div className="p-3 rounded-xl bg-white/[0.03] border border-white/5">
                <span className="text-white/40 text-[10px] block mb-1">AIME 2026 Score</span>
                <span className="text-purple-300 font-bold">93.2% Pass@1</span>
              </div>
            </div>
          </div>

          <div className="pt-4 border-t border-white/10 flex items-center justify-between text-xs text-white/50">
            <span className="flex items-center gap-1.5">
              <Shield className="w-3.5 h-3.5 text-purple-400" />
              SOTA across 12 Benchmark Disciplines
            </span>
            <span className="text-purple-300 font-mono font-semibold">Active in Zero Chat</span>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
