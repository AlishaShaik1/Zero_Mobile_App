'use client';
import { useState, useMemo } from 'react';
import { Artifact } from '@/types';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { ArtifactToolbar } from './ArtifactToolbar';
import { Eye, Code, Copy, Check } from 'lucide-react';

// ── Spreadsheet / Excel table preview ────────────────────────────────────────
function SpreadsheetPreview({ content }: { content: string }) {
    const { headers, rows } = useMemo(() => {
        const lines = content.trim().split('\n').filter(l => l.trim());
        const parseRow = (line: string): string[] => {
            const fields: string[] = [];
            let field = '';
            let inQuotes = false;
            for (let i = 0; i < line.length; i++) {
                const ch = line[i];
                if (ch === '"') {
                    if (inQuotes && line[i + 1] === '"') { field += '"'; i++; }
                    else { inQuotes = !inQuotes; }
                } else if (ch === ',' && !inQuotes) {
                    fields.push(field.trim()); field = '';
                } else { field += ch; }
            }
            fields.push(field.trim());
            return fields;
        };
        const [headerLine, ...dataLines] = lines;
        return {
            headers: parseRow(headerLine || ''),
            rows: dataLines.map(parseRow),
        };
    }, [content]);

    if (!headers.length) {
        return <div className="p-6 text-zinc-400 text-sm">No spreadsheet data found.</div>;
    }

    return (
        <div className="flex-1 overflow-auto p-4 bg-[#0D0E12]">
            {/* Row count badge */}
            <div className="mb-3 flex items-center gap-3">
                <span className="text-xs font-mono text-zinc-400">
                    {rows.length} rows &times; {headers.length} columns
                </span>
                <span className="text-[10px] px-2 py-0.5 rounded bg-emerald-900/40 text-emerald-300 font-semibold border border-emerald-700/40">XLSX</span>
            </div>
            <div className="overflow-x-auto rounded-lg border border-zinc-700 shadow-lg">
                <table className="min-w-full text-xs border-collapse">
                    <thead>
                        <tr>
                            {/* Row number header */}
                            <th className="sticky left-0 z-10 bg-zinc-800 border-r border-b border-zinc-700 px-2 py-2 text-zinc-500 font-mono text-[10px] min-w-[36px] text-center">#</th>
                            {headers.map((h, i) => (
                                <th
                                    key={i}
                                    className="bg-[#1A2340] border-r border-b border-zinc-700 px-3 py-2 text-left font-bold text-[#7DD3FC] whitespace-nowrap tracking-tight text-[11px]"
                                >
                                    {h || '—'}
                                </th>
                            ))}
                        </tr>
                    </thead>
                    <tbody>
                        {rows.map((row, ri) => (
                            <tr
                                key={ri}
                                className={ri % 2 === 0 ? 'bg-[#0D0E12]' : 'bg-[#111318]'}
                            >
                                {/* Row number */}
                                <td className="sticky left-0 border-r border-b border-zinc-800 px-2 py-1.5 text-zinc-600 font-mono text-[10px] text-center bg-inherit">
                                    {ri + 1}
                                </td>
                                {headers.map((_, ci) => (
                                    <td
                                        key={ci}
                                        className="border-r border-b border-zinc-800 px-3 py-1.5 text-zinc-200 whitespace-nowrap"
                                    >
                                        {row[ci] ?? ''}
                                    </td>
                                ))}
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

// ── PPTX slide preview ────────────────────────────────────────────────────────
function PptxPreview({ content }: { content: string }) {
    let slides: { title: string; content: string[]; bg?: string }[] = [];
    try {
        slides = JSON.parse(content);
    } catch {
        return <p className="text-zinc-400 p-4 text-sm font-mono">Invalid or incomplete slide data.</p>;
    }

    return (
        <div className="flex flex-col gap-4 p-4 overflow-y-auto">
            {slides.map((slide, i) => (
                <div
                    key={i}
                    className="rounded-xl overflow-hidden shadow-lg border border-zinc-700"
                    style={{ background: slide.bg ?? '#1a1a2e', minHeight: '180px' }}
                >
                    <div className="px-6 pt-5 pb-2">
                        <p className="text-[11px] text-zinc-500 mb-1 uppercase tracking-widest">Slide {i + 1}</p>
                        <h3 className="text-white text-xl font-bold leading-tight mb-3">{slide.title}</h3>
                        <ul className="space-y-1.5">
                            {(slide.content ?? []).map((line, j) => (
                                <li key={j} className="flex items-start gap-2 text-zinc-200 text-sm">
                                    <span className="mt-2 w-1.5 h-1.5 rounded-full bg-[#22C8FF] shrink-0" />
                                    {line}
                                </li>
                            ))}
                        </ul>
                    </div>
                </div>
            ))}
        </div>
    );
}

// ── Code block with copy & line numbers ─────────────────────────────────────────
function CodePreview({ content, language }: { content: string; language?: string }) {
    const [copied, setCopied] = useState(false);

    const handleCopy = () => {
        navigator.clipboard.writeText(content);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
    };

    return (
        <div className="overflow-auto h-full flex flex-col bg-[#0D0E12]">
            <div className="flex items-center justify-between px-4 py-2 bg-zinc-900 border-b border-zinc-800 text-xs text-zinc-400">
                <div className="flex items-center gap-2">
                    <span className="w-2.5 h-2.5 rounded-full bg-red-500/80" />
                    <span className="w-2.5 h-2.5 rounded-full bg-yellow-500/80" />
                    <span className="w-2.5 h-2.5 rounded-full bg-green-500/80" />
                    <span className="ml-2 font-mono text-zinc-300">{language || 'code'}</span>
                </div>
                <button
                    onClick={handleCopy}
                    className="flex items-center gap-1.5 text-xs text-zinc-400 hover:text-white px-2 py-1 rounded bg-zinc-800 hover:bg-zinc-700 transition-colors"
                >
                    {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copied ? 'Copied' : 'Copy Code'}</span>
                </button>
            </div>
            <pre className="p-5 text-xs font-mono text-zinc-100 leading-relaxed overflow-auto whitespace-pre">
                <code>{content}</code>
            </pre>
        </div>
    );
}

// ── Markdown rendered ─────────────────────────────────────────────────────────
function MarkdownPreview({ content }: { content: string }) {
    return (
        <div className="p-6 overflow-auto prose prose-invert prose-sm max-w-none
            prose-headings:text-white prose-p:text-zinc-200 prose-strong:text-white
            prose-a:text-[#22C8FF] prose-code:bg-zinc-700 prose-code:px-1.5 prose-code:rounded
            prose-pre:bg-zinc-800 prose-li:text-zinc-200 prose-blockquote:border-[#22C8FF]">
            <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
        </div>
    );
}

// ── PDF document preview (styled A4 page look) ────────────────────────────────
function PdfPreview({ content, title }: { content: string; title: string }) {
    return (
        <div className="flex-1 overflow-auto bg-zinc-700 p-6 flex justify-center items-start min-h-full">
            <div
                className="bg-white text-black shadow-2xl rounded-sm w-full"
                style={{ maxWidth: '210mm', padding: '18mm 20mm', fontFamily: 'Georgia, serif' }}
            >
                {/* PDF-style header bar */}
                <div className="border-b-2 border-[#1A1A4E] pb-3 mb-6">
                    <div className="text-[10px] font-mono text-zinc-400 uppercase tracking-widest mb-1">PDF Document · Titan Pro — Zero Labs</div>
                    <h1 className="text-2xl font-bold text-[#1A1A4E] leading-tight">{title}</h1>
                </div>
                {/* Render markdown as styled PDF-like content */}
                <div className="prose prose-sm max-w-none
                    prose-headings:text-[#1A1A4E] prose-headings:font-bold
                    prose-h1:text-xl prose-h1:border-b prose-h1:border-[#22C8FF]/40 prose-h1:pb-1
                    prose-h2:text-lg prose-h2:mt-6
                    prose-h3:text-base prose-h3:text-[#2A2A6E]
                    prose-p:text-[#222] prose-p:leading-relaxed
                    prose-strong:text-[#111]
                    prose-ul:text-[#222] prose-ol:text-[#222]
                    prose-li:marker:text-[#1A1A4E]
                    prose-code:bg-[#F0F0F8] prose-code:text-[#C7254E] prose-code:px-1 prose-code:rounded prose-code:text-[11px]
                    prose-pre:bg-[#1E1E28] prose-pre:text-[#B4E6B4] prose-pre:text-[10px] prose-pre:rounded-lg prose-pre:p-4
                    prose-blockquote:border-l-4 prose-blockquote:border-[#22C8FF] prose-blockquote:bg-blue-50 prose-blockquote:py-2 prose-blockquote:px-3 prose-blockquote:italic
                    prose-table:text-sm prose-th:bg-[#1A1A4E] prose-th:text-white prose-td:border prose-td:border-zinc-300
                ">
                    <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
                </div>
                {/* PDF footer */}
                <div className="border-t border-zinc-200 mt-10 pt-3 text-[9px] text-zinc-400 flex justify-between">
                    <span>{title}</span>
                    <span>Generated by Titan Pro · Zero Labs</span>
                </div>
            </div>
        </div>
    );
}

// ── HTML live preview in sandboxed iframe ──────────────────────────────────────
function HtmlPreview({ content }: { content: string }) {
    const srcDoc = useMemo(() => {
        let html = content.trim();
        // If snippet lacks basic HTML container, wrap it safely
        if (!html.includes('<html') && !html.includes('<!DOCTYPE')) {
            html = `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;font-family:system-ui,sans-serif;background:#000;color:#fff;overflow:hidden;}</style></head><body>${html}</body></html>`;
        }
        // Auto-close unclosed tags during streaming/incomplete output
        if (html.includes('<script') && !html.includes('</script>')) {
            html += '\n</script>';
        }
        if (html.includes('<body') && !html.includes('</body>')) {
            html += '\n</body></html>';
        } else if (!html.includes('</html>')) {
            html += '\n</html>';
        }
        return html;
    }, [content]);

    return (
        <div className="w-full h-full flex-1 flex flex-col bg-black relative">
            <iframe
                srcDoc={srcDoc}
                sandbox="allow-scripts allow-modals allow-same-origin allow-popups"
                className="w-full h-full flex-1 border-0 bg-black min-h-[500px]"
                title="Live Simulation & HTML Preview"
            />
        </div>
    );
}

// ── Main panel ────────────────────────────────────────────────────────────────
export function ArtifactPanel({ artifact }: { artifact: Artifact }) {
    const isHtml = artifact.type === 'html';
    const isPdf = artifact.type === 'pdf';
    const isSheet = artifact.type === 'xlsx' || artifact.type === 'csv';
    const [viewMode, setViewMode] = useState<'preview' | 'code'>((isHtml || isPdf || isSheet) ? 'preview' : 'code');

    const renderContent = () => {
        if (viewMode === 'code') {
            return <CodePreview content={artifact.content} language={artifact.language || artifact.type} />;
        }

        switch (artifact.type) {
            case 'html':
                return <HtmlPreview content={artifact.content} />;
            case 'markdown':
            case 'md':
            case 'docx':
                return <MarkdownPreview content={artifact.content} />;
            case 'pdf':
                return <PdfPreview content={artifact.content} title={artifact.title} />;
            case 'xlsx':
            case 'csv':
                return <SpreadsheetPreview content={artifact.content} />;
            case 'pptx':
                return <PptxPreview content={artifact.content} />;
            case 'code':
            default:
                return <CodePreview content={artifact.content} language={artifact.language} />;
        }
    };

    return (
        <div className="flex flex-col h-full overflow-hidden bg-[#0D0E12] text-white">
            {/* View Mode Switcher Header */}
            <div className="flex items-center justify-between px-4 py-2 bg-zinc-900 border-b border-zinc-800 text-xs">
                <div className="flex items-center gap-1.5 bg-zinc-800/80 p-1 rounded-lg border border-zinc-700/50">
                    <button
                        onClick={() => setViewMode('preview')}
                        className={`flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-all ${
                            viewMode === 'preview'
                                ? 'bg-[#22C8FF] text-black font-semibold shadow-sm'
                                : 'text-zinc-400 hover:text-white'
                        }`}
                    >
                        <Eye className="w-3.5 h-3.5" />
                        <span>Visual Preview</span>
                    </button>
                    <button
                        onClick={() => setViewMode('code')}
                        className={`flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-all ${
                            viewMode === 'code'
                                ? 'bg-[#22C8FF] text-black font-semibold shadow-sm'
                                : 'text-zinc-400 hover:text-white'
                        }`}
                    >
                        <Code className="w-3.5 h-3.5" />
                        <span>Source Code</span>
                    </button>
                </div>

                <ArtifactToolbar artifact={artifact} />
            </div>

            <div className="overflow-auto flex-1 flex flex-col">
                {renderContent()}
            </div>
        </div>
    );
}
