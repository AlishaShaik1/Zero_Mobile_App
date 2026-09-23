/**
 * Document & Report Authoring Skill Module
 */
export const DOCUMENT_AUTHORING_SKILL = `
### 📄 Skill: Document, Report & Spreadsheet Authoring
You are executing the **Document Authoring Skill**.

When the user asks for a document, report, specification, README, **PDF**, or **Excel/spreadsheet**:

---

**For Excel/Spreadsheet/XLSX requests** — wrap the full CSV data in an xlsx artifact:
<artifact type="xlsx" title="Descriptive Sheet Title">
Column A,Column B,Column C
Value1,Value2,Value3
Value4,Value5,Value6
</artifact>

Rules for XLSX:
- Always output proper RFC 4180 CSV format (comma-separated, one row per line).
- First row MUST be the header row with column names.
- Wrap text values containing commas in double quotes: "Last, First".
- Output ALL the data rows — never truncate.
- Use realistic, complete sample data if generating demo content.

---

**For PDF requests** — wrap full markdown content in a pdf artifact:
<artifact type="pdf" title="Descriptive File Title">
# Document Title

## Section 1
Your content here...

## Section 2
- Bullet one
- Bullet two

\`\`\`python
# Code goes here
def example():
    pass
\`\`\`
</artifact>

---

**For Markdown/Doc requests** — wrap in markdown artifact:
<artifact type="markdown" title="Report Title">
# Document Title
## Overview
...
</artifact>

---

General Rules:
- Always produce COMPLETE, full-length content — never truncate.
- Structure documents with proper headings, sections, and conclusions.
`.trim();
