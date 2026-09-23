import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';

/**
 * GET /api/sessions?uid=<user_uid>
 * Returns all chat sessions for the given user, ordered by most recently updated.
 */
export async function GET(req: NextRequest) {
    try {
        const { searchParams } = new URL(req.url);
        const userUid = searchParams.get('uid');

        if (!userUid) {
            return NextResponse.json({ error: 'User UID is required' }, { status: 400 });
        }

        const supabase = getSupabaseServerClient();
        if (!supabase) {
            // Supabase not configured -> client uses LocalStorage
            return NextResponse.json({ sessions: [], offline: true });
        }

        const { data, error } = await supabase
            .from('chat_sessions')
            .select('id, user_uid, title, model, message_count, token_count, created_at, updated_at')
            .eq('user_uid', userUid)
            .order('updated_at', { ascending: false });

        if (error) {
            console.error('Supabase get sessions error:', error);
            return NextResponse.json({ error: error.message }, { status: 500 });
        }

        return NextResponse.json({ sessions: data || [] });
    } catch (err: any) {
        console.error('Sessions GET exception:', err);
        return NextResponse.json({ error: err.message || 'Internal error' }, { status: 500 });
    }
}

/**
 * POST /api/sessions
 * Creates a new chat session.
 */
export async function POST(req: NextRequest) {
    try {
        const body = await req.json();
        const { id, user_uid, title = 'New Chat', model = 'Titan Pro', messages_gz = '', message_count = 0 } = body;

        if (!id || !user_uid) {
            return NextResponse.json({ error: 'Session ID and User UID are required' }, { status: 400 });
        }

        const supabase = getSupabaseServerClient();
        if (!supabase) {
            return NextResponse.json({ success: true, offline: true });
        }

        const { data, error } = await supabase
            .from('chat_sessions')
            .upsert({
                id,
                user_uid,
                title,
                model,
                messages_gz,
                message_count,
                updated_at: new Date().toISOString(),
            })
            .select()
            .single();

        if (error) {
            console.error('Supabase create session error:', error);
            return NextResponse.json({ error: error.message }, { status: 500 });
        }

        return NextResponse.json({ session: data });
    } catch (err: any) {
        console.error('Sessions POST exception:', err);
        return NextResponse.json({ error: err.message || 'Internal error' }, { status: 500 });
    }
}
