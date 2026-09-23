'use client';

import { useState, useCallback, useRef, useEffect } from 'react';
import { Message, Artifact } from '@/types';
import { parseArtifacts } from '@/lib/ornith/artifactParser';
import { compressMessages, decompressMessages } from '@/lib/storage/compression';
import { getOrCreateUserUid } from '@/lib/storage/identity';

interface UseChatOptions {
    sessionId?: string | null;
    onSessionCreated?: (sessionId: string, title: string) => void;
    onTitleGenerated?: (sessionId: string, title: string) => void;
}

export function useChat(options?: UseChatOptions) {
    const [messages, setMessages] = useState<Message[]>([]);
    const [isStreaming, setIsStreaming] = useState(false);
    const [searchStatus, setSearchStatus] = useState<string | null>(null);
    const [activeSkill, setActiveSkill] = useState<string | null>(null);
    const [activeArtifact, setActiveArtifact] = useState<Artifact | null>(null);
    const [sessionId, setSessionId] = useState<string | null>(options?.sessionId || null);
    const [activeModelName, setActiveModelName] = useState<string>('Titan Pro');
    const [isLoadingSession, setIsLoadingSession] = useState<boolean>(false);

    const abortControllerRef = useRef<AbortController | null>(null);
    const currentReaderRef = useRef<ReadableStreamDefaultReader<Uint8Array> | null>(null);
    const sessionIdRef = useRef<string | null>(options?.sessionId || null);
    const loadedSessionIdRef = useRef<string | null>(options?.sessionId || null);

    // Keep sessionIdRef in sync
    useEffect(() => {
        sessionIdRef.current = options?.sessionId || null;
        setSessionId(options?.sessionId || null);
    }, [options?.sessionId]);

    // Load messages only when switching to a different sessionId from sidebar
    useEffect(() => {
        const currentId = options?.sessionId;
        if (!currentId) {
            if (loadedSessionIdRef.current !== null) {
                setMessages([]);
                setActiveArtifact(null);
                loadedSessionIdRef.current = null;
            }
            return;
        }

        // If this session is already loaded in memory, skip
        if (loadedSessionIdRef.current === currentId) {
            return;
        }

        loadedSessionIdRef.current = currentId;
        let isCancelled = false;
        setIsLoadingSession(true);

        // 1. Instant synchronous load from local cache (0ms delay)
        try {
            const cachedGz = localStorage.getItem(`zero_session_${currentId}`);
            if (cachedGz) {
                const cachedMsgs = decompressMessages(cachedGz);
                if (cachedMsgs.length > 0 && !isCancelled) {
                    setMessages(cachedMsgs);
                    setIsLoadingSession(false);
                }
            }
        } catch { }

        // 2. Fetch latest decompressed session from server in background
        fetch(`/api/sessions/${currentId}`)
            .then(res => res.ok ? res.json() : null)
            .then(data => {
                if (data?.session?.messages && !isCancelled) {
                    setMessages(data.session.messages);
                    // Update local cache
                    try {
                        const gz = compressMessages(data.session.messages);
                        localStorage.setItem(`zero_session_${currentId}`, gz);
                    } catch { }
                }
            })
            .catch(() => { })
            .finally(() => {
                if (!isCancelled) setIsLoadingSession(false);
            });

        return () => {
            isCancelled = true;
        };
    }, [options?.sessionId]);

    const stop = useCallback(() => {
        if (currentReaderRef.current) {
            try {
                currentReaderRef.current.cancel();
            } catch { }
            currentReaderRef.current = null;
        }
        if (abortControllerRef.current) {
            try {
                abortControllerRef.current.abort();
            } catch { }
            abortControllerRef.current = null;
        }
        setIsStreaming(false);
        setSearchStatus(null);
        setActiveSkill(null);
    }, []);

    // Save session messages helper (fire-and-forget, non-blocking)
    const persistSession = useCallback((
        targetSessionId: string,
        finalMessages: Message[],
        modelName: string,
        isFirstTurn: boolean,
        firstUserText: string
    ) => {
        const uid = getOrCreateUserUid();
        const gz = compressMessages(finalMessages);

        // 1. LocalStorage fast cache
        try {
            localStorage.setItem(`zero_session_${targetSessionId}`, gz);
        } catch { }

        // 2. Server-side Supabase persist (detached async)
        fetch(`/api/sessions/${targetSessionId}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                messages_gz: gz,
                message_count: finalMessages.length,
                model: modelName,
                user_uid: uid,
            }),
        }).catch((err) => {
            console.warn('Failed to persist session to server:', err);
        });

        // 3. Auto AI title generation on first turn (detached async)
        if (isFirstTurn && firstUserText) {
            fetch(`/api/sessions/${targetSessionId}/title`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ promptText: firstUserText }),
            })
                .then(res => res.ok ? res.json() : null)
                .then(data => {
                    if (data?.title && options?.onTitleGenerated) {
                        options.onTitleGenerated(targetSessionId, data.title);
                    }
                })
                .catch(() => { });
        }
    }, [options]);

    const send = useCallback(async (userText: string, modelName: string = 'Titan Pro', webSearch: boolean = false) => {
        // If a previous stream is running, abort cleanly
        if (abortControllerRef.current) {
            abortControllerRef.current.abort();
        }
        const controller = new AbortController();
        abortControllerRef.current = controller;

        // Ensure session ID exists
        let activeId = sessionIdRef.current;
        const isNewSession = !activeId;
        if (!activeId) {
            activeId = crypto.randomUUID();
            sessionIdRef.current = activeId;
            setSessionId(activeId);
            const initialTitle = userText.slice(0, 30).trim() + (userText.length > 30 ? '…' : '');
            if (options?.onSessionCreated) {
                options.onSessionCreated(activeId, initialTitle);
            }
        }

        const userMsg: Message = {
            id: crypto.randomUUID(),
            role: 'user',
            text: userText,
            artifacts: [],
            timestamp: Date.now(),
        };

        const isFirstTurn = messages.length === 0;
        const updatedWithUser = [...messages, userMsg];
        setMessages(updatedWithUser);
        setIsStreaming(true);
        setActiveSkill(null);
        setSearchStatus(webSearch ? 'Connecting to Zero Real-Time Search...' : null);

        const assistantId = crypto.randomUUID();
        let accumulated = '';

        // Add placeholder assistant message
        setMessages(prev => [...prev, {
            id: assistantId,
            role: 'assistant',
            text: '',
            artifacts: [],
            timestamp: Date.now(),
        }]);

        let finalCompletedMessages: Message[] = [...updatedWithUser];

        let detectedModelName = modelName;
        setActiveModelName(modelName);
        let pendingText = '';
        let pendingArtifacts: Artifact[] = [];

        try {
            const history = updatedWithUser.map(m => ({
                role: m.role,
                content: m.text,
            }));

            const res = await fetch('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    messages: history,
                    model: modelName,
                    webSearch: webSearch,
                }),
                signal: controller.signal,
            });

            if (!res.ok) {
                const errorText = await res.text();
                const errMessage: Message = {
                    id: assistantId,
                    role: 'assistant',
                    text: `⚠️ ${errorText || 'Failed to connect to Zero GPU Cluster. Please verify status.'}`,
                    artifacts: [],
                    timestamp: Date.now(),
                    model: modelName,
                    webSearchUsed: webSearch,
                };
                setMessages(prev => prev.map(m => m.id === assistantId ? errMessage : m));
                finalCompletedMessages = [...updatedWithUser, errMessage];
                return;
            }

            const reader = res.body?.getReader();
            if (!reader) throw new Error('No stream body returned');
            currentReaderRef.current = reader;

            const decoder = new TextDecoder();
            let buffer = '';
            let rafId: number | null = null;

            const flushStreamUpdate = () => {
                setMessages(prev => prev.map(m =>
                    m.id === assistantId
                        ? { ...m, text: pendingText, artifacts: pendingArtifacts, model: detectedModelName, webSearchUsed: webSearch }
                        : m
                ));

                if (pendingArtifacts.length > 0) {
                    setActiveArtifact(prev => {
                        if (!prev) return null;
                        const updated = pendingArtifacts.find(a => a.id === prev.id);
                        return updated || prev;
                    });
                }
                rafId = null;
            };

            while (true) {
                if (controller.signal.aborted) {
                    try { await reader.cancel(); } catch { }
                    break;
                }

                const { done, value } = await reader.read();
                if (done) break;

                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');
                buffer = lines.pop() ?? '';

                for (const line of lines) {
                    if (!line.startsWith('data:')) continue;
                    const raw = line.slice(5).trim();
                    if (raw === '[DONE]') break;

                    try {
                        const event = JSON.parse(raw);

                        if (event.type === 'model_info' && event.model) {
                            detectedModelName = event.model;
                            setActiveModelName(event.model);
                        }
                        if (event.type === 'tool_start') {
                            setSearchStatus(`🔍 Live Web Search: "${event.query || userText}"…`);
                        }
                        if (event.type === 'tool_result') {
                            setSearchStatus('⚡ Search synthesized, streaming GPU response…');
                        }
                        if (event.type === 'token') {
                            accumulated += event.token;
                            const { text, artifacts, activeSkill: detectedSkill } = parseArtifacts(accumulated, false);

                            if (detectedSkill) {
                                setActiveSkill(detectedSkill);
                            }

                            pendingText = text;
                            pendingArtifacts = artifacts;

                            if (!rafId) {
                                rafId = requestAnimationFrame(flushStreamUpdate);
                            }
                        }
                    } catch {
                        // Skip unparsed lines
                    }
                }
            }

            if (rafId) {
                cancelAnimationFrame(rafId);
                flushStreamUpdate();
            }
        } catch (err: any) {
            if (err.name === 'AbortError' || controller.signal.aborted) {
                // Stream stopped gracefully by user
            } else {
                console.error('Chat stream error:', err);
                const networkErrMsg: Message = {
                    id: assistantId,
                    role: 'assistant',
                    text: `⚠️ Network error: ${err.message}. Please check your connection.`,
                    artifacts: [],
                    timestamp: Date.now(),
                    model: modelName,
                    webSearchUsed: webSearch,
                };
                setMessages(prev => prev.map(m => m.id === assistantId && !m.text ? networkErrMsg : m));
            }
        } finally {
            if (abortControllerRef.current === controller) {
                abortControllerRef.current = null;
            }
            currentReaderRef.current = null;

            // Finalize artifacts & messages
            let finalAssistantMessage: Message;
            if (accumulated) {
                const { text, artifacts } = parseArtifacts(accumulated, true);
                const finalArtifacts = artifacts.map(a => ({ ...a, isGenerating: false }));
                finalAssistantMessage = {
                    id: assistantId,
                    role: 'assistant',
                    text,
                    artifacts: finalArtifacts,
                    timestamp: Date.now(),
                    model: detectedModelName || modelName,
                    webSearchUsed: webSearch,
                };
                setMessages(prev => prev.map(m => m.id === assistantId ? finalAssistantMessage : m));
                setActiveArtifact(prev => {
                    if (!prev) return null;
                    const updated = finalArtifacts.find(a => a.id === prev.id);
                    return updated ? { ...updated, isGenerating: false } : prev;
                });
            } else {
                finalAssistantMessage = {
                    id: assistantId,
                    role: 'assistant',
                    text: pendingText || '',
                    artifacts: pendingArtifacts || [],
                    timestamp: Date.now(),
                    model: detectedModelName || modelName,
                    webSearchUsed: webSearch,
                };
            }

            finalCompletedMessages = [...updatedWithUser, finalAssistantMessage];

            setIsStreaming(false);
            setSearchStatus(null);
            setActiveSkill(null);

            // Persist full conversation to Supabase & LocalStorage
            if (activeId) {
                persistSession(activeId, finalCompletedMessages, modelName, isFirstTurn, userText);
            }
        }
    }, [messages, options, persistSession]);

    return {
        sessionId,
        setSessionId,
        messages,
        setMessages,
        send,
        sendMessage: send,
        stop,
        stopGenerating: stop,
        isStreaming,
        isTyping: isStreaming,
        searchStatus,
        activeSkill,
        activeArtifact,
        setActiveArtifact,
        activeModelName,
        isLoadingSession,
    };
}
