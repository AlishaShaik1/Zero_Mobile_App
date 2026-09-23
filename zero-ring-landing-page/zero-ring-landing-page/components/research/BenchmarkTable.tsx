'use client';

import React, { useState } from 'react';
import { BENCHMARKS, BenchmarkItem } from './benchmarkData';
import { TitanLogo, OpenAILogo, AnthropicLogo, GoogleLogo, SarvamLogo, DeepSeekLogo } from './BrandLogos';

export function BenchmarkTable() {
  const [activeCategory, setActiveCategory] = useState<string>('All');

  const filtered = activeCategory === 'All'
    ? BENCHMARKS
    : BENCHMARKS.filter(b => b.category === activeCategory);

  const categories = ['All', 'Agentic', 'Coding', 'Reasoning', 'Tools & MCP', 'Multimodal'];

  return (
    <div className="w-full bg-[#141414] border border-white/10 rounded-2xl p-4 sm:p-6 overflow-hidden shadow-2xl">
      {/* Category Pills */}
      <div className="flex items-center gap-2 overflow-x-auto pb-4 mb-2 border-b border-white/5 scrollbar-none">
        {categories.map(cat => (
          <button
            key={cat}
            onClick={() => setActiveCategory(cat)}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
              activeCategory === cat
                ? 'bg-[#00C8FF] text-black shadow-[0_0_15px_rgba(0,200,255,0.4)]'
                : 'bg-white/5 text-white/70 hover:bg-white/10 hover:text-white'
            }`}
          >
            {cat} {cat === 'All' ? `(${BENCHMARKS.length})` : ''}
          </button>
        ))}
      </div>

      {/* Table Container */}
      <div className="overflow-x-auto">
        <table className="w-full text-left text-xs border-collapse">
          <thead>
            <tr className="border-b border-white/10 text-white/50 font-mono uppercase tracking-wider text-[11px]">
              <th className="py-3.5 px-3 min-w-[200px]">Benchmark</th>
              <th className="py-3.5 px-3">Category</th>
              <th className="py-3.5 px-3 bg-purple-950/30 text-purple-300 font-bold border-x border-purple-500/20">
                <div className="flex items-center gap-1.5">
                  <TitanLogo className="w-4 h-4" />
                  <span>Zero Titan Ultra</span>
                </div>
              </th>
              <th className="py-3.5 px-3 bg-[#00C8FF]/10 text-[#00C8FF] font-bold border-r border-[#00C8FF]/20">
                <div className="flex items-center gap-1.5">
                  <TitanLogo className="w-4 h-4" />
                  <span>Zero Titan Pro</span>
                </div>
              </th>
              <th className="py-3.5 px-3">
                <div className="flex items-center gap-1.5">
                  <OpenAILogo className="w-3.5 h-3.5 text-emerald-400" />
                  <span>GPT-5.6 Luna</span>
                </div>
              </th>
              <th className="py-3.5 px-3">
                <div className="flex items-center gap-1.5">
                  <AnthropicLogo className="w-3.5 h-3.5 text-amber-400" />
                  <span>Claude 4.6</span>
                </div>
              </th>
              <th className="py-3.5 px-3">
                <div className="flex items-center gap-1.5">
                  <GoogleLogo className="w-3.5 h-3.5" />
                  <span>Gemini 3.5</span>
                </div>
              </th>
              <th className="py-3.5 px-3">
                <div className="flex items-center gap-1.5">
                  <SarvamLogo className="w-3.5 h-3.5" />
                  <span>Sarvam 105B</span>
                </div>
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5 font-mono">
            {filtered.map((item) => {
              const gptScore = item.scores.find(s => s.brand === 'openai')?.score;
              const claudeScore = item.scores.find(s => s.brand === 'anthropic')?.score;
              const geminiScore = item.scores.find(s => s.brand === 'google')?.score;
              const sarvamScore = item.scores.find(s => s.brand === 'sarvam')?.score;

              return (
                <tr key={item.id} className="hover:bg-white/[0.02] transition-colors">
                  <td className="py-3.5 px-3 font-sans font-medium text-white">
                    <div className="font-semibold">{item.title}</div>
                    <div className="text-[11px] font-mono text-white/40">{item.metric}</div>
                  </td>
                  <td className="py-3.5 px-3">
                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-white/5 border border-white/10 text-white/70">
                      {item.category}
                    </span>
                  </td>
                  <td className="py-3.5 px-3 bg-purple-950/20 text-purple-300 font-bold border-x border-purple-500/10">
                    <span className="text-sm">{item.titanUltraScore.toFixed(1)}%</span>
                  </td>
                  <td className="py-3.5 px-3 bg-[#00C8FF]/5 text-[#00C8FF] font-bold border-r border-[#00C8FF]/10">
                    <span className="text-sm">{item.titanProScore.toFixed(1)}%</span>
                  </td>
                  <td className="py-3.5 px-3 text-white/70">
                    {gptScore !== undefined ? `${gptScore.toFixed(1)}%` : '—'}
                  </td>
                  <td className="py-3.5 px-3 text-white/70">
                    {claudeScore !== undefined ? `${claudeScore.toFixed(1)}%` : '—'}
                  </td>
                  <td className="py-3.5 px-3 text-white/70">
                    {geminiScore !== undefined ? `${geminiScore.toFixed(1)}%` : '—'}
                  </td>
                  <td className="py-3.5 px-3 text-white/70">
                    {sarvamScore !== undefined ? `${sarvamScore.toFixed(1)}%` : '—'}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
