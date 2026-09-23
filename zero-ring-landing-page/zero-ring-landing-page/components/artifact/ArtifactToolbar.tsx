'use client';
import { Artifact } from '@/types';
import { saveAs } from 'file-saver';
import { Document, Paragraph, TextRun, HeadingLevel, Packer } from 'docx';

interface Props {
    artifact: Artifact;
}

// Slug helper
const slug = (s: string) => s.replace(/\s+/g, '-').toLowerCase();

// ── Load pptxgenjs from CDN (its npm ES build requires node:fs; CDN UMD build is browser-safe) ──
async function loadPptxGenJS(): Promise<any> {
    if (typeof (window as any).PptxGenJS !== 'undefined') {
        return (window as any).PptxGenJS;
    }
    return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/pptxgenjs@4.0.1/dist/pptxgen.bundle.js';
        script.onload = () => resolve((window as any).PptxGenJS);
        script.onerror = () => reject(new Error('Failed to load pptxgenjs from CDN'));
        document.head.appendChild(script);
    });
}

// ── PPTX download via pptxgenjs ──────────────────────────────────────────────
async function downloadPptx(artifact: Artifact) {
    const PptxGenJS = await loadPptxGenJS();
    const prs = new PptxGenJS();

    prs.layout = 'LAYOUT_16x9';
    prs.author = 'Titan Pro — Zero Labs';
    prs.title = artifact.title;

    let slides: { title: string; content: string[]; notes?: string; bg?: string }[] = [];
    try {
        slides = JSON.parse(artifact.content);
    } catch {
        slides = [{ title: artifact.title, content: [artifact.content] }];
    }

    slides.forEach((slide) => {
        const s = prs.addSlide();
        const bg = slide.bg ?? '#0f0f1a';
        s.background = { fill: bg.replace('#', '') };

        s.addText(slide.title ?? '', {
            x: 0.5, y: 0.4, w: '90%', h: 1.0,
            fontSize: 32, bold: true, color: 'FFFFFF',
            fontFace: 'Arial',
        });

        const bullets = (slide.content ?? []).map((line: string) => ({
            text: line,
            options: { bullet: true, fontSize: 18, color: 'DDDDEE', indentLevel: 0 },
        }));
        if (bullets.length > 0) {
            s.addText(bullets, { x: 0.5, y: 1.6, w: '90%', h: 4.5, fontFace: 'Arial' });
        }

        if (slide.notes) s.addNotes(slide.notes);
    });

    const buf = await prs.write({ outputType: 'arraybuffer' }) as ArrayBuffer;
    saveAs(new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' }),
        `${slug(artifact.title)}.pptx`);
}

// ── DOCX download via docx.js ─────────────────────────────────────────────────
async function downloadDocx(artifact: Artifact) {
    const lines = artifact.content.split('\n');
    const children = lines.map(line => {
        if (line.startsWith('# ')) return new Paragraph({ text: line.slice(2), heading: HeadingLevel.HEADING_1 });
        if (line.startsWith('## ')) return new Paragraph({ text: line.slice(3), heading: HeadingLevel.HEADING_2 });
        if (line.startsWith('### ')) return new Paragraph({ text: line.slice(4), heading: HeadingLevel.HEADING_3 });
        if (line.startsWith('- ') || line.startsWith('* ')) {
            return new Paragraph({ text: line.slice(2), bullet: { level: 0 } });
        }
        return new Paragraph({ children: [new TextRun({ text: line, size: 24 })], spacing: { after: 120 } });
    });

    const doc = new Document({ sections: [{ properties: {}, children }] });
    const blob = await Packer.toBlob(doc);
    saveAs(blob, `${slug(artifact.title)}.docx`);
}

