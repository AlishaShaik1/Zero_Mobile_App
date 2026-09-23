'use client'

import { motion } from 'framer-motion'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import remarkMath from 'remark-math'
import rehypeKatex from 'rehype-katex'
import 'katex/dist/katex.min.css'
import { Message, Artifact } from '@/types'
import { ArtifactCard } from '../artifacts/ArtifactCard'
import { CodeBlock } from './CodeBlock'

interface MessageCardProps {
  message: Message
  isStreaming?: boolean
  onArtifactView: (artifact: Artifact) => void
}

/**
 * Normalizes math delimiters to ensure KaTeX handles both $...$, $$...$$, \(...\), and \[...\]
 */
function normalizeMathDelimiters(content: string): string {
  if (!content) return ''
  // Convert \[ ... \] to $$ ... $$
  let text = content.replace(/\\\[([\s\S]*?)\\\]/g, '$$$$1$$$')
  // Convert \( ... \) to $ ... $
  text = text.replace(/\\\(([\s\S]*?)\\\)/g, '$$$1$')
  return text
}

export function MessageCard({ message, isStreaming = false, onArtifactView }: MessageCardProps) {
  const isAssistant = message.role === 'assistant' || (message as any).role === 'ai'
  const processedText = isAssistant ? normalizeMathDelimiters(message.text) : message.text

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
      className={`flex w-full ${isAssistant ? 'justify-start' : 'justify-end'} mb-7`}
      style={{ fontFamily: 'var(--font-space-grotesk), sans-serif' }}
    >
      {isAssistant ? (
        <div className="flex flex-col w-full max-w-full">
          {/* Assistant Header Badge */}
          <div className="flex items-center gap-2 mb-2.5">
            {isStreaming ? (
              <div className="relative flex items-center justify-center w-5 h-5 shrink-0">
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ duration: 1.3, repeat: Infinity, ease: 'linear' }}
                  className={`w-5 h-5 rounded-full border-[2px] ${
                    (message.model || '').toLowerCase().includes('ultra')
                      ? 'border-[#9333EA]/20 border-t-[#9333EA] border-r-[#9333EA]'
                      : 'border-[#00C8FF]/20 border-t-[#00C8FF] border-r-[#00C8FF]'
                  }`}
                />
                <motion.div
                  animate={{ scale: [0.75, 1.2, 0.75], opacity: [0.4, 1, 0.4] }}
                  transition={{ duration: 1.3, repeat: Infinity, ease: 'easeInOut' }}
                  className={`absolute w-1.5 h-1.5 rounded-full ${
                    (message.model || '').toLowerCase().includes('ultra')
                      ? 'bg-[#9333EA] shadow-[0_0_8px_rgba(147,51,234,0.7)]'
                      : 'bg-[#00C8FF] shadow-[0_0_8px_rgba(0,200,255,0.7)]'
                  }`}
                />
              </div>
            ) : (
              <div className={`w-5 h-5 rounded-md flex items-center justify-center border ${
                (message.model || '').toLowerCase().includes('ultra')
                  ? 'bg-[#9333EA]/10 border-[#9333EA]/30'
                  : 'bg-[#00C8FF]/10 border-[#00C8FF]/30'
              }`}>
                <span className={`w-1.5 h-1.5 rounded-full ${
                  (message.model || '').toLowerCase().includes('ultra') ? 'bg-[#9333EA]' : 'bg-[#00C8FF]'
                }`} />
              </div>
            )}
            <span className={`text-xs font-bold uppercase tracking-wider ${
              (message.model || '').toLowerCase().includes('ultra') ? 'text-[#9333EA]' : 'text-[#111111]/70'
            }`}>
              {message.model || 'Titan Pro'}
            </span>
            {isStreaming && (
              <span className={`text-[10px] font-mono px-2 py-0.5 rounded font-semibold flex items-center gap-1 animate-pulse ${
                (message.model || '').toLowerCase().includes('ultra')
                  ? 'bg-purple-100 text-purple-700'
                  : 'bg-sky-100 text-sky-700'
              }`}>
                <span>Generating…</span>
              </span>
            )}
            {message.webSearchUsed && (
              <span className="text-[10px] font-bold text-[#00C8FF] bg-[#00C8FF]/10 px-2 py-0.5 rounded-full uppercase tracking-wider">
                Web Search
              </span>
            )}
          </div>

          {/* Full-width seamless response text, formulas, and code blocks */}
          <div className="w-full text-[#111111] leading-relaxed text-[15px] sm:text-[15.5px] tracking-tight">
            <div className="prose prose-base max-w-none text-[#111111] leading-relaxed">
              <ReactMarkdown
                remarkPlugins={[remarkGfm, remarkMath]}
                rehypePlugins={[rehypeKatex]}
                components={{
                  h1({ children }) {
                    return <h1 className="text-[19px] sm:text-[20px] font-bold text-[#111] mt-6 mb-3 tracking-tight border-b border-[#E5E4DF] pb-1.5">{children}</h1>;
                  },
                  h2({ children }) {
                    return <h2 className="text-[17px] sm:text-[18px] font-bold text-[#111] mt-5 mb-2.5 tracking-tight border-b border-[#E5E4DF]/60 pb-1">{children}</h2>;
                  },
                  h3({ children }) {
                    return <h3 className="text-[15.5px] sm:text-[16px] font-bold text-[#1A1A1A] mt-4 mb-2 tracking-tight flex items-center gap-1.5">{children}</h3>;
                  },
                  h4({ children }) {
                    return <h4 className="text-[14.5px] font-bold text-[#2A2A2A] mt-3 mb-1.5 tracking-tight">{children}</h4>;
                  },
                  p({ children }) {
                    return <p className="my-2.5 text-[#222] leading-relaxed">{children}</p>;
                  },
                  ul({ children }) {
                    return <ul className="pl-6 my-3 list-disc space-y-2 marker:text-[#111111]/80 text-[#222]">{children}</ul>;
                  },
                  ol({ children }) {
                    return <ol className="pl-6 my-3 list-decimal space-y-2.5 marker:text-[#111111] marker:font-bold text-[#222]">{children}</ol>;
                  },
                  li({ children }) {
                    return <li className="pl-1 text-[#222] leading-relaxed my-1">{children}</li>;
                  },
                  blockquote({ children }) {
                    return (
                      <blockquote className="my-4 border-l-4 border-[#00C8FF] bg-[#00C8FF]/[0.06] py-3 px-4 rounded-r-xl text-[#222222] text-[14px] leading-relaxed shadow-xs">
                        {children}
                      </blockquote>
                    );
                  },
                  table({ children }) {
                    return (
                      <div className="my-4 w-full overflow-x-auto rounded-xl border border-[#E5E4DF] bg-white shadow-xs">
                        <table className="w-full text-left border-collapse text-[13.5px] sm:text-[14px]">
                          {children}
                        </table>
                      </div>
                    );
                  },
                  thead({ children }) {
                    return (
                      <thead className="bg-[#F8F7F3] border-b border-[#E5E4DF] text-[#111111]">
                        {children}
                      </thead>
                    );
                  },
                  tbody({ children }) {
                    return <tbody className="divide-y divide-[#E5E4DF]/60">{children}</tbody>;
                  },
                  tr({ children }) {
                    return <tr className="hover:bg-[#FAFAFA] transition-colors">{children}</tr>;
                  },
                  th({ children }) {
                    return (
                      <th className="px-4 py-2.5 font-bold text-[#111111] text-[13px] tracking-tight whitespace-nowrap">
                        {children}
                      </th>
                    );
                  },
                  td({ children }) {
                    return (
                      <td className="px-4 py-2.5 text-[#222222] leading-relaxed align-middle">
                        {children}
                      </td>
                    );
                  },
                  hr() {
                    return <hr className="my-5 border-[#E5E4DF]" />;
                  },
                  strong({ children }) {
                    return <strong className="font-bold text-[#000] tracking-tight">{children}</strong>;
                  },
                  code({ node, inline, className, children, ...props }: any) {
                    const match = /language-(\w+)/.exec(className || '');
                    const codeString = String(children).replace(/\n$/, '');

                    if (!inline && (match || codeString.includes('\n'))) {
                      return (
                        <CodeBlock
                          language={match ? match[1] : ''}
                          code={codeString}
                        />
                      );
                    }

                    return (
                      <code
                        className="bg-[#EFECE6] text-[#C93B3B] px-1.5 py-0.5 rounded-md font-mono text-[13px] font-semibold tracking-tight"
                        {...props}
                      >
                        {children}
                      </code>
                    );
                  },
                  pre({ children }) {
                    return <div className="not-prose w-full max-w-full my-3">{children}</div>;
                  },
                }}
              >
                {processedText}
              </ReactMarkdown>
            </div>

            {/* Artifact cards (if visual HTML/deck app is generated) */}
            {message.artifacts && message.artifacts.length > 0 && (
              <div className="mt-4 flex flex-col gap-3 border-t border-[#E5E4DF] pt-4">
                {message.artifacts.map(a => (
                  <ArtifactCard key={a.id} artifact={a} onView={onArtifactView} />
                ))}
              </div>
            )}
          </div>
        </div>
      ) : (
        <motion.div
          className="bg-[#111111] rounded-2xl px-5 py-3.5 sm:px-6 sm:py-4 text-white max-w-[90%] md:max-w-[75%] leading-relaxed text-[15px] sm:text-[15.5px] tracking-tight shadow-[0_4px_16px_rgba(0,0,0,0.12)] whitespace-pre-wrap break-words ml-auto"
        >
          {message.text}
        </motion.div>
      )}
    </motion.div>
  )
}
