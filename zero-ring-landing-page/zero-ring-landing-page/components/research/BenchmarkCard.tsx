'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { BenchmarkItem, BenchmarkModelScore } from './benchmarkData';
import { TitanLogo, OpenAILogo, AnthropicLogo, GoogleLogo, SarvamLogo, DeepSeekLogo } from './BrandLogos';
import { Info, CheckCircle2, ChevronRight } from 'lucide-react';

interface BenchmarkCardProps {
  benchmark: BenchmarkItem;
  index: number;
}

function renderBrandIcon(brand: BenchmarkModelScore['brand']) {
  switch (brand) {
    case 'titan':
      return <TitanLogo className="w-5 h-4 object-contain" />;
    case 'openai':
      return <OpenAILogo className="w-3.5 h-3.5 text-emerald-400" />;
    case 'anthropic':
      return <AnthropicLogo className="w-3.5 h-3.5 text-amber-400" />;
    case 'google':
      return <GoogleLogo className="w-3.5 h-3.5" />;
    case 'sarvam':
      return <SarvamLogo className="w-3.5 h-3.5" />;
    case 'deepseek':
      return <DeepSeekLogo className="w-3.5 h-3.5" />;
    default:
      return null;
  }
}

export function BenchmarkCard({ benchmark, index }: BenchmarkCardProps) {
  const [showInfo, setShowInfo] = useState(false);

  // Highest competitor score for comparison
  const highestCompetitor = benchmark.scores
    .filter(s => s.type === 'competitor')
    .reduce((max, s) => Math.max(max, s.score), 0);

  const delta = (benchmark.titanUltraScore - highestCompetitor).toFixed(1);

  // Maximum value for bar scaling (normalized to e.g. 100 or max+10)
  const maxScore = 100;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, delay: index * 0.05 }}
      className="relative flex flex-col bg-[#161616]/90 backdrop-blur-xl border border-white/10 hover:border-white/20 rounded-2xl p-5 shadow-[0_4px_30px_rgba(0,0,0,0.5)] transition-all duration-300 group hover:shadow-[0_8px_40px_rgba(0,200,255,0.08)]"
    >
      {/* Header */}
      <div className="flex items-start justify-between gap-3 mb-3">
        <div>
          <div className="flex items-center gap-2 mb-1 flex-wrap">
            <span
              className={`text-[10px] font-mono font-semibold px-2 py-0.5 rounded-full border ${
                benchmark.category === 'Agentic'
                  ? 'bg-[#00C8FF]/10 text-[#00C8FF] border-[#00C8FF]/30'
                  : benchmark.category === 'Coding'
                  ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                  : benchmark.category === 'Reasoning'
                  ? 'bg-amber-500/10 text-amber-400 border-amber-500/30'
                  : benchmark.category === 'Tools & MCP'
                  ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                  : 'bg-rose-500/10 text-rose-400 border-rose-500/30'
              }`}
            >
              {benchmark.category}
            </span>
            <span className="text-[11px] text-white/40 font-mono">{benchmark.metric}</span>
          </div>
          <h3 className="text-base font-bold text-white tracking-tight flex items-center gap-2">
            {benchmark.title}
          </h3>
        </div>

        {/* Info Toggle */}
        <button
          type="button"
          onClick={() => setShowInfo(!showInfo)}
          className="p-1.5 rounded-lg text-white/40 hover:text-white/90 hover:bg-white/5 transition-colors"
          title="Benchmark details & evaluation methodology"
          aria-label="Toggle benchmark details"
        >
          <Info className="w-4 h-4" />
        </button>
      </div>

      {/* Domain Subheading */}
      <p className="text-xs text-white/60 mb-4 line-clamp-2 leading-relaxed">
        {benchmark.summary}
      </p>

      {/* Info popover if active */}
      {showInfo && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          exit={{ opacity: 0, height: 0 }}
          className="mb-4 p-3 bg-black/60 border border-white/10 rounded-xl text-xs text-white/80 space-y-1.5"
        >
          <p><strong className="text-white">Domain:</strong> {benchmark.domain}</p>
          <p><strong className="text-white">Setup:</strong> {benchmark.evaluationSetup}</p>
          <p className="text-white/60 text-[11px] pt-1">{benchmark.description}</p>
        </motion.div>
      )}

      {/* Clustered Bars */}
      <div className="space-y-2.5 my-auto pt-1 pb-2">
        {benchmark.scores.map((s, si) => {
          const isUltra = s.type === 'titan-ultra';
          const isPro = s.type === 'titan-pro';
          const isTitan = isUltra || isPro;
          const pct = Math.min(100, Math.max(10, (s.score / maxScore) * 100));

          return (
            <div key={s.name} className="flex flex-col gap-1">
              <div className="flex items-center justify-between text-xs font-medium">
                <div className="flex items-center gap-1.5">
                  <div className="w-4 h-4 flex items-center justify-center">
                    {renderBrandIcon(s.brand)}
                  </div>
                  <span
                    className={`text-[12px] truncate max-w-[170px] ${
                      isUltra
                        ? 'text-purple-300 font-bold'
                        : isPro
                        ? 'text-[#00C8FF] font-bold'
                        : 'text-white/70'
                    }`}
                  >
                    {s.name}
                  </span>
                </div>
                <div className="flex items-center gap-1 font-mono text-[12px]">
                  <span
                    className={
                      isUltra
                        ? 'text-purple-300 font-bold'
                        : isPro
                        ? 'text-[#00C8FF] font-bold'
                        : 'text-white/60'
                    }
                  >
                    {s.score.toFixed(1)}%
                  </span>
                </div>
              </div>

              {/* Bar track */}
              <div className="relative w-full h-2.5 bg-white/5 rounded-full overflow-hidden">
                <motion.div
                  initial={{ width: 0 }}
                  whileInView={{ width: `${pct}%` }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.8, delay: 0.1 + si * 0.06, ease: 'easeOut' }}
                  className={`h-full rounded-full ${
                    isUltra
                      ? 'bg-gradient-to-r from-[#9333EA] via-[#A855F7] to-[#C084FC] shadow-[0_0_12px_rgba(168,85,247,0.6)]'
                      : isPro
                      ? 'bg-gradient-to-r from-[#0284C7] via-[#00C8FF] to-[#38BDF8] shadow-[0_0_12px_rgba(0,200,255,0.6)]'
                      : 'bg-white/20'
                  }`}
                />
              </div>
            </div>
          );
        })}
      </div>

      {/* Delta Footer Badge */}
      <div className="mt-3 pt-3 border-t border-white/5 flex items-center justify-between text-[11px]">
        <span className="text-white/40 flex items-center gap-1">
          <CheckCircle2 className="w-3.5 h-3.5 text-[#00C8FF]" />
          Self-verified CoT
        </span>
        <span className="text-purple-300 font-mono font-semibold bg-purple-950/50 border border-purple-500/30 px-2 py-0.5 rounded-md">
          +{delta}% vs Frontier SOTA
        </span>
      </div>
    </motion.div>
  );
}
