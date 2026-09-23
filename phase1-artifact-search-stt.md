# PHASE 1 — Artifact System · Web Search · STT
### Ornith 9B · Next.js App Builder

> **Read this top-to-bottom, do every micro-step in order.**
> Every file path is relative to your Next.js root unless stated otherwise.
> Never skip the install steps — wrong package versions = silent failures.

---

## 0 · PRE-FLIGHT

### 0.1 – Confirm stack
```
Node.js ≥ 18.17
Next.js 14+ (App Router)  ← these instructions assume App Router
Ornith 9B API endpoint returning SSE text/event-stream
Serper API key  (serper.dev → free 2500 queries)
```

### 0.2 – Install all Phase 1 deps in one shot
```bash
npm install \
  @huggingface/transformers \
  react-markdown remark-gfm rehype-highlight rehype-raw \
  highlight.js \
  docx file-saver \
  @types/file-saver
```

---

## 1 · PROJECT STRUCTURE

Create every folder/file listed below. Empty for now — you'll fill them:

```
/app
  /api
    /chat/route.ts          ← Ornith SSE proxy + tool dispatch
    /search/route.ts        ← Serper proxy (keeps API key server-side)
  /components
    /artifact
      ArtifactPanel.tsx     ← renders md / html / code artifacts
      MarkdownViewer.tsx
      HtmlViewer.tsx
      ArtifactToolbar.tsx   ← copy / download buttons
    /chat
      ChatInterface.tsx     ← main chat + artifact split-view
      MessageBubble.tsx
    /stt
      STTButton.tsx
  /hooks
    useChat.ts
    useSTT.ts
  /lib
    /ornith
      client.ts             ← fetch wrapper for your API
      tools.ts              ← tool definitions (search)
      streamParser.ts       ← SSE chunk → text
      artifactParser.ts     ← detect <artifact> in stream
    /search
      serper.ts
  /workers
    stt.worker.ts           ← runs transformers.js off main thread
  /types
    index.ts
```

---

## 2 · SHARED TYPES

### File: `/types/index.ts`
```typescript
export type ArtifactType = 'markdown' | 'html' | 'code';

export interface Artifact {
  id: string;
  type: ArtifactType;
  title: string;
  language?: string;   // for code artifacts
  content: string;
}

export interface Message {
  id: string;
  role: 'user' | 'assistant';
  text: string;          // rendered text (no artifact tags)
  thinking?: string;     // Phase 2
  artifacts: Artifact[];
  timestamp: number;
}

export interface Tool {
  name: string;
  description: string;
  parameters: Record<string, unknown>;
}
```

---

## 3 · SYSTEM PROMPT — ARTIFACT FORMAT INSTRUCTIONS

The model must know *how* to emit artifacts.
This goes into every chat request as `role: "system"`.

### File: `/lib/ornith/systemPrompt.ts`
```typescript
export const SYSTEM_PROMPT = `
You are Ornith, a powerful AI assistant.

## Creating Artifacts

When your response includes:
- A complete HTML page or interactive demo
- A Markdown document (report, readme, structured writing)
- A code file the user will save or run

Wrap it in an artifact tag INSTEAD of a code block:

<artifact type="html" title="Short descriptive title">
<!DOCTYPE html>
<html>...full content...</html>
</artifact>

<artifact type="markdown" title="Short descriptive title">
# Content here...
</artifact>

<artifact type="code" language="python" title="Short descriptive title">
# code here
</artifact>

Rules for artifacts:
- Only one artifact per message unless user explicitly asks for multiple
- Short inline code snippets (< 20 lines, just showing a concept) do NOT need artifact tags — use normal code blocks
- Always write the full, complete, working content inside the artifact
- Your explanation text goes OUTSIDE the artifact tags, before or after

## Web Search Tool

When you need current information, you may call the search tool:
<tool_call>{"name":"web_search","arguments":{"query":"your search query"}}</tool_call>

Wait for the tool result before continuing your response.

## Identity
You are Ornith. Never reveal technical details about your architecture or training.
`.trim();
```

---

## 4 · ARTIFACT PARSER

This is the most important piece — it separates artifact XML from regular text in the streamed output.

