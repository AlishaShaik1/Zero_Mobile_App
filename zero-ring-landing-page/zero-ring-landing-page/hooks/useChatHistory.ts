'use client';

import { useState, useEffect, useCallback, useMemo } from 'react';
import { ChatSession, GroupedSessions } from '@/types';
import { getOrCreateUserUid } from '@/lib/storage/identity';

const LOCAL_SESSIONS_KEY = 'zero_local_chat_sessions';

export function useChatHistory(customUserUid?: string | null) {
    const [sessions, setSessions] = useState<ChatSession[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [searchQuery, setSearchQuery] = useState('');

    const effectiveUid = customUserUid || getOrCreateUserUid();

    // Load sessions from API / LocalStorage
    const fetchSessions = useCallback(async () => {
        const uid = effectiveUid;
        try {
            // First load from fast localStorage cache
            const cached = localStorage.getItem(`${LOCAL_SESSIONS_KEY}_${uid}`);
            if (cached) {
                try {
                    const parsed = JSON.parse(cached);
                    if (Array.isArray(parsed)) {
                        setSessions(parsed);
                    }
                } catch { }
            }

            const res = await fetch(`/api/sessions?uid=${encodeURIComponent(uid)}`);
            if (res.ok) {
                const data = await res.json();
                if (data.sessions && Array.isArray(data.sessions)) {
                    setSessions(data.sessions);
                    localStorage.setItem(`${LOCAL_SESSIONS_KEY}_${uid}`, JSON.stringify(data.sessions));
                }
            }
        } catch (err) {
            console.warn('Could not fetch sessions from server, using local cache:', err);
        } finally {
            setIsLoading(false);
        }
    }, [effectiveUid]);

    useEffect(() => {
        fetchSessions();
    }, [fetchSessions]);

    // Create a new session
    const createSession = useCallback(async (title: string = 'New Chat', model: string = 'Titan Pro'): Promise<string> => {
        const uid = effectiveUid;
        const newId = crypto.randomUUID();
        const now = new Date().toISOString();

        const newSession: ChatSession = {
            id: newId,
            user_uid: uid,
            title,
            model,
            message_count: 0,
            token_count: 0,
            created_at: now,
            updated_at: now,
        };

        setSessions(prev => [newSession, ...prev.filter(s => s.id !== newId)]);

        // Update local storage
        try {
            const current = JSON.parse(localStorage.getItem(LOCAL_SESSIONS_KEY) || '[]');
            localStorage.setItem(LOCAL_SESSIONS_KEY, JSON.stringify([newSession, ...current.filter((s: any) => s.id !== newId)]));
        } catch { }

        // Sync to backend
        try {
            await fetch('/api/sessions', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(newSession),
            });
        } catch { }

        return newId;
    }, []);

    // Rename a session (Optimistic update)
    const renameSession = useCallback(async (id: string, newTitle: string) => {
        const trimmed = newTitle.trim();
        if (!trimmed) return;

        setSessions(prev =>
            prev.map(s => (s.id === id ? { ...s, title: trimmed, updated_at: new Date().toISOString() } : s))
        );

        // Update local cache
        try {
            const current = JSON.parse(localStorage.getItem(LOCAL_SESSIONS_KEY) || '[]');
            const updated = current.map((s: any) => s.id === id ? { ...s, title: trimmed } : s);
            localStorage.setItem(LOCAL_SESSIONS_KEY, JSON.stringify(updated));
        } catch { }

        // Sync to backend
        try {
            await fetch(`/api/sessions/${id}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ title: trimmed }),
            });
        } catch (err) {
            console.error('Failed to rename session on server:', err);
        }
    }, []);

    // Delete a session (Optimistic update)
    const deleteSession = useCallback(async (id: string) => {
        setSessions(prev => prev.filter(s => s.id !== id));

        // Update local cache
        try {
            const current = JSON.parse(localStorage.getItem(LOCAL_SESSIONS_KEY) || '[]');
            const updated = current.filter((s: any) => s.id !== id);
            localStorage.setItem(LOCAL_SESSIONS_KEY, JSON.stringify(updated));
            // Also clean up stored local messages
            localStorage.removeItem(`zero_session_${id}`);
        } catch { }

        // Sync to backend
        try {
            await fetch(`/api/sessions/${id}`, {
                method: 'DELETE',
            });
        } catch (err) {
            console.error('Failed to delete session on server:', err);
        }
    }, []);

    // Update local session metadata (e.g. after message sent)
    const updateSessionMetadata = useCallback((id: string, updates: Partial<ChatSession>) => {
        setSessions(prev => {
            const existing = prev.find(s => s.id === id);
            const updatedList = existing
                ? prev.map(s => (s.id === id ? { ...s, ...updates, updated_at: new Date().toISOString() } : s))
                : [
                    {
                        id,
                        user_uid: getOrCreateUserUid(),
                        title: updates.title || 'New Chat',
                        model: updates.model || 'Titan Pro',
                        message_count: updates.message_count || 1,
                        created_at: new Date().toISOString(),
                        updated_at: new Date().toISOString(),
                        ...updates,
                    },
                    ...prev,
                ];

            try {
                localStorage.setItem(LOCAL_SESSIONS_KEY, JSON.stringify(updatedList));
            } catch { }

            return updatedList;
        });
    }, []);

    // Date grouping & search filtering
    const groupedSessions = useMemo<GroupedSessions>(() => {
        const filtered = sessions.filter(s =>
            s.title.toLowerCase().includes(searchQuery.toLowerCase())
        );

        const now = new Date();
        const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const startOfYesterday = startOfToday - 86400000;
        const startOfWeek = startOfToday - 7 * 86400000;

        const groups: GroupedSessions = {
            today: [],
            yesterday: [],
            week: [],
            older: [],
        };

        for (const session of filtered) {
            const sessionTime = new Date(session.updated_at || session.created_at).getTime();

            if (sessionTime >= startOfToday) {
                groups.today.push(session);
            } else if (sessionTime >= startOfYesterday) {
                groups.yesterday.push(session);
            } else if (sessionTime >= startOfWeek) {
                groups.week.push(session);
            } else {
                groups.older.push(session);
            }
        }

        return groups;
    }, [sessions, searchQuery]);

    return {
        sessions,
        groupedSessions,
        isLoading,
        searchQuery,
        setSearchQuery,
        createSession,
        renameSession,
        deleteSession,
        updateSessionMetadata,
        refreshSessions: fetchSessions,
    };
}
