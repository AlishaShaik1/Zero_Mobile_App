'use client';

import React, { useState } from 'react';
import { ModelComparisonHero } from '@/components/research/ModelComparisonHero';
import { BenchmarkGrid } from '@/components/research/BenchmarkGrid';
import { TrainingMethodology } from '@/components/research/TrainingMethodology';
import { TitanLogo } from '@/components/research/BrandLogos';
import { PageNav } from '@/components/chat/nav/PageNav';
import { Menu, ArrowUpRight, Copy, Check, Terminal, Code2, BookOpen, ExternalLink, ShieldCheck } from 'lucide-react';
import Link from 'next/link';

export default function ResearchPage() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [copiedBibtex, setCopiedBibtex] = useState(false);
  const [copiedCode, setCopiedCode] = useState(false);

  const bibtex = `@article{zerolabs2026titan,
  title={Titan: Frontier Agentic Reasoning and Step-by-Step Self-Verification via Trajectory Alignment},
  author={Zero Labs Deep Learning Research Group},
  journal={Zero Technical Reports},
  year={2026},
  url={https://zero-tech.in/research}
}`;

  const apiSnippet = `import { ZeroClient } from '@zero-tech/sdk';

// Initialize Zero Client with Titan Ultra Thinking
const zero = new ZeroClient({
  apiKey: process.env.ZERO_API_KEY,
});

const response = await zero.chat.completions.create({
  model: 'titan-ultra', // Titan Ultra Thinking
  messages: [
    { role: 'user', content: 'Debug and refactor this distributed consensus worker.' }
  ],
  thinking: {
    mode: 'step_by_step_verify',
    max_reasoning_tokens: 4096,
  },
  stream: true,
});

for await (const chunk of response) {
  process.stdout.write(chunk.choices[0]?.delta?.content || '');
}`;

  const copyToClipboard = (text: string, isBibtex: boolean) => {
    navigator.clipboard.writeText(text);
    if (isBibtex) {
      setCopiedBibtex(true);
      setTimeout(() => setCopiedBibtex(false), 2000);
    } else {
      setCopiedCode(true);
      setTimeout(() => setCopiedCode(false), 2000);
    }
  };

  return (
    <div className="min-h-screen bg-[#0A0A0A] text-white selection:bg-[#00C8FF] selection:text-black font-sans">
      {/* ── Sticky Top Nav ─────────────────────────────────────── */}
      <header className="sticky top-0 z-50 bg-[#0A0A0A]/90 backdrop-blur-xl border-b border-white/10 px-4 sm:px-6 h-16 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <button
            onClick={() => setMenuOpen(true)}
            className="p-2 rounded-xl hover:bg-white/10 text-white/60 hover:text-white transition-colors"
            aria-label="Open Navigation"
          >
            <Menu className="w-5 h-5" />
          </button>

          <Link href="/" className="flex items-center gap-2">
            <img src="/logo.png?v=2" alt="Zero AI" className="h-7 object-contain brightness-0 invert" />
            <span className="text-xs font-mono px-2 py-0.5 rounded-full bg-white/10 text-white/80 border border-white/10">
              Research
            </span>
          </Link>
        </div>

        {/* Center Desktop Links */}
        <nav className="hidden md:flex items-center gap-6 text-xs font-medium text-white/60">
          <a href="#models" className="hover:text-white transition-colors">Models</a>
          <a href="#benchmarks" className="hover:text-white transition-colors">Benchmarks</a>
          <a href="#methodology" className="hover:text-white transition-colors">Methodology</a>
          <a href="#api" className="hover:text-white transition-colors">API Specs</a>
        </nav>

        {/* Right CTA */}
        <div className="flex items-center gap-3">
          <Link
            href="/chat"
            className="px-4 py-2 rounded-full bg-[#00C8FF] text-black text-xs font-semibold hover:bg-[#38BDF8] transition-all shadow-[0_0_15px_rgba(0,200,255,0.3)] flex items-center gap-1.5"
          >
            <span>Open Chat</span>
            <ArrowUpRight className="w-3.5 h-3.5" />
          </Link>
        </div>
      </header>

      {/* ── Page Navigation Drawer ─────────────────────────────── */}
      <PageNav open={menuOpen} onClose={() => setMenuOpen(false)} />

      {/* ── Main Content Container ─────────────────────────────── */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 py-12">
        {/* Section 1: Hero & Model Comparison */}
        <div id="models">
          <ModelComparisonHero />
        </div>

        {/* Section 2: Industry Benchmark Comparisons */}
        <BenchmarkGrid />

        {/* Section 3: Training Methodology & Architecture */}
        <div id="methodology" className="my-16">
          <TrainingMethodology />
        </div>

        {/* Section 4: Developer Integration & API Specification */}
        <div id="api" className="my-16 bg-[#121212] border border-white/10 rounded-3xl p-6 sm:p-10 shadow-2xl">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-8">
            <div>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#00C8FF]/10 text-[#00C8FF] border border-[#00C8FF]/30 text-xs font-mono mb-2">
                <Code2 className="w-3.5 h-3.5" />
                <span>Zero Labs Cloud & Edge API</span>
              </div>
              <h3 className="text-2xl sm:text-3xl font-bold text-white tracking-tight">
                Integrate Titan into Your Agentic Workflows
              </h3>
              <p className="text-sm text-white/60 mt-1 max-w-xl">
                Directly call Titan Pro Thinking and Titan Ultra Thinking via OpenAI-compatible endpoints or our native streaming SDK.
              </p>
            </div>

            <div className="flex items-center gap-3">
              <Link
                href="/chat"
                className="px-5 py-2.5 rounded-xl bg-white/10 hover:bg-white/15 text-white text-xs font-semibold border border-white/10 transition-all flex items-center gap-2"
              >
                <span>Launch Interactive Sandbox</span>
                <ExternalLink className="w-3.5 h-3.5" />
              </Link>
            </div>
          </div>

          {/* Code Box */}
          <div className="w-full bg-[#080808] border border-white/10 rounded-2xl overflow-hidden shadow-2xl">
            <div className="px-4 py-3 bg-white/5 border-b border-white/5 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Terminal className="w-4 h-4 text-[#00C8FF]" />
                <span className="text-xs font-mono text-white/70">titan-agent-stream.ts</span>
              </div>
              <button
                type="button"
                onClick={() => copyToClipboard(apiSnippet, false)}
                className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-white/5 hover:bg-white/10 text-white/70 hover:text-white text-[11px] font-mono transition-colors"
              >
                {copiedCode ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
                <span>{copiedCode ? 'Copied' : 'Copy Code'}</span>
              </button>
            </div>
            <pre className="p-4 sm:p-6 text-xs sm:text-sm font-mono text-[#00C8FF] overflow-x-auto whitespace-pre leading-relaxed bg-black/60">
              <code>{apiSnippet}</code>
            </pre>
          </div>
        </div>

        {/* Section 5: BibTeX Citation */}
        <div className="my-16 bg-[#121212] border border-white/10 rounded-3xl p-6 sm:p-10">
          <div className="flex items-center justify-between mb-4 flex-wrap gap-3">
            <div className="flex items-center gap-2">
              <BookOpen className="w-4 h-4 text-[#00C8FF]" />
              <h4 className="text-base font-bold text-white">Cite Technical Report</h4>
            </div>
            <button
              type="button"
              onClick={() => copyToClipboard(bibtex, true)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-white/70 hover:text-white text-xs font-mono transition-colors"
            >
              {copiedBibtex ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
              <span>{copiedBibtex ? 'Copied to Clipboard' : 'Copy BibTeX'}</span>
            </button>
          </div>
          <pre className="p-4 bg-black/60 border border-white/10 rounded-xl text-xs font-mono text-white/70 overflow-x-auto">
            <code>{bibtex}</code>
          </pre>
        </div>
      </main>

      {/* ── Footer ─────────────────────────────────────────────── */}
      <footer className="border-t border-white/10 bg-[#080808] py-12 px-6">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-3">
            <img src="/logo.png?v=2" alt="Zero AI" className="h-6 object-contain brightness-0 invert" />
            <span className="text-xs text-white/40">Zero Labs Deep Learning Research</span>
          </div>
          <div className="flex items-center gap-6 text-xs text-white/50">
            <Link href="/" className="hover:text-white transition-colors">Zero Ring</Link>
            <Link href="/chat" className="hover:text-white transition-colors">Zero AI Chat</Link>
            <Link href="/cowork" className="hover:text-white transition-colors">Cowork</Link>
            <Link href="/research" className="hover:text-white transition-colors text-[#00C8FF]">Research</Link>
          </div>
          <span className="text-xs font-mono text-white/30">© 2026 Zero Tech Inc.</span>
        </div>
      </footer>
    </div>
  );
}
