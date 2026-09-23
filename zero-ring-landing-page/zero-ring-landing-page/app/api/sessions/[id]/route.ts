import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { decompressMessages } from '@/lib/storage/compression';

export const runtime = 'nodejs';

/**
 * GET /api/sessions/[id]
 * Returns the full session record including decompressed messages.
 */
export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { id } = await params;
        if (!id) {
            return NextResponse.json({ error: 'Session ID is required' }, { status: 400 });
        }

        const supabase = getSupabaseServerClient();
        if (!supabase) {
            return NextResponse.json({ error: 'Supabase offline' }, { status: 404 });
        }

        const { data, error } = await supabase
            .from('chat_sessions')
            .select('*')
            .eq('id', id)
            .single();

        if (error || !data) {
            return NextResponse.json({ error: error?.message || 'Session not found' }, { status: 404 });
        }

        const messages = decompressMessages(data.messages_gz);

        return NextResponse.json({
            session: {
                id: data.id,
                user_uid: data.user_uid,
                title: data.title,
                model: data.model,
                message_count: data.message_count,
                token_count: data.token_count,
                created_at: data.created_at,
                updated_at: data.updated_at,
                messages,
            }
        });
    } catch (err: any) {
        console.error('Session GET exception:', err);
        return NextResponse.json({ error: err.message || 'Internal error' }, { status: 500 });
    }
}

/**
 * PATCH /api/sessions/[id]
 * Updates session title, compressed messages, and metadata.
 */
export async function PATCH(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { id } = await params;
        if (!id) {
            return NextResponse.json({ error: 'Session ID is required' }, { status: 400 });
        }

        const body = await req.json();
        const { title, messages_gz, message_count, model, user_uid } = body;

        const supabase = getSupabaseServerClient();
        if (!supabase) {
            return NextResponse.json({ success: true, offline: true });
        }

        const updatePayload: Record<string, any> = {
            updated_at: new Date().toISOString(),
        };

        if (title !== undefined) updatePayload.title = title;
        if (messages_gz !== undefined) updatePayload.messages_gz = messages_gz;
        if (message_count !== undefined) updatePayload.message_count = message_count;
        if (model !== undefined) updatePayload.model = model;
        if (user_uid !== undefined) updatePayload.user_uid = user_uid;

        const { data, error } = await supabase
            .from('chat_sessions')
            .upsert({
                id,
                ...updatePayload,
            })
            .select()
            .single();

        if (error) {
            console.error('Supabase update session error:', error);
            return NextResponse.json({ error: error.message }, { status: 500 });
        }

        return NextResponse.json({ session: data });
    } catch (err: any) {
        console.error('Session PATCH exception:', err);
        return NextResponse.json({ error: err.message || 'Internal error' }, { status: 500 });
    }
}

/**
 * DELETE /api/sessions/[id]
 * Permanently deletes a chat session.
 */
export async function DELETE(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
    try {
        const { id } = await params;
        if (!id) {
            return NextResponse.json({ error: 'Session ID is required' }, { status: 400 });
        }

        const supabase = getSupabaseServerClient();
        if (!supabase) {
            return NextResponse.json({ success: true, offline: true });
        }

        const { error } = await supabase
            .from('chat_sessions')
            .delete()
            .eq('id', id);

        if (error) {
            console.error('Supabase delete session error:', error);
            return NextResponse.json({ error: error.message }, { status: 500 });
        }

        return NextResponse.json({ success: true });
    } catch (err: any) {
        console.error('Session DELETE exception:', err);
        return NextResponse.json({ error: err.message || 'Internal error' }, { status: 500 });
    }
}
