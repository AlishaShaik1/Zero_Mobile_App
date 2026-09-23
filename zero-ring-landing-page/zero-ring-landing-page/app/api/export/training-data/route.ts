import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { decompressMessages } from '@/lib/storage/compression';

export const runtime = 'nodejs';

/**
 * GET /api/export/training-data?uid=<user_uid>&all=true
 * Exports chat sessions as a fine-tuning ready JSONL dataset.
 */
export async function GET(req: NextRequest) {
    try {
        const { searchParams } = new URL(req.url);
        const userUid = searchParams.get('uid');
        const exportAll = searchParams.get('all') === 'true';

        const supabase = getSupabaseServerClient();
        if (!supabase) {
            return NextResponse.json({ error: 'Supabase storage is not configured' }, { status: 400 });
        }

        let query = supabase
            .from('chat_sessions')
            .select('id, user_uid, model, messages_gz, created_at')
            .not('messages_gz', 'is', null);

        if (!exportAll && userUid) {
            query = query.eq('user_uid', userUid);
        }

        const { data, error } = await query;

        if (error) {
            return NextResponse.json({ error: error.message }, { status: 500 });
        }

        const jsonlLines: string[] = [];

        for (const session of data || []) {
            const messages = decompressMessages(session.messages_gz);
            if (messages.length < 2) continue;

            const formattedMessages = messages.map(m => ({
                role: m.role,
                content: m.text,
            })).filter(m => m.content && m.content.trim().length > 0);

            if (formattedMessages.length >= 2) {
                const record = {
                    session_id: session.id,
                    model: session.model,
                    created_at: session.created_at,
                    messages: formattedMessages,
                };
                jsonlLines.push(JSON.stringify(record));
            }
        }

        const fileContent = jsonlLines.join('\n');
        const filename = `zero_training_dataset_${new Date().toISOString().slice(0, 10)}.jsonl`;

        return new NextResponse(fileContent, {
            status: 200,
            headers: {
                'Content-Type': 'application/jsonl; charset=utf-8',
                'Content-Disposition': `attachment; filename="${filename}"`,
            },
        });
    } catch (err: any) {
        console.error('Export training data exception:', err);
        return NextResponse.json({ error: err.message || 'Internal error' }, { status: 500 });
    }
}