// ── XLSX download via xlsx (SheetJS) ─────────────────────────────────────────
async function downloadXlsx(artifact: Artifact) {
    const XLSX = await import('xlsx');
    const content = artifact.content.trim();

    let workbook: ReturnType<typeof XLSX.utils.book_new>;
    let worksheet: ReturnType<typeof XLSX.utils.aoa_to_sheet>;

    // Try JSON array-of-objects first
    try {
        const jsonData = JSON.parse(content);
        if (Array.isArray(jsonData) && jsonData.length > 0) {
            worksheet = XLSX.utils.json_to_sheet(jsonData);
            workbook = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(workbook, worksheet, 'Sheet1');
            const buf = XLSX.write(workbook, { bookType: 'xlsx', type: 'array' });
            saveAs(new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }),
                `${slug(artifact.title)}.xlsx`);
            return;
        }
    } catch { /* not JSON, fall through to CSV parse */ }

    // Parse as CSV (the primary format the AI outputs inside xlsx artifacts)
    const rows: string[][] = [];
    const rawLines = content.split('\n').filter(l => l.trim());
    for (const line of rawLines) {
        const fields: string[] = [];
        let field = '';
        let inQuotes = false;
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === '"') {
                if (inQuotes && line[i + 1] === '"') { field += '"'; i++; }
                else { inQuotes = !inQuotes; }
            } else if (ch === ',' && !inQuotes) {
                fields.push(field.trim());
                field = '';
            } else {
                field += ch;
            }
        }
        fields.push(field.trim());
        rows.push(fields);
    }

    worksheet = XLSX.utils.aoa_to_sheet(rows);

    // Auto column widths based on header length
    if (rows.length > 0) {
        worksheet['!cols'] = rows[0].map(h => ({ wch: Math.max((h || '').length + 4, 12) }));
    }

    workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Sheet1');

    const buf = XLSX.write(workbook, { bookType: 'xlsx', type: 'array' });
    saveAs(
        new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }),
        `${slug(artifact.title)}.xlsx`
    );
}

// ── PDF download via jsPDF ────────────────────────────────────────────────────
async function downloadPdf(artifact: Artifact) {
    const { jsPDF } = await import('jspdf');
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });

    const pageWidth = doc.internal.pageSize.getWidth();
    const margin = 18;
    const contentWidth = pageWidth - margin * 2;
    let y = 20;
    const pageHeight = doc.internal.pageSize.getHeight();

    const addPage = () => { doc.addPage(); y = 20; };
    const ensureSpace = (needed: number) => { if (y + needed > pageHeight - 15) addPage(); };

    const wrapAndPrint = (text: string, fontSize: number, color: [number, number, number], bold: boolean, indent = 0) => {
        doc.setFontSize(fontSize);
        doc.setTextColor(...color);
        doc.setFont('helvetica', bold ? 'bold' : 'normal');
        const wrapped = doc.splitTextToSize(text, contentWidth - indent);
        for (const line of wrapped) {
            ensureSpace(fontSize * 0.5 + 3);
            doc.text(line, margin + indent, y);
            y += fontSize * 0.45 + 2;
        }
    };

    const lines = artifact.content.split('\n');
    let inCodeBlock = false;
    let codeLines: string[] = [];

    const flushCodeBlock = () => {
        if (codeLines.length === 0) return;
        const blockHeight = Math.min(codeLines.length * 4.5 + 6, pageHeight - y - 15);
        ensureSpace(blockHeight + 4);
        doc.setFillColor(30, 30, 40);
        doc.roundedRect(margin - 2, y - 2, contentWidth + 4, blockHeight, 2, 2, 'F');
        doc.setFont('courier', 'normal');
        doc.setFontSize(8);
        doc.setTextColor(180, 230, 180);
        for (const cl of codeLines) {
            if (y > pageHeight - 18) { addPage(); }
            const wrapped = doc.splitTextToSize(cl || ' ', contentWidth - 4);
            for (const wl of wrapped) { doc.text(wl, margin + 2, y); y += 4.5; }
        }
        y += 4;
        codeLines = [];
    };

    for (const line of lines) {
        if (line.startsWith('```')) {
            if (inCodeBlock) { flushCodeBlock(); inCodeBlock = false; }
            else { inCodeBlock = true; }
            continue;
        }
        if (inCodeBlock) { codeLines.push(line); continue; }

        if (line.startsWith('# ')) {
            y += 4; ensureSpace(12);
            wrapAndPrint(line.slice(2), 18, [10, 10, 50], true);
            doc.setDrawColor(34, 200, 255); doc.setLineWidth(0.5);
            doc.line(margin, y - 1, margin + contentWidth, y - 1); y += 3;
        } else if (line.startsWith('## ')) {
            y += 3; ensureSpace(10); wrapAndPrint(line.slice(3), 13, [20, 20, 80], true); y += 1;
        } else if (line.startsWith('### ')) {
            y += 2; ensureSpace(8); wrapAndPrint(line.slice(4), 11, [40, 40, 100], true);
        } else if (line.startsWith('- ') || line.startsWith('* ')) {
            ensureSpace(6);
            const cleanText = line.slice(2).replace(/\*\*([^*]+)\*\*/g, '$1');
            doc.setFontSize(10); doc.setTextColor(40, 40, 40); doc.setFont('helvetica', 'normal');
            const wrapped = doc.splitTextToSize('• ' + cleanText, contentWidth - 4);
            for (const wl of wrapped) { ensureSpace(5); doc.text(wl, margin + 3, y); y += 5; }
        } else if (/^\d+\.\s/.test(line)) {
            ensureSpace(6);
            const cleanText = line.replace(/\*\*([^*]+)\*\*/g, '$1');
            doc.setFontSize(10); doc.setTextColor(40, 40, 40); doc.setFont('helvetica', 'normal');
            const wrapped = doc.splitTextToSize(cleanText, contentWidth - 4);
            for (const wl of wrapped) { ensureSpace(5); doc.text(wl, margin + 3, y); y += 5; }
        } else if (line.startsWith('---') || line.startsWith('===')) {
            ensureSpace(6); doc.setDrawColor(200, 200, 210); doc.setLineWidth(0.3);
            doc.line(margin, y, margin + contentWidth, y); y += 5;
        } else if (line.trim() === '') {
            y += 3;
        } else {
            const cleanText = line.replace(/\*\*([^*]+)\*\*/g, '$1').replace(/\*([^*]+)\*/g, '$1');
            wrapAndPrint(cleanText, 10, [30, 30, 30], false); y += 1;
        }
    }
    if (inCodeBlock) flushCodeBlock();

    const totalPages = (doc.internal as any).getNumberOfPages();
    for (let i = 1; i <= totalPages; i++) {
        doc.setPage(i);
        doc.setFontSize(8); doc.setTextColor(160, 160, 160); doc.setFont('helvetica', 'normal');
        doc.text(artifact.title + ' — Generated by Titan Pro · Zero Labs', margin, pageHeight - 8);
        doc.text(i + ' / ' + totalPages, pageWidth - margin, pageHeight - 8, { align: 'right' });
    }

    doc.save(`${slug(artifact.title)}.pdf`);
}

