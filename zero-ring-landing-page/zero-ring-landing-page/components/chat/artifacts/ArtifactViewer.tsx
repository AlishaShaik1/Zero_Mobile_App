'use client';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Maximize2, ExternalLink } from 'lucide-react';
import { Artifact } from '@/types';
import { ArtifactPanel } from '@/components/artifact/ArtifactPanel';

interface ArtifactViewerProps {
  artifact: Artifact | null;
  onClose: () => void;
}

export function ArtifactViewer({ artifact, onClose }: ArtifactViewerProps) {
  return (
    <AnimatePresence>
      {artifact && (
        <>
          {/* Backdrop */}
          <motion.div
            key="artifact-backdrop"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={onClose}
            className="fixed inset-0 z-[140] bg-black/40 backdrop-blur-[3px]"
          />

          {/* Sliding Drawer */}
          <motion.div
            key="artifact-drawer"
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            transition={{ type: 'spring', damping: 28, stiffness: 260 }}
            className="fixed inset-y-0 right-0 w-full sm:w-[92vw] md:w-[80vw] lg:w-[65vw] max-w-5xl bg-[#0F1015] border-l border-white/10 shadow-[0_0_60px_rgba(0,0,0,0.5)] z-[150] flex flex-col overflow-hidden"
          >
            {/* Header */}
            <div className="flex items-center justify-between px-5 py-3.5 border-b border-white/10 bg-[#161822] text-white">
              <div className="flex items-center gap-2.5 overflow-hidden">
                <span className="w-2 h-2 rounded-full bg-[#22C8FF]" />
                <span className="font-semibold text-sm truncate">{artifact.title}</span>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-white/10 text-white/70 uppercase">
                  {artifact.type}
                </span>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={onClose}
                  className="p-1.5 rounded-lg text-white/60 hover:text-white hover:bg-white/10 transition-colors"
                  title="Close preview"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Content area */}
            <div className="flex-1 overflow-hidden flex flex-col bg-[#0A0B0E]">
              <ArtifactPanel artifact={artifact} />
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
