import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';

const ZERO_GPU_BASE = process.env.ZERO_GPU_API_BASE || 'https://zero-gpu-server.vercel.app/v1';
const ZERO_GPU_API_KEY = process.env.ZERO_GPU_API_KEY || 'zerotech13287';

/**
 * POST /api/sessions/[id]/title
 * Generates an automated concise 3-5 word title using the Zero GPU model.
 */
export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { id } = await params;
        const body = await req.json();
        const { promptText } = body;

        if (!id || !promptText) {
            return NextResponse.json({ error: 'Session ID and prompt text required' }, { status: 400 });
        }

        let generatedTitle = '';

        try {
            const res = await fetch(`${ZERO_GPU_BASE}/chat/completions`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${ZERO_GPU_API_KEY}`,
                },
                body: JSON.stringify({
                    model: 'titan-pro',
                    messages: [
                        {
                            role: 'system',
                            content: 'You are a chat title generator. Generate a concise 3 to 5 word title summarizing the user topic. Output ONLY the plain title with no quotation marks, no periods, and no prefixes.'
                        },
                        {
                            role: 'user',
                            content: promptText.slice(0, 300)
                        }
                    ],
                    max_tokens: 15,
                    temperature: 0.3,
                }),
            });

            if (res.ok) {
                const data = await res.json();
                const rawTitle = data.choices?.[0]?.message?.content?.trim() || '';
                generatedTitle = rawTitle.replace(/^["'`]|["'`]$/g, '').replace(/^Title:\s*/i, '').trim();
            }
        } catch (err) {
            console.warn('AI title generation failed, using fallback heuristic:', err);
        }

        // Fallback if AI generation failed or returned blank
        if (!generatedTitle || generatedTitle.length < 2) {
            generatedTitle = promptText
                .slice(0, 35)
                .replace(/[\n\r]/g, ' ')
                .trim() + (promptText.length > 35 ? '…' : '');
        }

        // Clean formatting
        generatedTitle = generatedTitle.slice(0, 48);

        // Update in Supabase if configured
        const supabase = getSupabaseServerClient();
        if (supabase) {
            await supabase
                .from('chat_sessions')
                .update({ title: generatedTitle, updated_at: new Date().toISOString() })
                .eq('id', id);
        }

        return NextResponse.json({ title: generatedTitle });
    } catch (err: any) {
        console.error('Session title generation exception:', err);
        return NextResponse.json({ error: err.message || 'Internal error' }, { status: 500 });
    }
}