export function ArtifactToolbar({ artifact }: Props) {
    const copy = () => navigator.clipboard.writeText(artifact.content);
    const dlMd = () => saveAs(new Blob([artifact.content], { type: 'text/markdown;charset=utf-8' }), `${slug(artifact.title)}.md`);
    const dlHtml = () => saveAs(new Blob([artifact.content], { type: 'text/html;charset=utf-8' }), `${slug(artifact.title)}.html`);
    const dlCsv = () => saveAs(new Blob([artifact.content], { type: 'text/csv;charset=utf-8' }), `${slug(artifact.title)}.csv`);
    const dlCode = () => {
        const ext = artifact.language ?? 'txt';
        saveAs(new Blob([artifact.content], { type: 'text/plain;charset=utf-8' }), `${slug(artifact.title)}.${ext}`);
    };

    const typeLabel: Record<string, string> = {
        markdown: 'Markdown', html: 'HTML', code: artifact.language?.toUpperCase() ?? 'Code',
        pptx: 'Presentation', docx: 'Document', md: 'Markdown', pdf: 'PDF Document',
        xlsx: 'Excel Spreadsheet', csv: 'CSV Data',
    };

    return (
        <div className="flex items-center gap-2 px-3 py-2 bg-zinc-800 border-b border-zinc-700 text-xs text-zinc-300 flex-wrap">
            <span className="font-medium text-white truncate flex-1">{artifact.title}</span>
            <span className="text-zinc-500">{typeLabel[artifact.type] ?? artifact.type}</span>
            <button onClick={copy} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">Copy</button>

            {(artifact.type === 'markdown' || artifact.type === 'md') && (
                <>
                    <button onClick={dlMd} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.md</button>
                    <button onClick={() => downloadDocx(artifact)} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.docx</button>
                </>
            )}
            {artifact.type === 'docx' && (
                <button onClick={() => downloadDocx(artifact)} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.docx</button>
            )}
            {artifact.type === 'html' && (
                <button onClick={dlHtml} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.html</button>
            )}
            {artifact.type === 'code' && (
                <button onClick={dlCode} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">
                    .{artifact.language ?? 'txt'}
                </button>
            )}
            {artifact.type === 'pptx' && (
                <button onClick={() => downloadPptx(artifact)} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.pptx</button>
            )}
            {artifact.type === 'pdf' && (
                <button
                    onClick={() => downloadPdf(artifact)}
                    className="flex items-center gap-1 hover:text-white px-2 py-1 rounded hover:bg-zinc-700 text-red-300 font-semibold"
                >
                    ⬇ Download PDF
                </button>
            )}
            {(artifact.type === 'xlsx' || artifact.type === 'csv') && (
                <>
                    <button
                        onClick={() => downloadXlsx(artifact)}
                        className="flex items-center gap-1 hover:text-white px-2 py-1 rounded hover:bg-zinc-700 text-emerald-300 font-semibold"
                    >
                        ⬇ Download .xlsx
                    </button>
                    <button onClick={dlCsv} className="hover:text-white px-2 py-1 rounded hover:bg-zinc-700">.csv</button>
                </>
            )}
        </div>
    );
}
