import { Artifact, ArtifactType } from '@/types';

interface ParseResult {
    text: string;           // clean text without artifact tags, think blocks, or skill calls
    artifacts: Artifact[];  // extracted artifacts (both complete and streaming)
    isComplete: boolean;    // true when all open tags are fully closed
    activeSkill: string | null; // active skill name if invoked
}

const SKILL_LABELS: Record<string, string> = {
    'frontend-design': 'Frontend Design Skill',
    'presentation-design': 'Presentation Skill',
    'document-authoring': 'Document Skill',
    'code-engineering': 'Code Engineering Skill',
    'web-search': 'Search Retrieval Skill',
};

// Call this on the FULL accumulated response string as it streams
export function parseArtifacts(raw: string, isStreamFinal: boolean = false): ParseResult {
    const artifacts: Artifact[] = [];
    let text = raw;
    let activeSkill: string | null = null;

    // 1. Strip reasoning <think>...</think> blocks cleanly
    if (text.includes('</think>')) {
        text = text.substring(text.lastIndexOf('</think>') + 8).trim();
    } else if (text.includes('<think>')) {
        // Discard everything from <think> onwards while thinking
        text = text.substring(0, text.indexOf('<think>')).trim();
    }

    // 2. Detect and strip <skill_call name="..."> tags
    const skillMatch = text.match(/<skill(?:_call)?\s+name="([^"]+)"[^>]*>(?:<\/skill(?:_call)?>)?/i);
    if (skillMatch) {
        const rawSkillId = skillMatch[1].toLowerCase().trim();
        activeSkill = SKILL_LABELS[rawSkillId] || `${rawSkillId.replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase())} Skill`;
        text = text.replace(skillMatch[0], '').trim();
    }

    // 3. Extract and replace all fully closed <artifact ...>...</artifact> tags
    const closedArtifactRegex = /<artifact\s+type="([^"]+)"(?:\s+language="([^"]+)")?(?:\s+title="([^"]+)")?[^>]*>([\s\S]*?)<\/artifact>/gi;
    let match: RegExpExecArray | null;
    const seen = new Set<string>();

    while ((match = closedArtifactRegex.exec(text)) !== null) {
        const [fullMatch, type, language, title, content] = match;
        const id = `artifact-${artifacts.length}`;

        if (!seen.has(fullMatch)) {
            seen.add(fullMatch);
            artifacts.push({
                id,
                type: (type as ArtifactType) || 'code',
                title: title || `Artifact ${artifacts.length + 1}`,
                language,
                description: `${(type || 'code').toUpperCase()} file`,
                content: content.trim(),
                isGenerating: false,
            });
            text = text.replace(fullMatch, '');
        }
    }

    // 4. Check for in-progress (unclosed) <artifact ...> tag currently streaming
    const openArtifactMatch = text.match(/<artifact\s+type="([^"]+)"(?:\s+language="([^"]+)")?(?:\s+title="([^"]+)")?[^>]*>([\s\S]*)$/i);
    let isComplete = true;

    if (openArtifactMatch) {
        isComplete = isStreamFinal;
        const [fullOpenMatch, type, language, title, partialContent] = openArtifactMatch;
        const id = `artifact-${artifacts.length}`;

        artifacts.push({
            id,
            type: (type as ArtifactType) || 'code',
            title: title || 'Interactive Project',
            language,
            description: isStreamFinal ? `${(type || 'code').toUpperCase()} file` : `Generating ${(type || 'code').toUpperCase()}...`,
            content: partialContent.trim(),
            isGenerating: !isStreamFinal,
        });

        // Strip the unclosed artifact block from display text so raw code never leaks into chat
        text = text.replace(fullOpenMatch, '');
    } else if (/<artifact\b/i.test(text)) {
        // Tag is opening without full header yet
        isComplete = isStreamFinal;
        text = text.replace(/<artifact[\s\S]*$/i, '');
    }

    // 5. Fallback Auto-Detection: If raw <!DOCTYPE html> or <html> was output without artifact tags
    if (artifacts.length === 0 && (text.includes('<!DOCTYPE html>') || text.includes('<html'))) {
        const htmlStartIndex = text.indexOf('<!DOCTYPE html>') !== -1 ? text.indexOf('<!DOCTYPE html>') : text.indexOf('<html');
        const preText = text.substring(0, htmlStartIndex).trim();
        let rawHtml = text.substring(htmlStartIndex).trim();

        // Extract title if present
        const titleMatch = rawHtml.match(/<title>([^<]+)<\/title>/i);
        const title = titleMatch ? titleMatch[1].trim() : 'Interactive Simulation';

        // Check if </html> is closed
        const hasClosingTag = rawHtml.includes('</html>');

        artifacts.push({
            id: 'artifact-0',
            type: 'html',
            title: title,
            description: isStreamFinal || hasClosingTag ? 'HTML Application' : 'Generating HTML...',
            content: rawHtml,
            isGenerating: !(isStreamFinal || hasClosingTag),
        });

        // Replace raw HTML in conversation text
        text = preText;
        isComplete = hasClosingTag || isStreamFinal;
    }

    return { text: text.trim(), artifacts, isComplete, activeSkill };
}

// Tool call detector: returns query string or null
export function detectToolCall(text: string): string | null {
    const match = text.match(/<tool_call>\s*\{"name"\s*:\s*"web_search"\s*,\s*"arguments"\s*:\s*\{"query"\s*:\s*"([^"]+)"\s*\}\s*\}\s*<\/tool_call>/);
    return match ? match[1] : null;
}
