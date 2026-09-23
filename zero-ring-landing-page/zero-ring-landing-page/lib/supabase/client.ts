import { createClient, SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || '';

let browserClient: SupabaseClient | null = null;

/**
 * Checks if Supabase client environment variables are configured.
 */
export function isSupabaseConfigured(): boolean {
    return Boolean(supabaseUrl && supabaseAnonKey && supabaseUrl.startsWith('https://'));
}

/**
 * Get or initialize the browser Supabase singleton client.
 * Returns null if Supabase keys are not set, triggering graceful offline LocalStorage mode.
 */
export function getSupabaseBrowserClient(): SupabaseClient | null {
    if (!isSupabaseConfigured()) {
        return null;
    }
    if (!browserClient) {
        browserClient = createClient(supabaseUrl, supabaseAnonKey, {
            auth: {
                persistSession: true,
                autoRefreshToken: true,
            },
        });
    }
    return browserClient;
}
