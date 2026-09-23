import { FileText, Code, Presentation, FileSpreadsheet, Folder, Download, Maximize2, Loader2, Sparkles, BookOpen } from 'lucide-react';
import { Artifact } from '@/types';
import { downloadArtifact } from '../../../lib/fileGenerators';

export function ArtifactCard({ artifact, onView }: { artifact: Artifact, onView: (a: Artifact) => void }) {
  const getIcon = () => {
    switch (artifact.type) {
      case 'html': return <Code className="w-5 h-5 text-[#E34F26]" />;
      case 'markdown':
      case 'md': return <FileText className="w-5 h-5 text-[#111111]" />;
      case 'pptx': return <Presentation className="w-5 h-5 text-[#D24726]" />;
      case 'xlsx':
      case 'csv': return <FileSpreadsheet className="w-5 h-5 text-[#217346]" />;
      case 'pdf': return <BookOpen className="w-5 h-5 text-[#E53E3E]" />;
      case 'folder': return <Folder className="w-5 h-5 text-[#F8D775]" />;
      case 'code': return <Code className="w-5 h-5 text-[#F7DF1E]" />;
      case 'json': return <Code className="w-5 h-5 text-[#111111]" />;
      default: return <FileText className="w-5 h-5" />;
    }
  };

  const isGenerating = !!artifact.isGenerating;

  return (
    <div className={`flex flex-col border rounded-xl overflow-hidden mt-3 bg-[#F8F7F3] shadow-sm max-w-sm transition-all ${
      isGenerating ? 'border-[#22C8FF]/50 shadow-[0_0_15px_rgba(34,200,255,0.15)] animate-pulse' : 'border-[#E0E0E0]'
    }`}>
      <div className="flex items-center gap-3 p-3 bg-white border-b border-[#E0E0E0]">
        <div className="p-2 bg-[#F8F7F3] rounded-lg">
          {getIcon()}
        </div>
        <div className="flex-1 overflow-hidden">
          <div className="flex items-center gap-2">
            <h4 className="text-sm font-bold text-[#111111] truncate">{artifact.title}</h4>
            {isGenerating && (
              <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-sky-100 text-sky-700 font-semibold flex items-center gap-1">
                <Loader2 className="w-2.5 h-2.5 animate-spin" />
                <span>Building</span>
              </span>
            )}
          </div>
          <p className="text-xs text-[#111111]/60 truncate">
            {isGenerating ? `Streaming ${(artifact.type || 'code').toUpperCase()} (${artifact.content.length} chars)...` : artifact.description}
          </p>
        </div>
      </div>
      <div className="flex items-center justify-between p-2 bg-[#FAFAFA]">
        <button
          onClick={() => onView(artifact)}
          disabled={isGenerating && !artifact.content}
          className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-[#111111] hover:bg-[#E0E0E0] rounded-md transition-colors disabled:opacity-50"
        >
          <Maximize2 className="w-3.5 h-3.5" />
          {isGenerating ? 'Live Preview' : 'Preview'}
        </button>
        <button
          onClick={() => downloadArtifact(artifact)}
          disabled={isGenerating}
          className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-white bg-[#22C8FF] hover:bg-[#1ba0cc] rounded-md transition-colors disabled:opacity-50"
        >
          <Download className="w-3.5 h-3.5" />
          Download
        </button>
      </div>
    </div>
  );
}
