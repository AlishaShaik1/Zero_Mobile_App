export type ArtifactType = 'html' | 'md' | 'pptx' | 'xlsx' | 'pdf' | 'folder' | 'code' | 'csv' | 'json';

export interface ArtifactItem {
  id: string;
  type: ArtifactType;
  title: string;
  description: string;
  content: string; // Used for raw text, code, HTML, MD, JSON
  metadata?: any;  // Used for structured data like PPTX slides, XLSX data, or folder tree
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  model?: string;
  webSearchUsed?: boolean;
  artifacts?: ArtifactItem[];
}
