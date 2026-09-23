'use client';

import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { User, Session, AuthError } from '@supabase/supabase-js';
import { getSupabaseBrowserClient } from '@/lib/supabase/client';
import { getOrCreateUserUid } from '@/lib/storage/identity';

interface AuthContextType {
    user: User | null;
    session: Session | null;
    isLoading: boolean;
    signInWithEmail: (email: string, password: string) => Promise<{ error: AuthError | null }>;
    signUpWithEmail: (email: string, password: string) => Promise<{ error: AuthError | null; user: User | null }>;
    signInWithGoogle: () => Promise<{ error: AuthError | null }>;
    forgotPassword: (email: string) => Promise<{ error: AuthError | null }>;
    updatePassword: (password: string) => Promise<{ error: AuthError | null }>;
    signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
    const [user, setUser] = useState<User | null>(null);
    const [session, setSession] = useState<Session | null>(null);
    const [isLoading, setIsLoading] = useState(true);

    // Helper to migrate guest sessions to the authenticated user ID
    const migrateGuestSessions = useCallback(async (authUserId: string) => {
        try {
            const guestUid = getOrCreateUserUid();
            if (guestUid && guestUid !== authUserId) {
                await fetch('/api/auth/migrate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        guestUid,
                        authUserId,
                    }),
                });
            }
        } catch (err) {
            console.warn('Failed to migrate guest sessions:', err);
        }
    }, []);

    useEffect(() => {
        const supabase = getSupabaseBrowserClient();
        if (!supabase) {
            setIsLoading(false);
            return;
        }

        // 1. Initial session check
        supabase.auth.getSession().then(({ data: { session: initialSession } }) => {
            setSession(initialSession);
            setUser(initialSession?.user ?? null);
            setIsLoading(false);
            if (initialSession?.user?.id) {
                migrateGuestSessions(initialSession.user.id);
            }
        });

        // 2. Real-time auth state listener
        const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, currentSession) => {
            setSession(currentSession);
            setUser(currentSession?.user ?? null);
            setIsLoading(false);

            if (event === 'SIGNED_IN' && currentSession?.user?.id) {
                await migrateGuestSessions(currentSession.user.id);
            }
        });

        return () => {
            subscription.unsubscribe();
        };
    }, [migrateGuestSessions]);

    // Sign in with Email & Password
    const signInWithEmail = async (email: string, password: string) => {
        const supabase = getSupabaseBrowserClient();
        if (!supabase) {
            return { error: { message: 'Supabase client is not configured' } as AuthError };
        }
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
        });
        if (!error && data.user) {
            setUser(data.user);
            setSession(data.session);
            await migrateGuestSessions(data.user.id);
        }
        return { error };
    };

    // Sign up with Email & Password
    const signUpWithEmail = async (email: string, password: string) => {
        const supabase = getSupabaseBrowserClient();
        if (!supabase) {
            return { error: { message: 'Supabase client is not configured' } as AuthError, user: null };
        }
        const { data, error } = await supabase.auth.signUp({
            email,
            password,
            options: {
                emailRedirectTo: typeof window !== 'undefined' ? `${window.location.origin}/auth/callback` : undefined,
            }
        });
        if (!error && data.user) {
            setUser(data.user);
            setSession(data.session);
            if (data.user.id) {
                await migrateGuestSessions(data.user.id);
            }
        }
        return { error, user: data.user };
    };

    // Real Google OAuth
    const signInWithGoogle = async () => {
        const supabase = getSupabaseBrowserClient();
        if (!supabase) {
            return { error: { message: 'Supabase client is not configured' } as AuthError };
        }
        const redirectTo = typeof window !== 'undefined' ? `${window.location.origin}/auth/callback` : '';
        const { error } = await supabase.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo,
                queryParams: {
                    access_type: 'offline',
                    prompt: 'consent',
                },
            },
        });
        return { error };
    };

    // Send Forgot Password Email Link
    const forgotPassword = async (email: string) => {
        const supabase = getSupabaseBrowserClient();
        if (!supabase) {
            return { error: { message: 'Supabase client is not configured' } as AuthError };
        }
        const redirectTo = typeof window !== 'undefined' ? `${window.location.origin}/chat?view=reset-password` : '';
        const { error } = await supabase.auth.resetPasswordForEmail(email, {
            redirectTo,
        });
        return { error };
    };

    // Update password (for users arriving via password reset link)
    const updatePassword = async (password: string) => {
        const supabase = getSupabaseBrowserClient();
        if (!supabase) {
            return { error: { message: 'Supabase client is not configured' } as AuthError };
        }
        const { error } = await supabase.auth.updateUser({
            password,
        });
        return { error };
    };

    // Sign out
    const signOut = async () => {
        const supabase = getSupabaseBrowserClient();
        if (supabase) {
            await supabase.auth.signOut();
        }
        setUser(null);
        setSession(null);
    };

    return (
        <AuthContext.Provider
            value={{
                user,
                session,
                isLoading,
                signInWithEmail,
                signUpWithEmail,
                signInWithGoogle,
                forgotPassword,
                updatePassword,
                signOut,
            }}
        >
            {children}
        </AuthContext.Provider>
    );
}

export function useAuth() {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
}
