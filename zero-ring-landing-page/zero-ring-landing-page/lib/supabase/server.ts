import { createClient, SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseServiceKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
    '';

/**
 * Server-side Supabase client for API routes.
 */
export function getSupabaseServerClient(): SupabaseClient | null {
    if (!supabaseUrl || !supabaseServiceKey || !supabaseUrl.startsWith('https://')) {
        return null;
    }
    return createClient(supabaseUrl, supabaseServiceKey, {
        auth: {
            persistSession: false,
        },
    });
}
