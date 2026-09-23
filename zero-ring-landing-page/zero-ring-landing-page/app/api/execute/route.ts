import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'edge';

const JUDGE0_LANGUAGES: Record<string, { id: number; name: string }> = {
  python: { id: 100, name: 'Python 3.12' },
  python3: { id: 100, name: 'Python 3.12' },
  py: { id: 100, name: 'Python 3.12' },
  javascript: { id: 97, name: 'Node.js 20' },
  js: { id: 97, name: 'Node.js 20' },
  jsx: { id: 97, name: 'Node.js 20' },
  typescript: { id: 101, name: 'TypeScript 5.6' },
  ts: { id: 101, name: 'TypeScript 5.6' },
  tsx: { id: 101, name: 'TypeScript 5.6' },
  c: { id: 103, name: 'GCC 14.1 (C)' },
  cpp: { id: 105, name: 'GCC 14.1 (C++)' },
  'c++': { id: 105, name: 'GCC 14.1 (C++)' },
  cc: { id: 105, name: 'GCC 14.1 (C++)' },
  cxx: { id: 105, name: 'GCC 14.1 (C++)' },
  java: { id: 91, name: 'OpenJDK 17' },
  rust: { id: 108, name: 'Rust 1.85' },
  rs: { id: 108, name: 'Rust 1.85' },
  go: { id: 107, name: 'Go 1.23' },
  golang: { id: 107, name: 'Go 1.23' },
  bash: { id: 46, name: 'GNU Bash 5.0' },
  sh: { id: 46, name: 'GNU Bash 5.0' },
  shell: { id: 46, name: 'GNU Bash 5.0' },
  php: { id: 98, name: 'PHP 8.3' },
  ruby: { id: 72, name: 'Ruby 2.7' },
  rb: { id: 72, name: 'Ruby 2.7' },
  csharp: { id: 51, name: 'C# (Mono 6.6)' },
  'c#': { id: 51, name: 'C# (Mono 6.6)' },
  cs: { id: 51, name: 'C# (Mono 6.6)' },
  lua: { id: 64, name: 'Lua 5.3' },
  sql: { id: 82, name: 'SQLite 3.27' },
  swift: { id: 83, name: 'Swift 5.2' },
  r: { id: 99, name: 'R 4.4' },
};

function detectLanguageId(language: string, code: string): { id: number; name: string } {
  const lang = language.toLowerCase().trim();
  if (JUDGE0_LANGUAGES[lang]) {
    return JUDGE0_LANGUAGES[lang];
  }

  // Automatic signature detection
  if (/#include\s*<iostream>|std::|cout\s*<<|namespace\s+std|template\s*</i.test(code)) {
    return JUDGE0_LANGUAGES['cpp'];
  }
  if (/#include\s*<|int\s+main\s*\(|printf\s*\(|scanf\s*\(|void\s+main\s*\(/i.test(code)) {
    return JUDGE0_LANGUAGES['c'];
  }
  if (/public\s+class\s+|System\.out\.print/i.test(code)) {
    return JUDGE0_LANGUAGES['java'];
  }
  if (/def\s+[a-zA-Z0-9_]+\s*\(|import\s+sys|import\s+os|print\s*\(/i.test(code)) {
    return JUDGE0_LANGUAGES['python'];
  }
  if (/console\.log|function\s+|const\s+|let\s+|var\s+/i.test(code)) {
    return JUDGE0_LANGUAGES['javascript'];
  }
  if (/fn\s+main\s*\(|println!/i.test(code)) {
    return JUDGE0_LANGUAGES['rust'];
  }
  if (/package\s+main|func\s+main\s*\(/i.test(code)) {
    return JUDGE0_LANGUAGES['go'];
  }

  return JUDGE0_LANGUAGES['c'];
}

export async function POST(req: NextRequest) {
  const startTime = Date.now();
  try {
    const body = await req.json();
    const { language = '', code = '', stdin = '' } = body;

    if (!code || !code.trim()) {
      return NextResponse.json({ error: 'No code provided' }, { status: 400 });
    }

    const { id: languageId, name: compilerName } = detectLanguageId(language, code);

    // Call high-speed Judge0 CE API
    const response = await fetch('https://ce.judge0.com/submissions?base64_encoded=false&wait=true', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        source_code: code,
        language_id: languageId,
        stdin: stdin || '',
      }),
    });

    const durationMs = Date.now() - startTime;

    if (!response.ok) {
      const errText = await response.text();
      return NextResponse.json(
        {
          error: `Execution service error: ${response.status}`,
          details: errText,
          durationMs,
        },
        { status: 502 }
      );
    }

    const result = await response.json();

    const stdout = result.stdout || '';
    const compileOutput = result.compile_output || '';
    const stderr = result.stderr || compileOutput || '';
    const output = (stdout || stderr || result.message || '').trim();
    const isSuccess = result.status?.id === 3;
    const exitCode = isSuccess ? 0 : 1;

    return NextResponse.json({
      language,
      compiler: `judge0-${languageId}`,
      compilerName,
      stdout,
      stderr,
      output,
      exitCode,
      durationMs,
    });
  } catch (err: any) {
    const durationMs = Date.now() - startTime;
    return NextResponse.json(
      {
        error: err.message || 'Failed to execute code',
        stderr: err.message || 'Execution error',
        exitCode: 1,
        durationMs,
      },
      { status: 500 }
    );
  }
}