### File: `/lib/ornith/artifactParser.ts`
```typescript
import { Artifact } from '@/types';

interface ParseResult {
  text: string;           // clean text without artifact tags
  artifacts: Artifact[];  // extracted artifacts
  isComplete: boolean;    // true when no open tags remain
}

// Call this on the FULL accumulated response string as it streams
export function parseArtifacts(raw: string): ParseResult {
  const artifacts: Artifact[] = [];
  let text = raw;

  // Regex: <artifact type="X" title="Y" [language="Z"]>...content...</artifact>
  const artifactRegex = /<artifact\s+type="([^"]+)"(?:\s+language="([^"]+)")?(?:\s+title="([^"]+)")?[^>]*>([\s\S]*?)<\/artifact>/gi;

  let match: RegExpExecArray | null;
  const seen = new Set<string>();

  while ((match = artifactRegex.exec(raw)) !== null) {
    const [fullMatch, type, language, title, content] = match;
    const id = `artifact-${artifacts.length}`;

    if (!seen.has(fullMatch)) {
      seen.add(fullMatch);
      artifacts.push({
        id,
        type: (type as Artifact['type']) || 'code',
        title: title || `Artifact ${artifacts.length + 1}`,
        language,
        content: content.trim(),
      });
      // Remove artifact from display text
      text = text.replace(fullMatch, `[${title || 'Artifact'}]`);
    }
  }

  // Check if there's an unclosed artifact tag (still streaming)
  const isComplete = !/<artifact\b(?!.*<\/artifact>)/.test(raw);

  return { text: text.trim(), artifacts, isComplete };
}

// Tool call detector: returns query string or null
export function detectToolCall(text: string): string | null {
  const match = text.match(/<tool_call>\s*\{"name"\s*:\s*"web_search"\s*,\s*"arguments"\s*:\s*\{"query"\s*:\s*"([^"]+)"\s*\}\s*\}\s*<\/tool_call>/);
  return match ? match[1] : null;
}
```

---

## 5 · SERPER WEB SEARCH

### 5.1 – Server-side Serper helper
### File: `/lib/search/serper.ts`
```typescript
const SERPER_API_KEY = process.env.SERPER_API_KEY!;

export interface SearchResult {
  title: string;
  snippet: string;
  link: string;
}

export async function serperSearch(query: string, numResults = 5): Promise<SearchResult[]> {
  const res = await fetch('https://google.serper.dev/search', {
    method: 'POST',
    headers: {
      'X-API-KEY': SERPER_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ q: query, num: numResults }),
  });

  if (!res.ok) throw new Error(`Serper error: ${res.status}`);

  const data = await res.json();

  return (data.organic ?? []).slice(0, numResults).map((r: any) => ({
    title: r.title ?? '',
    snippet: r.snippet ?? '',
    link: r.link ?? '',
  }));
}

export function formatSearchResults(results: SearchResult[]): string {
  return results
    .map((r, i) => `[${i + 1}] ${r.title}\n${r.snippet}\nSource: ${r.link}`)
    .join('\n\n');
}
```

### 5.2 – API Route for search proxy
### File: `/app/api/search/route.ts`
```typescript
import { NextRequest, NextResponse } from 'next/server';
import { serperSearch, formatSearchResults } from '@/lib/search/serper';

export async function POST(req: NextRequest) {
  try {
    const { query } = await req.json();
    if (!query) return NextResponse.json({ error: 'No query' }, { status: 400 });

    const results = await serperSearch(query);
    const formatted = formatSearchResults(results);

    return NextResponse.json({ results, formatted });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
```

---

## 6 · ORNITH 9B CHAT API ROUTE

This is the main server route — it calls your Ornith endpoint, handles SSE streaming, and detects tool calls mid-stream.

