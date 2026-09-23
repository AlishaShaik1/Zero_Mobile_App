'use client';
import { Artifact } from '@/types';
import { saveAs } from 'file-saver';

const slug = (s: string) => s.replace(/\s+/g, '-').toLowerCase();

// ── Smart dispatcher — calls the right generator per type ─────────────────────
export async function downloadArtifact(artifact: Artifact) {
    switch (artifact.type) {
        case 'pptx':
            return downloadPptx(artifact);
        case 'xlsx':
        case 'csv':
            return downloadXlsx(artifact);
        case 'pdf':
            return downloadPdf(artifact);
        case 'html':
            saveAs(new Blob([artifact.content], { type: 'text/html;charset=utf-8' }), `${slug(artifact.title)}.html`);
            return;
        case 'markdown':
        case 'md':
            saveAs(new Blob([artifact.content], { type: 'text/markdown;charset=utf-8' }), `${slug(artifact.title)}.md`);
            return;
        case 'json':
            saveAs(new Blob([artifact.content], { type: 'application/json;charset=utf-8' }), `${slug(artifact.title)}.json`);
            return;
        default: {
            const ext = artifact.language ?? (artifact.type !== 'code' ? artifact.type : 'txt') ?? 'txt';
            saveAs(new Blob([artifact.content], { type: 'text/plain;charset=utf-8' }), `${slug(artifact.title)}.${ext}`);
        }
    }
}

// ── Load pptxgenjs from CDN (its npm build requires node:fs, CDN UMD build is browser-safe) ──
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

// ── PPTX via pptxgenjs ────────────────────────────────────────────────────────
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
            fontSize: 32, bold: true, color: 'FFFFFF', fontFace: 'Arial',
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
    saveAs(
        new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.presentationml.presentation' }),
        `${slug(artifact.title)}.pptx`
    );
}

// ── XLSX via SheetJS ──────────────────────────────────────────────────────────
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
    } catch { /* not JSON, parse as CSV */ }

    // Parse CSV
    const rows: string[][] = [];
    for (const line of content.split('\n').filter(l => l.trim())) {
        const fields: string[] = [];
        let field = '';
        let inQuotes = false;
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === '"') {
                if (inQuotes && line[i + 1] === '"') { field += '"'; i++; }
                else { inQuotes = !inQuotes; }
            } else if (ch === ',' && !inQuotes) {
                fields.push(field.trim()); field = '';
            } else { field += ch; }
        }
        fields.push(field.trim());
        rows.push(fields);
    }

    worksheet = XLSX.utils.aoa_to_sheet(rows);
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

// ── PDF via jsPDF ─────────────────────────────────────────────────────────────
async function downloadPdf(artifact: Artifact) {
    const { jsPDF } = await import('jspdf');
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });

    const pageWidth = doc.internal.pageSize.getWidth();
    const margin = 18;
    const contentWidth = pageWidth - margin * 2;
    let y = 20;
    const pageHeight = doc.internal.pageSize.getHeight();

    const addPage = () => { doc.addPage(); y = 20; };
    const ensureSpace = (n: number) => { if (y + n > pageHeight - 15) addPage(); };

    const print = (text: string, size: number, color: [number, number, number], bold: boolean, indent = 0) => {
        doc.setFontSize(size);
        doc.setTextColor(...color);
        doc.setFont('helvetica', bold ? 'bold' : 'normal');
        for (const line of doc.splitTextToSize(text, contentWidth - indent)) {
            ensureSpace(size * 0.5 + 3);
            doc.text(line, margin + indent, y);
            y += size * 0.45 + 2;
        }
    };

    let inCode = false;
    let codeLines: string[] = [];
    const flushCode = () => {
        if (!codeLines.length) return;
        const bh = Math.min(codeLines.length * 4.5 + 6, pageHeight - y - 15);
        ensureSpace(bh + 4);
        doc.setFillColor(30, 30, 40);
        doc.roundedRect(margin - 2, y - 2, contentWidth + 4, bh, 2, 2, 'F');
        doc.setFont('courier', 'normal'); doc.setFontSize(8); doc.setTextColor(180, 230, 180);
        for (const cl of codeLines) {
            if (y > pageHeight - 18) addPage();
            for (const wl of doc.splitTextToSize(cl || ' ', contentWidth - 4)) { doc.text(wl, margin + 2, y); y += 4.5; }
        }
        y += 4; codeLines = [];
    };

    for (const line of artifact.content.split('\n')) {
        if (line.startsWith('```')) { inCode ? (flushCode(), inCode = false) : (inCode = true); continue; }
        if (inCode) { codeLines.push(line); continue; }
        const clean = (s: string) => s.replace(/\*\*([^*]+)\*\*/g, '$1').replace(/\*([^*]+)\*/g, '$1');
        if (line.startsWith('# ')) { y += 4; ensureSpace(12); print(line.slice(2), 18, [10, 10, 50], true); doc.setDrawColor(34, 200, 255); doc.setLineWidth(0.5); doc.line(margin, y - 1, margin + contentWidth, y - 1); y += 3; }
        else if (line.startsWith('## ')) { y += 3; ensureSpace(10); print(line.slice(3), 13, [20, 20, 80], true); y += 1; }
        else if (line.startsWith('### ')) { y += 2; ensureSpace(8); print(line.slice(4), 11, [40, 40, 100], true); }
        else if (line.startsWith('- ') || line.startsWith('* ')) { ensureSpace(6); for (const wl of doc.splitTextToSize('• ' + clean(line.slice(2)), contentWidth - 4)) { doc.setFontSize(10); doc.setTextColor(40, 40, 40); doc.setFont('helvetica', 'normal'); ensureSpace(5); doc.text(wl, margin + 3, y); y += 5; } }
        else if (/^\d+\.\s/.test(line)) { ensureSpace(6); for (const wl of doc.splitTextToSize(clean(line), contentWidth - 4)) { doc.setFontSize(10); doc.setTextColor(40, 40, 40); doc.setFont('helvetica', 'normal'); ensureSpace(5); doc.text(wl, margin + 3, y); y += 5; } }
        else if (line.trim() === '') { y += 3; }
        else { print(clean(line), 10, [30, 30, 30], false); y += 1; }
    }
    if (inCode) flushCode();

    const total = (doc.internal as any).getNumberOfPages();
    for (let i = 1; i <= total; i++) {
        doc.setPage(i);
        doc.setFontSize(8); doc.setTextColor(160, 160, 160); doc.setFont('helvetica', 'normal');
        doc.text(artifact.title + ' — Titan Pro · Zero Labs', margin, pageHeight - 8);
        doc.text(i + ' / ' + total, pageWidth - margin, pageHeight - 8, { align: 'right' });
    }
    doc.save(`${slug(artifact.title)}.pdf`);
}
