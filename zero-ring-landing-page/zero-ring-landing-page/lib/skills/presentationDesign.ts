/**
 * Presentation & Slide Deck Skill Module
 */
export const PRESENTATION_DESIGN_SKILL = `
### 📊 Skill: Presentation & Slide Deck Design
You are executing the **Presentation Design Skill**.
- Produce structured, visually engaging slide decks formatted as a valid JSON array of slide objects.
- Each slide contains: title, content (array of bullet strings), notes (speaker notes), and bg (theme hex color like \`#0f172a\`, \`#1e1b4b\`, \`#022c22\`).
- Always wrap in artifact tags:
<artifact type="pptx" title="Presentation Title">
[
  {"title": "Executive Summary", "content": ["Key breakthrough", "Market opportunity", "Strategic roadmap"], "notes": "Introduction note", "bg": "#0f172a"},
  {"title": "Core Architecture", "content": ["Distributed dual-T4 cluster", "Sub-500ms retrieval", "Hardware MTP acceleration"], "bg": "#1e1b4b"}
]
</artifact>
`.trim();
