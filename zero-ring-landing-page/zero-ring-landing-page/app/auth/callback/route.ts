import { NextRequest, NextResponse } from 'next/server';
import { getSupabaseServerClient } from '@/lib/supabase/server';

export const runtime = 'nodejs';

/**
 * GET /auth/callback
 * Handles OAuth code exchange for Google Sign-In and redirects the user to /chat.
 */
export async function GET(req: NextRequest) {
    const { searchParams, origin } = new URL(req.url);
    const code = searchParams.get('code');
    const next = searchParams.get('next') || '/chat';

    if (code) {
        const supabase = getSupabaseServerClient();
        if (supabase) {
            try {
                await supabase.auth.exchangeCodeForSession(code);
            } catch (err) {
                console.error('Failed to exchange auth code:', err);
            }
        }
    }

    return NextResponse.redirect(`${origin}${next}`);
}
