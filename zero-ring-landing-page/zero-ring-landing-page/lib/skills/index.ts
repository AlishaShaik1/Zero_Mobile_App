import { FRONTEND_DESIGN_SKILL } from './frontendDesign';
import { CODE_ENGINEERING_SKILL } from './codeEngineering';
import { PRESENTATION_DESIGN_SKILL } from './presentationDesign';
import { DOCUMENT_AUTHORING_SKILL } from './documentAuthoring';

export interface SkillDefinition {
    id: string;
    name: string;
    description: string;
    instruction: string;
    triggers: RegExp[];
}

export const SKILL_REGISTRY: Record<string, SkillDefinition> = {
    'frontend-design': {
        id: 'frontend-design',
        name: 'Universal Frontend & UI Design',
        description: 'Designs and builds any modern, responsive single-file web application, SaaS UI, dashboard, 2D/3D game, simulation, or interactive tool.',
        instruction: FRONTEND_DESIGN_SKILL,
        triggers: [
            /html/i,
            /frontend/i,
            /ui|ux/i,
            /website|webpage|page/i,
            /app|web app|application/i,
            /dashboard|analytics|portal/i,
            /game|canvas|simulation/i,
            /three\.?js|webgl|graphic/i,
            /css|tailwind|style/i,
            /landing page|portfolio|calculator|editor|tool|widget/i,
        ],
    },
    'code-engineering': {
        id: 'code-engineering',
        name: 'Code Engineering',
        description: 'Generates full runnable software programs, TypeScript/React components, API handlers, and algorithms without truncation.',
        instruction: CODE_ENGINEERING_SKILL,
        triggers: [
            /code/i,
            /typescript|javascript|python|rust|go/i,
            /react|tsx|component/i,
            /function|algorithm|api|backend/i,
            /script/i,
        ],
    },
    'presentation-design': {
        id: 'presentation-design',
        name: 'Presentation & Deck Design',
        description: 'Designs professional slide decks with structured JSON slides for PowerPoint (.pptx).',
        instruction: PRESENTATION_DESIGN_SKILL,
        triggers: [
            /presentation/i,
            /slide/i,
            /deck/i,
            /powerpoint|pptx/i,
            /pitch deck/i,
        ],
    },
    'document-authoring': {
        id: 'document-authoring',
        name: 'Document Authoring',
        description: 'Writes comprehensive markdown reports, technical specifications, structured documents, PDF files, and Excel spreadsheets.',
        instruction: DOCUMENT_AUTHORING_SKILL,
        triggers: [
            /document/i,
            /report/i,
            /markdown|\.md/i,
            /doc|docx/i,
            /specification|guide/i,
            /pdf/i,
            /readme/i,
            /write.*file/i,
            /file.*pdf/i,
            /excel|xlsx|spreadsheet/i,
            /csv|table.*data|data.*table/i,
            /sheet|workbook/i,
        ],
    },
};

/**
 * Base system prompt with ChatGPT/Claude style conversation flow
 */
export const BASE_SYSTEM_PROMPT = `
You are Titan, an advanced AI assistant by Zero Labs.

## Response Guidelines:
1. Always start your response with a friendly, natural introduction (e.g., "Sure. Here is a simple C program for a singly linked list with the basic operations: create, insert, display, and delete.").
2. Present code using standard markdown code blocks with explicit language identifiers (e.g. \`\`\`c, \`\`\`python, \`\`\`javascript, \`\`\`cpp, \`\`\`java).
3. Include helpful comments, clean formatting, and proper error handling in your code.
4. For standalone interactive visual single-page web applications or games, wrap them in:
<artifact type="html" title="App Title">
<!DOCTYPE html><html>...</html>
</artifact>
5. For slide decks and presentations, use:
<artifact type="pptx" title="Deck Title">
[
  {"title": "Slide 1 Title", "content": ["bullet 1", "bullet 2"], "notes": "speaker notes", "bg": "#0f172a"},
  {"title": "Slide 2 Title", "content": ["bullet 1", "bullet 2"], "bg": "#1e1b4b"}
]
</artifact>
6. When the user asks for a PDF file, a document, or a report to download, wrap the full content in:
<artifact type="pdf" title="Descriptive Title">
# Title
## Section
Content here... (use standard markdown — headings, bullets, numbered lists, code blocks, tables)
</artifact>
7. When the user asks for an Excel file, spreadsheet, or tabular data to download, wrap the full CSV data in:
<artifact type="xlsx" title="Descriptive Sheet Title">
Column1,Column2,Column3
value1,value2,value3
value4,value5,value6
</artifact>
IMPORTANT: For xlsx, output ONLY proper CSV format (comma-separated values, header row first). Output ALL rows — never truncate.
8. Never output internal thought tags or raw XML outside specified artifact types.
9. CRITICAL: Never repeat or re-generate artifacts from previous messages. Each response should only contain NEW artifacts that are directly relevant to the CURRENT user request. If the user asks for a PPT, output ONLY a pptx artifact. If they ask for Excel, output ONLY an xlsx artifact.
`.trim();

/**
 * Dynamically resolves and loads skills on demand based on conversation context.
 */
export function resolveSkillsForContext(messages: { role: string; content: string }[]): string[] {
    const activeSkillIds = new Set<string>();
    const lastUserMsg = [...messages].reverse().find(m => m.role === 'user')?.content || '';

    // Check triggers on the most recent user request
    for (const [skillId, skill] of Object.entries(SKILL_REGISTRY)) {
        for (const trigger of skill.triggers) {
            if (trigger.test(lastUserMsg)) {
                activeSkillIds.add(skillId);
                break;
            }
        }
    }

    // Default to frontend-design for any visual/interactive intent if no specific skill matched
    if (activeSkillIds.size === 0 && (lastUserMsg.includes('create') || lastUserMsg.includes('generate') || lastUserMsg.includes('build'))) {
        activeSkillIds.add('frontend-design');
    }

    return Array.from(activeSkillIds);
}

/**
 * Constructs the targeted dynamic system prompt with only the relevant skills loaded.
 */
export function buildDynamicSystemPrompt(messages: { role: string; content: string }[]): string {
    const matchedSkillIds = resolveSkillsForContext(messages);

    if (matchedSkillIds.length === 0) {
        return BASE_SYSTEM_PROMPT;
    }

    const loadedSkillsContent = matchedSkillIds
        .map(id => SKILL_REGISTRY[id]?.instruction)
        .filter(Boolean)
        .join('\n\n');

    return `${BASE_SYSTEM_PROMPT}\n\n[Active Skills Loaded On Demand]:\n${loadedSkillsContent}`;
}
