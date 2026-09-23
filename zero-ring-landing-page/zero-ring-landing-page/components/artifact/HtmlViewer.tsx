'use client';
import { useEffect, useRef } from 'react';

export function HtmlViewer({ content }: { content: string }) {
    const iframeRef = useRef<HTMLIFrameElement>(null);

    useEffect(() => {
        if (!iframeRef.current) return;
        // Use srcdoc — no allow-same-origin so iframe can't reach parent DOM
        iframeRef.current.srcdoc = content;
    }, [content]);

    return (
        <iframe
            ref={iframeRef}
            sandbox="allow-scripts allow-forms allow-modals"
            className="w-full border-0"
            style={{ height: '500px', minHeight: '300px', resize: 'vertical', overflow: 'auto' }}
            title="HTML Preview"
        />
    );
}
