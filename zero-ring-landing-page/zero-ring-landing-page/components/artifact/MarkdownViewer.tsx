'use client';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeHighlight from 'rehype-highlight';
import rehypeRaw from 'rehype-raw';
import 'highlight.js/styles/github-dark.css';

export function MarkdownViewer({ content }: { content: string }) {
    return (
        <div className="prose prose-invert max-w-none p-4 text-sm leading-relaxed">
            <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                rehypePlugins={[rehypeHighlight, rehypeRaw]}
            >
                {content}
            </ReactMarkdown>
        </div>
    );
}