### File: `/app/api/chat/route.ts`
```typescript
import { NextRequest } from 'next/server';
import { SYSTEM_PROMPT } from '@/lib/ornith/systemPrompt';
import { detectToolCall } from '@/lib/ornith/artifactParser';
import { serperSearch, formatSearchResults } from '@/lib/search/serper';

const ORNITH_API_URL = process.env.ORNITH_API_URL!; // e.g. https://your-kaggle-endpoint.com/v1/chat/completions

export const runtime = 'edge'; // optional, remove if you need Node APIs

export async function POST(req: NextRequest) {
  const { messages } = await req.json() as { messages: { role: string; content: string }[] };

  const fullMessages = [
    { role: 'system', content: SYSTEM_PROMPT },
    ...messages,
  ];

  // ---- First pass: call Ornith ----
  const ornithRes = await fetch(ORNITH_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.ORNITH_API_KEY ?? 'none'}`,
    },
    body: JSON.stringify({
      messages: fullMessages,
      stream: true,
      max_tokens: 4096,
      temperature: 0.7,
    }),
  });

  if (!ornithRes.ok) {
    return new Response(`Ornith API error: ${ornithRes.status}`, { status: 502 });
  }

  // ---- Stream transformer: detect tool calls ----
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();
  let accumulated = '';
  let toolHandled = false;

  const stream = new ReadableStream({
    async start(controller) {
      const reader = ornithRes.body!.getReader();

      const processChunk = async (chunk: string) => {
        // Parse SSE lines
        const lines = chunk.split('\n');
        for (const line of lines) {
          if (!line.startsWith('data:')) continue;
          const data = line.slice(5).trim();
          if (data === '[DONE]') continue;

          try {
            const parsed = JSON.parse(data);
            // Support both OpenAI-compatible and raw streaming formats
            const token =
              parsed.choices?.[0]?.delta?.content ??
              parsed.token ??
              parsed.text ??
              '';

            if (token) {
              accumulated += token;

              // Check if we hit a tool call (only once)
              if (!toolHandled) {
                const query = detectToolCall(accumulated);
                if (query) {
                  toolHandled = true;
                  // Send tool-call marker to client
                  controller.enqueue(encoder.encode(`data: ${JSON.stringify({ type: 'tool_start', query })}\n\n`));

                  // Perform search
                  const results = await serperSearch(query);
                  const formatted = formatSearchResults(results);

                  controller.enqueue(encoder.encode(`data: ${JSON.stringify({ type: 'tool_result', formatted })}\n\n`));

                  // Continue with search results injected
                  const injectedMessages = [
                    ...fullMessages,
                    { role: 'assistant', content: accumulated },
                    { role: 'tool', content: `Search results for "${query}":\n\n${formatted}` },
                  ];

                  // Second Ornith call with context
                  const secondRes = await fetch(ORNITH_API_URL, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${process.env.ORNITH_API_KEY ?? 'none'}` },
                    body: JSON.stringify({ messages: injectedMessages, stream: true, max_tokens: 4096, temperature: 0.7 }),
                  });

                  const reader2 = secondRes.body!.getReader();
                  while (true) {
                    const { done, value } = await reader2.read();
                    if (done) break;
                    const chunk2 = decoder.decode(value, { stream: true });
                    // Re-parse and forward each token
                    for (const l of chunk2.split('\n')) {
                      if (!l.startsWith('data:')) continue;
                      const d = l.slice(5).trim();
                      if (d === '[DONE]') continue;
                      try {
                        const p = JSON.parse(d);
                        const t = p.choices?.[0]?.delta?.content ?? p.token ?? p.text ?? '';
                        if (t) controller.enqueue(encoder.encode(`data: ${JSON.stringify({ type: 'token', token: t })}\n\n`));
                      } catch {}
                    }
                  }
                  controller.enqueue(encoder.encode(`data: [DONE]\n\n`));
                  controller.close();
                  return; // done
                }
              }

              if (!toolHandled) {
                controller.enqueue(encoder.encode(`data: ${JSON.stringify({ type: 'token', token })}\n\n`));
              }
            }
          } catch {}
        }
      };

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        await processChunk(decoder.decode(value, { stream: true }));
      }

      if (!toolHandled) {
        controller.enqueue(encoder.encode(`data: [DONE]\n\n`));
        controller.close();
      }
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}
```

---

## 7 · REACT HOOK — useChat

### File: `/hooks/useChat.ts`
```typescript
'use client';
import { useState, useCallback, useRef } from 'react';
import { Message, Artifact } from '@/types';
import { parseArtifacts } from '@/lib/ornith/artifactParser';

export function useChat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isStreaming, setIsStreaming] = useState(false);
  const [searchStatus, setSearchStatus] = useState<string | null>(null);

  const send = useCallback(async (userText: string) => {
    const userMsg: Message = {
      id: crypto.randomUUID(),
      role: 'user',
      text: userText,
      artifacts: [],
      timestamp: Date.now(),
    };

    setMessages(prev => [...prev, userMsg]);
    setIsStreaming(true);
    setSearchStatus(null);

    const assistantId = crypto.randomUUID();
    let accumulated = '';

    // Add placeholder
    setMessages(prev => [...prev, {
      id: assistantId,
      role: 'assistant',
      text: '',
      artifacts: [],
      timestamp: Date.now(),
    }]);

    try {
      const history = [...messages, userMsg].map(m => ({
        role: m.role,
        content: m.text,
      }));

      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: history }),
      });

      const reader = res.body!.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value, { stream: true });
        for (const line of chunk.split('\n')) {
          if (!line.startsWith('data:')) continue;
          const raw = line.slice(5).trim();
          if (raw === '[DONE]') break;

          try {
            const event = JSON.parse(raw);

            if (event.type === 'tool_start') {
              setSearchStatus(`Searching: "${event.query}"…`);
            }
            if (event.type === 'tool_result') {
              setSearchStatus('Search done, generating…');
            }
            if (event.type === 'token') {
              accumulated += event.token;
              const { text, artifacts } = parseArtifacts(accumulated);

              setMessages(prev => prev.map(m =>
                m.id === assistantId
                  ? { ...m, text, artifacts }
                  : m
              ));
            }
          } catch {}
        }
      }
    } finally {
      setIsStreaming(false);
      setSearchStatus(null);
    }
  }, [messages]);

  return { messages, send, isStreaming, searchStatus };
}
```

---

## 8 · ARTIFACT COMPONENTS

### 8.1 – MarkdownViewer
### File: `/components/artifact/MarkdownViewer.tsx`
```tsx
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
```

### 8.2 – HtmlViewer (sandboxed iframe)
### File: `/components/artifact/HtmlViewer.tsx`
```tsx
'use client';
import { useEffect, useRef } from 'react';

export function HtmlViewer({ content }: { content: string }) {
  const iframeRef = useRef<HTMLIFrameElement>(null);

  useEffect(() => {
    if (!iframeRef.current) return;
    // Use srcdoc — no allow-same-origin so iframe can't reach parent DOM
    iframeRef.current.srcdoc = content;
  }, [content]);

  return (
    <iframe
      ref={iframeRef}
      sandbox="allow-scripts allow-forms allow-modals"
      className="w-full border-0"
      style={{ height: '500px', minHeight: '300px', resize: 'vertical', overflow: 'auto' }}
      title="HTML Preview"
    />
  );
}
```

### 8.3 – ArtifactToolbar (download buttons)
### File: `/components/artifact/ArtifactToolbar.tsx`
```tsx
'use client';
import { Artifact } from '@/types';
import { saveAs } from 'file-saver';
import { Document, Paragraph, TextRun, Packer } from 'docx';

interface Props {
  artifact: Artifact;
}

export function ArtifactToolbar({ artifact }: Props) {
  const copyToClipboard = () => {
    navigator.clipboard.writeText(artifact.content);
  };

  const downloadMd = () => {
    const blob = new Blob([artifact.content], { type: 'text/markdown;charset=utf-8' });
    saveAs(blob, `${artifact.title.replace(/\s+/g, '-').toLowerCase()}.md`);
  };

  const downloadDocx = async () => {
    // Split content into paragraphs
    const paragraphs = artifact.content.split('\n').map(line =>
      new Paragraph({
        children: [new TextRun({ text: line, size: 24 })],
        spacing: { after: 160 },
      })
    );

    const doc = new Document({
      sections: [{ properties: {}, children: paragraphs }],
    });

    const buffer = await Packer.toBuffer(doc);
    const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' });
    saveAs(blob, `${artifact.title.replace(/\s+/g, '-').toLowerCase()}.docx`);
  };

  const downloadHtml = () => {
    const blob = new Blob([artifact.content], { type: 'text/html;charset=utf-8' });
    saveAs(blob, `${artifact.title.replace(/\s+/g, '-').toLowerCase()}.html`);
  };

  return (
    <div className="flex items-center gap-2 px-3 py-2 bg-zinc-800 border-b border-zinc-700 text-xs text-zinc-300">
      <span className="font-medium text-white truncate flex-1">{artifact.title}</span>
      <span className="text-zinc-500 capitalize">{artifact.type}</span>
      <button onClick={copyToClipboard} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">Copy</button>
      {artifact.type === 'markdown' && (
        <>
          <button onClick={downloadMd} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.md</button>
          <button onClick={downloadDocx} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.docx</button>
        </>
      )}
      {artifact.type === 'html' && (
        <button onClick={downloadHtml} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.html</button>
      )}
    </div>
  );
}
```

### 8.4 – ArtifactPanel (wires it all together)
### File: `/components/artifact/ArtifactPanel.tsx`
```tsx
'use client';
import { Artifact } from '@/types';
import { MarkdownViewer } from './MarkdownViewer';
import { HtmlViewer } from './HtmlViewer';
import { ArtifactToolbar } from './ArtifactToolbar';

export function ArtifactPanel({ artifact }: { artifact: Artifact }) {
  return (
    <div className="flex flex-col border border-zinc-700 rounded-xl overflow-hidden bg-zinc-900">
      <ArtifactToolbar artifact={artifact} />

      <div className="overflow-auto flex-1">
        {artifact.type === 'markdown' && <MarkdownViewer content={artifact.content} />}
        {artifact.type === 'html' && <HtmlViewer content={artifact.content} />}
        {artifact.type === 'code' && (
          <pre className="p-4 text-sm text-zinc-100 overflow-auto">
            <code>{artifact.content}</code>
          </pre>
        )}
      </div>
    </div>
  );
}
```

---

## 9 · STT — SPEECH TO TEXT

### WHY THIS APPROACH
- `@huggingface/transformers` v3 → runs whisper-tiny (onnx-community variant)
- Downloads ~39 MB (fp32 encoder + q4 decoder hybrid — best size/quality tradeoff)
- Cached in browser `CacheStorage` automatically — zero re-download on revisit
- Worker thread → UI never freezes during model load or inference
- WebGPU if available (5–10× faster), WASM fallback (automatic, no config)

### KNOWN CAVEAT (transformers.js v3.8.x)
SuppressTokensLogitsProcessor is commented out in this version — for silence or very short recordings Whisper can hallucinate repeated text. **Fix:** only transcribe when recording duration > 500ms and audio RMS > threshold (code below handles this).

---

### 9.1 – STT Worker
### File: `/workers/stt.worker.ts`

> **Next.js note:** place this in the `public/` folder if you hit module-resolution issues with workers.
> If you use `new Worker(new URL(...))` syntax, it stays in `/workers/`.

```typescript
// /workers/stt.worker.ts
import {
  pipeline,
  AutomaticSpeechRecognitionPipeline,
  env,
} from '@huggingface/transformers';

// Allow model files to load from HF CDN + cache in browser
env.allowLocalModels = false;
env.useBrowserCache = true;

let transcriber: AutomaticSpeechRecognitionPipeline | null = null;

self.addEventListener('message', async (event: MessageEvent) => {
  const { type } = event.data;

  // ---- INIT: download + cache model ----
  if (type === 'init') {
    try {
      self.postMessage({ type: 'status', status: 'loading' });

      const device = typeof navigator !== 'undefined' && 'gpu' in navigator
        ? 'webgpu'
        : 'wasm';

      transcriber = await pipeline(
        'automatic-speech-recognition',
        'onnx-community/whisper-tiny',    // ~39MB hybrid quant
        {
          device,
          dtype: {
            encoder_model: 'fp32',         // better quality encoder
            decoder_model_merged: 'q4',    // small decoder
          },
          progress_callback: (info: any) => {
            if (info.status === 'progress') {
              self.postMessage({
                type: 'progress',
                file: info.file,
                loaded: info.loaded,
                total: info.total,
              });
            }
          },
        }
      );

      self.postMessage({ type: 'status', status: 'ready', device });
    } catch (err: any) {
      self.postMessage({ type: 'error', message: err.message });
    }
  }

  // ---- TRANSCRIBE ----
  if (type === 'transcribe') {
    if (!transcriber) {
      self.postMessage({ type: 'error', message: 'Model not loaded' });
      return;
    }

    try {
      self.postMessage({ type: 'status', status: 'transcribing' });

      const { audio } = event.data as { audio: Float32Array };

      // Silence guard: skip if audio is near-silent
      const rms = Math.sqrt(audio.reduce((s, x) => s + x * x, 0) / audio.length);
      if (rms < 0.005) {
        self.postMessage({ type: 'result', text: '' });
        return;
      }

      const result = await transcriber(audio, {
        language: 'english',
        task: 'transcribe',
        chunk_length_s: 30,
        return_timestamps: false,
      }) as { text: string };

      self.postMessage({ type: 'result', text: result.text.trim() });
    } catch (err: any) {
      self.postMessage({ type: 'error', message: err.message });
    }
  }
});
```

---

### 9.2 – STT Hook
### File: `/hooks/useSTT.ts`
```typescript
'use client';
import { useRef, useState, useCallback, useEffect } from 'react';

export type STTStatus =
  | 'idle'         // not initialized
  | 'loading'      // downloading model
  | 'ready'        // model ready, not recording
  | 'recording'    // mic active
  | 'transcribing' // processing audio
  | 'error';

interface STTHookReturn {
  status: STTStatus;
  transcript: string;
  progress: number;       // 0–100 download progress
  device: string;         // 'webgpu' or 'wasm'
  startRecording: () => Promise<void>;
  stopRecording: () => void;
  clearTranscript: () => void;
}

export function useSTT(onTranscript?: (text: string) => void): STTHookReturn {
  const workerRef = useRef<Worker | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const startTimeRef = useRef<number>(0);

  const [status, setStatus] = useState<STTStatus>('idle');
  const [transcript, setTranscript] = useState('');
  const [progress, setProgress] = useState(0);
  const [device, setDevice] = useState('wasm');

  // Initialize worker on mount
  useEffect(() => {
    const worker = new Worker(
      new URL('../workers/stt.worker.ts', import.meta.url),
      { type: 'module' }
    );

    worker.onmessage = (e: MessageEvent) => {
      const { type } = e.data;

      if (type === 'status') {
        setStatus(e.data.status as STTStatus);
        if (e.data.device) setDevice(e.data.device);
      }
      if (type === 'progress') {
        const pct = e.data.total > 0 ? Math.round((e.data.loaded / e.data.total) * 100) : 0;
        setProgress(pct);
      }
      if (type === 'result') {
        const text = e.data.text as string;
        setTranscript(text);
        setStatus('ready');
        if (text && onTranscript) onTranscript(text);
      }
      if (type === 'error') {
        console.error('STT worker error:', e.data.message);
        setStatus('error');
      }
    };

    workerRef.current = worker;

    // Start loading model immediately (caches in browser after first load)
    worker.postMessage({ type: 'init' });

    return () => worker.terminate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const startRecording = useCallback(async () => {
    if (status === 'loading') return; // wait for model

    const stream = await navigator.mediaDevices.getUserMedia({
      audio: { sampleRate: 16000, channelCount: 1, echoCancellation: true },
    });

    chunksRef.current = [];
    startTimeRef.current = Date.now();

    const recorder = new MediaRecorder(stream, { mimeType: 'audio/webm;codecs=opus' });

    recorder.ondataavailable = (e) => {
      if (e.data.size > 0) chunksRef.current.push(e.data);
    };

    recorder.onstop = async () => {
      stream.getTracks().forEach(t => t.stop());

      const duration = Date.now() - startTimeRef.current;
      if (duration < 400) {
        // Too short — probably accidental tap
        setStatus('ready');
        return;
      }

      const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
      const arrayBuffer = await blob.arrayBuffer();

      // Decode to 16 kHz mono Float32Array
      const audioCtx = new AudioContext({ sampleRate: 16000 });
      const decoded = await audioCtx.decodeAudioData(arrayBuffer);
      const float32 = decoded.getChannelData(0); // mono channel

      // Transfer buffer to worker (zero-copy)
      workerRef.current?.postMessage(
        { type: 'transcribe', audio: float32 },
        [float32.buffer]
      );
    };

    mediaRecorderRef.current = recorder;
    recorder.start(250); // collect chunks every 250ms
    setStatus('recording');
  }, [status]);

  const stopRecording = useCallback(() => {
    mediaRecorderRef.current?.stop();
  }, []);

  const clearTranscript = useCallback(() => setTranscript(''), []);

  return { status, transcript, progress, device, startRecording, stopRecording, clearTranscript };
}
```

---

### 9.3 – STT Button Component
### File: `/components/stt/STTButton.tsx`
```tsx
'use client';
import { useSTT } from '@/hooks/useSTT';

interface Props {
  onTranscript: (text: string) => void;
}

export function STTButton({ onTranscript }: Props) {
  const { status, progress, device, startRecording, stopRecording } = useSTT(onTranscript);

  const isRecording = status === 'recording';
  const isLoading = status === 'loading';
  const isProcessing = status === 'transcribing';

  const handleClick = () => {
    if (isRecording) stopRecording();
    else startRecording();
  };

  const label = {
    idle: '🎤',
    loading: `${progress}%`,
    ready: '🎤',
    recording: '⏹',
    transcribing: '⏳',
    error: '⚠️',
  }[status];

  return (
    <div className="flex items-center gap-1">
      <button
        onClick={handleClick}
        disabled={isLoading || isProcessing}
        title={device === 'webgpu' ? 'STT (WebGPU)' : 'STT (WASM)'}
        className={`
          w-9 h-9 rounded-lg flex items-center justify-center text-base transition-all
          ${isRecording ? 'bg-red-600 animate-pulse' : 'bg-zinc-700 hover:bg-zinc-600'}
          ${(isLoading || isProcessing) ? 'opacity-50 cursor-wait' : 'cursor-pointer'}
        `}
      >
        {label}
      </button>
      {isLoading && (
        <span className="text-xs text-zinc-400">Downloading model…</span>
      )}
    </div>
  );
}
```

---

### 9.4 – Next.js config for Worker
### File: `next.config.js` (add this)
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Needed to bundle workers correctly
  webpack(config) {
    config.resolve.extensionAlias = {
      '.js': ['.ts', '.tsx', '.js', '.jsx'],
    };
    return config;
  },
};

module.exports = nextConfig;
```

---

## 10 · CHAT INTERFACE — FULL LAYOUT

### File: `/components/chat/ChatInterface.tsx`
```tsx
'use client';
import { useState, useRef, useEffect } from 'react';
import { useChat } from '@/hooks/useChat';
import { ArtifactPanel } from '@/components/artifact/ArtifactPanel';
import { STTButton } from '@/components/stt/STTButton';
import { Artifact } from '@/types';

export function ChatInterface() {
  const { messages, send, isStreaming, searchStatus } = useChat();
  const [input, setInput] = useState('');
  const [selectedArtifact, setSelectedArtifact] = useState<Artifact | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Auto-select latest artifact when it appears
  useEffect(() => {
    const lastMsg = messages[messages.length - 1];
    if (lastMsg?.artifacts.length > 0) {
      setSelectedArtifact(lastMsg.artifacts[lastMsg.artifacts.length - 1]);
    }
  }, [messages]);

  const handleSubmit = async (e?: React.FormEvent) => {
    e?.preventDefault();
    if (!input.trim() || isStreaming) return;
    const text = input.trim();
    setInput('');
    await send(text);
  };

  const handleTranscript = (text: string) => {
    setInput(prev => (prev ? `${prev} ${text}` : text));
  };

  const hasArtifact = selectedArtifact !== null;

  return (
    <div className="flex h-screen bg-zinc-950 text-zinc-100">
      {/* Chat pane */}
      <div className={`flex flex-col ${hasArtifact ? 'w-1/2' : 'w-full max-w-2xl mx-auto'} border-r border-zinc-800`}>
        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length === 0 && (
            <div className="text-center text-zinc-500 mt-20">
              <p className="text-2xl font-light">Ornith</p>
              <p className="text-sm mt-1">Ask anything, create anything</p>
            </div>
          )}
          {messages.map(msg => (
            <div key={msg.id} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
              <div className={`max-w-[80%] px-4 py-2 rounded-2xl text-sm leading-relaxed
                ${msg.role === 'user'
                  ? 'bg-blue-600 text-white'
                  : 'bg-zinc-800 text-zinc-100'
                }`}
              >
                <p className="whitespace-pre-wrap">{msg.text}</p>
                {/* Artifact chips */}
                {msg.artifacts.map(a => (
                  <button
                    key={a.id}
                    onClick={() => setSelectedArtifact(a)}
                    className="mt-2 block w-full text-left text-xs px-3 py-2 bg-zinc-700 hover:bg-zinc-600 rounded-lg border border-zinc-600"
                  >
                    📄 {a.title} · {a.type}
                  </button>
                ))}
              </div>
            </div>
          ))}

          {searchStatus && (
            <div className="text-xs text-zinc-400 text-center">{searchStatus}</div>
          )}

          {isStreaming && !searchStatus && (
            <div className="flex justify-start">
              <div className="bg-zinc-800 px-4 py-2 rounded-2xl">
                <span className="animate-pulse">●</span>
              </div>
            </div>
          )}

          <div ref={bottomRef} />
        </div>

        {/* Input bar */}
        <form onSubmit={handleSubmit} className="p-3 border-t border-zinc-800 flex items-end gap-2">
          <textarea
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={e => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                handleSubmit();
              }
            }}
            placeholder="Message Ornith…"
            rows={1}
            className="flex-1 bg-zinc-800 text-zinc-100 placeholder-zinc-500 rounded-xl px-4 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-blue-500"
            style={{ maxHeight: '120px', overflowY: 'auto' }}
          />
          <STTButton onTranscript={handleTranscript} />
          <button
            type="submit"
            disabled={!input.trim() || isStreaming}
            className="w-9 h-9 bg-blue-600 hover:bg-blue-500 disabled:opacity-40 rounded-lg flex items-center justify-center text-white text-base"
          >
            ↑
          </button>
        </form>
      </div>

      {/* Artifact pane */}
      {hasArtifact && selectedArtifact && (
        <div className="w-1/2 flex flex-col">
          <div className="flex items-center justify-between px-4 py-2 border-b border-zinc-800">
            <span className="text-sm text-zinc-400">Preview</span>
            <button onClick={() => setSelectedArtifact(null)} className="text-zinc-500 hover:text-white text-lg leading-none">×</button>
          </div>
          <div className="flex-1 overflow-auto">
            <ArtifactPanel artifact={selectedArtifact} />
          </div>
          {/* Artifact tabs if multiple artifacts in last message */}
          {messages[messages.length - 1]?.artifacts.length > 1 && (
            <div className="flex gap-1 p-2 border-t border-zinc-800 overflow-x-auto">
              {messages[messages.length - 1].artifacts.map(a => (
                <button
                  key={a.id}
                  onClick={() => setSelectedArtifact(a)}
                  className={`text-xs px-3 py-1 rounded-full whitespace-nowrap
                    ${selectedArtifact.id === a.id ? 'bg-blue-600 text-white' : 'bg-zinc-800 text-zinc-400 hover:bg-zinc-700'}`}
                >
                  {a.title}
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

---

## 11 · ENVIRONMENT VARIABLES

### File: `.env.local`
```
ORNITH_API_URL=https://your-kaggle-or-other-endpoint/v1/chat/completions
ORNITH_API_KEY=your-key-if-any
SERPER_API_KEY=your-serper-key-here
```

Add `.env.local` to `.gitignore` — it's already there by default in Next.js.

---

## 12 · PAGE ENTRY POINT

### File: `/app/page.tsx`
```tsx
import { ChatInterface } from '@/components/chat/ChatInterface';

export default function Home() {
  return <ChatInterface />;
}
```

### File: `/app/layout.tsx` — ensure dark background
```tsx
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Ornith',
  description: 'AI assistant powered by Ornith 9B',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className="bg-zinc-950 text-zinc-100 antialiased">{children}</body>
    </html>
  );
}
```

---

## 13 · TAILWIND CONFIG (dark mode)

### File: `tailwind.config.ts`
```typescript
import type { Config } from 'tailwindcss';
import typography from '@tailwindcss/typography';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  darkMode: 'class',
  plugins: [typography],
};

export default config;
```

Install typography plugin if missing:
```bash
npm install -D @tailwindcss/typography
```

---

## 14 · VERIFY PHASE 1

Run through this checklist before moving to Phase 2:

```
[ ] npm run dev → no build errors
[ ] Send a message → response streams in
[ ] Ask "search for latest AI news" → search status appears, results injected
[ ] Ask "write me an HTML landing page" → artifact panel opens on right
[ ] Ask "write a markdown report about X" → md renders, .md and .docx download work
[ ] Click the mic button → browser asks for mic permission
[ ] Model downloads (one-time, ~39MB) → progress shows in STT button
[ ] Record a sentence → transcript appears in input field
[ ] Refresh page → model loads instantly from cache (no re-download)
```

---

*Continue to Phase 2 for: system prompt hardening, jailbreak resistance, thinking block UI, and streaming optimizations.*
