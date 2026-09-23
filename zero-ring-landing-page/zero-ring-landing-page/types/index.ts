export type ArtifactType = 'markdown' | 'html' | 'code' | 'md' | 'json' | 'pdf' | 'pptx' | 'docx' | 'xlsx' | 'csv' | 'folder';

export interface Artifact {
    id: string;
    type: ArtifactType;
    title: string;
    language?: string;      // for code artifacts
    description?: string;   // optional subtitle
    content: string;
    isGenerating?: boolean;
}

export interface Message {
    id: string;
    role: 'user' | 'assistant';
    text: string;          // rendered text (no artifact tags)
    thinking?: string;     // Phase 2
    artifacts: Artifact[];
    timestamp: number;
    model?: string;
    webSearchUsed?: boolean;
}

export interface Tool {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
}

export interface ChatSession {
    id: string;
    user_uid?: string;
    title: string;
    model: string;
    message_count: number;
    token_count?: number;
    created_at: string;
    updated_at: string;
}

export interface GroupedSessions {
    today: ChatSession[];
    yesterday: ChatSession[];
    week: ChatSession[];
    older: ChatSession[];
}
