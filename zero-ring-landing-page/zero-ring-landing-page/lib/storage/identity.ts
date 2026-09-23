'use client';

const USER_UID_STORAGE_KEY = 'zero_user_uid';

/**
 * Retrieves the persistent anonymous user UUID from localStorage,
 * or generates and stores a new UUID if this is the first visit.
 * Stable across sessions, page reloads, and tabs.
 */
export function getOrCreateUserUid(): string {
    if (typeof window === 'undefined') return 'server-user';
    try {
        let uid = localStorage.getItem(USER_UID_STORAGE_KEY);
        if (!uid) {
            uid = 'usr_' + crypto.randomUUID().replace(/-/g, '');
            localStorage.setItem(USER_UID_STORAGE_KEY, uid);
        }
        return uid;
    } catch {
        return 'temp-user';
    }
}
