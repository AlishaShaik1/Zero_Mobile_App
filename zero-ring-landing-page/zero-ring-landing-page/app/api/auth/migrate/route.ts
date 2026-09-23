import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';

/**
 * POST /api/auth/migrate
 * Migrates chat sessions from an anonymous guest UID to the authenticated user ID.
 */
export async function POST(req: NextRequest) {
    try {
        const body = await req.json();
        const { guestUid, authUserId } = body;

        if (!guestUid || !authUserId) {
            return NextResponse.json({ error: 'guestUid and authUserId are required' }, { status: 400 });
        }

        const supabase = getSupabaseServerClient();
        if (!supabase) {
            return NextResponse.json({ success: true, offline: true });
        }

        // Migrate all guest sessions to authenticated user ID
        const { data, error } = await supabase
            .from('chat_sessions')
            .update({ user_uid: authUserId, updated_at: new Date().toISOString() })
            .eq('user_uid', guestUid)
            .select('id');

        if (error) {
            console.error('Failed to migrate guest sessions:', error);
            return NextResponse.json({ error: error.message }, { status: 500 });
        }

        return NextResponse.json({
            success: true,
            migratedCount: data?.length || 0,
        });
    } catch (err: any) {
        console.error('Migrate sessions exception:', err);
        return NextResponse.json({ error: err.message || 'Internal error' }, { status: 500 });
    }
}
