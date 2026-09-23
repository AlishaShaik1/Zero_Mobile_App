'use client';

import React, { useState } from 'react';
import { BENCHMARKS } from './benchmarkData';
import { BenchmarkCard } from './BenchmarkCard';
import { BenchmarkTable } from './BenchmarkTable';
import { LayoutGrid, Table, Search, Sparkles, Filter } from 'lucide-react';

export function BenchmarkGrid() {
  const [viewMode, setViewMode] = useState<'grid' | 'table'>('grid');
  const [activeCategory, setActiveCategory] = useState<string>('All');
  const [searchQuery, setSearchQuery] = useState<string>('');

  const categories = ['All', 'Agentic', 'Coding', 'Reasoning', 'Tools & MCP', 'Multimodal'];

  const filteredBenchmarks = BENCHMARKS.filter((item) => {
    const matchesCategory = activeCategory === 'All' || item.category === activeCategory;
    const matchesSearch =
      item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.domain.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.summary.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  return (
    <section id="benchmarks" className="w-full max-w-7xl mx-auto my-16 px-4">
      {/* Title & Description */}
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-8">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/5 border border-white/10 text-white/70 text-xs font-mono mb-3">
            <Sparkles className="w-3.5 h-3.5 text-[#00C8FF]" />
            <span>Empirical Evaluation Suite</span>
          </div>
          <h2 className="text-2xl sm:text-4xl font-bold text-white tracking-tight">
            Industry Benchmark Comparison
          </h2>
          <p className="text-sm text-white/60 mt-1 max-w-xl">
            Titan Pro Thinking and Titan Ultra Thinking evaluated across 12 industry-standard agentic, reasoning, and multi-modal benchmarks against 2026 leading frontier systems.
          </p>
        </div>

        {/* View mode toggle */}
        <div className="flex items-center gap-2 bg-[#171717] border border-white/10 p-1 rounded-xl self-start md:self-auto">
          <button
            type="button"
            onClick={() => setViewMode('grid')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              viewMode === 'grid'
                ? 'bg-[#00C8FF] text-black shadow-md'
                : 'text-white/60 hover:text-white'
            }`}
          >
            <LayoutGrid className="w-3.5 h-3.5" />
            <span>Card Grid</span>
          </button>
          <button
            type="button"
            onClick={() => setViewMode('table')}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
              viewMode === 'table'
                ? 'bg-[#00C8FF] text-black shadow-md'
                : 'text-white/60 hover:text-white'
            }`}
          >
            <Table className="w-3.5 h-3.5" />
            <span>Data Table</span>
          </button>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 mb-8">
        {/* Category Tabs */}
        <div className="flex items-center gap-1.5 overflow-x-auto w-full sm:w-auto pb-2 sm:pb-0 scrollbar-none">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setActiveCategory(cat)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-medium whitespace-nowrap transition-all ${
                activeCategory === cat
                  ? 'bg-white text-black font-bold shadow-md'
                  : 'bg-white/5 text-white/60 hover:bg-white/10 hover:text-white'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Search Input */}
        <div className="relative w-full sm:w-64">
          <Search className="w-4 h-4 text-white/40 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search benchmarks..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-[#161616] border border-white/10 rounded-xl pl-9 pr-3 py-1.5 text-xs text-white placeholder:text-white/40 outline-none focus:border-[#00C8FF] transition-all"
          />
        </div>
      </div>

      {/* Main Content Area */}
      {viewMode === 'grid' ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredBenchmarks.map((b, idx) => (
            <BenchmarkCard key={b.id} benchmark={b} index={idx} />
          ))}
        </div>
      ) : (
        <BenchmarkTable />
      )}

      {/* Benchmark Summary Bar */}
      <div className="mt-12 p-6 bg-gradient-to-r from-purple-950/20 via-black to-[#00C8FF]/10 border border-white/10 rounded-2xl flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-white/5 border border-white/10 flex items-center justify-center text-[#00C8FF]">
            <Sparkles className="w-5 h-5" />
          </div>
          <div>
            <h4 className="text-sm font-bold text-white">Consistent Frontier Leadership</h4>
            <p className="text-xs text-white/60">
              Titan models maintain top rank across agentic coding, verified GitHub resolution, and complex mathematical deduction.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-6 font-mono text-center sm:text-right">
          <div>
            <span className="text-base font-bold text-[#00C8FF]">12 / 12</span>
            <span className="text-[10px] text-white/40 block">Verified Tests</span>
          </div>
          <div>
            <span className="text-base font-bold text-purple-300">100%</span>
            <span className="text-[10px] text-white/40 block">Reproducible</span>
          </div>
        </div>
      </div>
    </section>
  );
}
