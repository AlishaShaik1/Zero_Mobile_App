'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Sparkles, Terminal, Cpu, ShieldCheck, GitBranch, Layers, ArrowRight, Check } from 'lucide-react';

export function TrainingMethodology() {
  const [activeTab, setActiveTab] = useState<number>(0);

  const pillars = [
    {
      id: 'agent-trajectories',
      title: 'Agent Trajectory Pre-Training',
      icon: Terminal,
      accent: '#00C8FF',
      tag: 'Data Architecture',
      headline: 'Trained on 4.2M Multi-Turn Autonomous Execution Loops',
      description:
        'Rather than training solely on static code repositories, Titan was initialized on dense interactive trajectories: bash shell sessions, LSP compiler diagnostics, multi-file diff trees, browser DOM manipulation rollouts, and runtime error-recovery paths.',
      bullets: [
        'Multi-file workspace synchronization & diff tree generation',
        'Stateful terminal execution with error-recovery loops',
        'Model Context Protocol (MCP) tool chaining traces',
        'Polyglot runtime debugging across Python, Rust, Go, TypeScript & C++',
      ],
      codeSnippet: `// Synthetic Trajectory Step Trace
<thought>
Step 1: Inspect failing unit test 'test_token_stream_interrupted'
Action: Execute pytest --capture=no tests/test_stream.py
Observation: Exit code 1: ConnectionResetError on line 142
Verification: Trace indicates race condition in SSE buffer flush
Refinement: Apply mutex lock around buffer chunk dispatch
</thought>`,
    },
    {
      id: 'sft-dpo',
      title: 'Curated SFT + DPO Preference Tuning',
      icon: Layers,
      accent: '#A855F7',
      tag: 'Optimization',
      headline: 'Dual-Phase Alignment for Extreme Precision and Verifiability',
      description:
        'We employ Supervised Fine-Tuning (SFT) on curated high-density reasoning proofs, followed by Direct Preference Optimization (DPO) calibrated against deterministic environment execution outcomes rather than generic human conversational preference.',
      bullets: [
        'Strict JSON schema and tool execution parameter validation',
        'Reward signal directly tied to test suite pass rates and compiler linter clearance',
        'Negative-sample suppression against hallucinated API functions',
        'Direct minimization of token bloat for sub-25ms time-to-first-token',
      ],
      codeSnippet: `// DPO Execution Reward Loss Calibration
L_DPO = -E [ log σ( β * log( π_θ(y_w | x) / π_ref(y_w | x) ) 
                 - β * log( π_θ(y_l | x) / π_ref(y_l | x) ) ) ]
where:
  y_w: Trajectory successfully compiling & passing all unit tests
  y_l: Trajectory causing runtime exceptions or lint regression`,
    },
    {
      id: 'distillation',
      title: 'Proprietary Frontier Teacher Distillation',
      icon: Cpu,
      accent: '#F59E0B',
      tag: 'Model Architecture',
      headline: 'Distilled Knowledge from an Undisclosed Flagship Frontier Teacher',
      description:
        'Titan Pro and Titan Ultra condense the multi-modal reasoning capabilities of our massive undisclosed frontier teacher model into ultra-compact, hyper-efficient parameters capable of real-time edge and serverless streaming.',
      bullets: [
        'Cross-entropy logit distillation on token probability distributions',
        'Intermediate attention-map matching for multi-hop mathematical deductions',
        'Zero parameter bloat with maximized reasoning throughput',
        'Hardware-accelerated KV-cache optimizations for long-context 128k windows',
      ],
      codeSnippet: `// Knowledge Transfer Loss Formulation
L_total = (1 - α) * L_CE(y, σ(z_student)) 
        + α * T² * KL( σ(z_teacher / T) || σ(z_student / T) )
where:
  T: Temperature scaling parameter (T = 2.4)
  Teacher: Undisclosed Flagship Multi-Stage Reasoning Engine`,
    },
    {
      id: 'self-verification-cot',
      title: 'Step-by-Step Self-Verification CoT',
      icon: ShieldCheck,
      accent: '#10B981',
      tag: 'Inference Engine',
      headline: 'Native Internal Verification at Every Reasoning Hop',
      description:
        'Titan features internal chain-of-thought (CoT) self-verification. At every intermediate reasoning leap, internal verification tokens independently audit preceding logic before committing to code generation or external tool invocations.',
      bullets: [
        'Zero-shot self-correction before emitting code modifications',
        'Constraint auditing for edge cases, null checks, and boundary conditions',
        'Sub-hypothesis validation for complex mathematical Olympiad proofs',
        'Dynamic reflection tokens preventing cascading agentic hallucinations',
      ],
      codeSnippet: `// Native Self-Verification Reasoning Stream
<thinking>
1. Formulate solution: Calculate optimal bounding box for canvas layout
2. Interim hypothesis: Use (x + width, y + height) offset
3. [INTERNAL VERIFICATION]: Check boundary case where zoom_level < 1.0
   Result: Offset diverges if devicePixelRatio is non-integer.
4. Correcting formula: Apply floor(coord * dpr) / dpr
5. Verification status: PASSED. Proceeding to code emission.
</thinking>`,
    },
  ];

  return (
    <div className="w-full bg-[#121212] border border-white/10 rounded-3xl p-6 sm:p-10 shadow-2xl relative overflow-hidden">
      {/* Glow background */}
      <div className="absolute top-0 right-0 w-96 h-96 bg-[#00C8FF]/5 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-0 left-0 w-96 h-96 bg-purple-500/5 rounded-full blur-3xl pointer-events-none" />

      {/* Section Header */}
      <div className="max-w-3xl mb-8">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/5 border border-white/10 text-white/70 text-xs font-mono mb-3">
          <Sparkles className="w-3.5 h-3.5 text-[#00C8FF]" />
          <span>Training Methodology & Architecture</span>
        </div>
        <h2 className="text-2xl sm:text-3xl font-bold text-white tracking-tight leading-snug">
          Why Titan Outperforms Monolithic Frontier Models
        </h2>
        <p className="text-sm sm:text-base text-white/60 mt-2 leading-relaxed">
          Titan achieves state-of-the-art benchmarks not through raw brute-force scale alone, but via an engineered synthesis of dense agent trajectories, verifiable reward alignment, frontier distillation, and step-level self-verification.
        </p>
      </div>

      {/* Tabs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-8">
        {pillars.map((pillar, idx) => {
          const Icon = pillar.icon;
          const isActive = activeTab === idx;
          return (
            <button
              key={pillar.id}
              onClick={() => setActiveTab(idx)}
              className={`text-left p-4 rounded-2xl border transition-all duration-200 flex flex-col justify-between ${
                isActive
                  ? 'bg-white/10 border-[#00C8FF]/60 shadow-[0_0_20px_rgba(0,200,255,0.15)]'
                  : 'bg-white/[0.02] border-white/5 hover:bg-white/[0.05] hover:border-white/10'
              }`}
            >
              <div className="flex items-center justify-between mb-3">
                <div
                  className="w-8 h-8 rounded-xl flex items-center justify-center"
                  style={{
                    backgroundColor: `${pillar.accent}20`,
                    color: pillar.accent,
                  }}
                >
                  <Icon className="w-4 h-4" />
                </div>
                <span className="text-[10px] font-mono text-white/40">{`0${idx + 1}`}</span>
              </div>
              <div>
                <span className="text-[10px] font-mono text-white/50 block mb-0.5">{pillar.tag}</span>
                <span className="text-xs sm:text-sm font-semibold text-white tracking-tight line-clamp-1">
                  {pillar.title}
                </span>
              </div>
            </button>
          );
        })}
      </div>

      {/* Active Tab Showcase */}
      <motion.div
        key={activeTab}
        initial={{ opacity: 0, y: 15 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="grid grid-cols-1 lg:grid-cols-12 gap-6 bg-black/40 border border-white/10 rounded-2xl p-5 sm:p-8 items-stretch"
      >
        {/* Left Column: Narrative & Bullets */}
        <div className="lg:col-span-7 flex flex-col justify-between">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span
                className="text-[11px] font-mono font-semibold px-2.5 py-0.5 rounded-md border"
                style={{
                  backgroundColor: `${pillars[activeTab].accent}15`,
                  color: pillars[activeTab].accent,
                  borderColor: `${pillars[activeTab].accent}30`,
                }}
              >
                {pillars[activeTab].tag}
              </span>
            </div>
            <h3 className="text-lg sm:text-xl font-bold text-white mb-3">
              {pillars[activeTab].headline}
            </h3>
            <p className="text-xs sm:text-sm text-white/70 leading-relaxed mb-6">
              {pillars[activeTab].description}
            </p>

            {/* Bullets */}
            <div className="space-y-2.5 mb-6">
              {pillars[activeTab].bullets.map((b, bi) => (
                <div key={bi} className="flex items-start gap-2 text-xs sm:text-sm text-white/80">
                  <div
                    className="w-4 h-4 rounded-full flex items-center justify-center shrink-0 mt-0.5"
                    style={{ backgroundColor: `${pillars[activeTab].accent}25`, color: pillars[activeTab].accent }}
                  >
                    <Check className="w-2.5 h-2.5" />
                  </div>
                  <span>{b}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="pt-4 border-t border-white/5 flex items-center gap-2 text-xs text-white/40 font-mono">
            <span>Titan Deep Learning Research Group</span>
            <span>·</span>
            <span>Technical Report 2026</span>
          </div>
        </div>

        {/* Right Column: Code & Mathematical Formulation */}
        <div className="lg:col-span-5 flex flex-col justify-center">
          <div className="w-full bg-[#0D0D0D] border border-white/10 rounded-xl overflow-hidden shadow-inner flex flex-col h-full">
            <div className="px-4 py-2.5 bg-white/5 border-b border-white/5 flex items-center justify-between">
              <div className="flex items-center gap-1.5">
                <div className="w-2.5 h-2.5 rounded-full bg-rose-500/80" />
                <div className="w-2.5 h-2.5 rounded-full bg-amber-500/80" />
                <div className="w-2.5 h-2.5 rounded-full bg-emerald-500/80" />
              </div>
              <span className="text-[11px] font-mono text-white/40">titan-spec.ts</span>
            </div>
            <pre className="p-4 text-[11px] sm:text-xs font-mono text-[#00C8FF] overflow-x-auto whitespace-pre leading-relaxed flex-1 bg-black/60">
              <code>{pillars[activeTab].codeSnippet}</code>
            </pre>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
