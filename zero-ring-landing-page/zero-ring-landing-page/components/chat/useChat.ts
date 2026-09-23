import { useState, useCallback } from 'react';
import { ChatMessage, ArtifactItem } from './types';

export function useChat() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isTyping, setIsTyping] = useState(false);
  const [activeArtifact, setActiveArtifact] = useState<ArtifactItem | null>(null);

  const sendMessage = useCallback(async (content: string, model: string, webSearch: boolean) => {
    const userMessage: ChatMessage = {
      id: Date.now().toString(),
      role: 'user',
      content,
      timestamp: new Date(),
    };
    
    // Optimistically update the UI with the user's message
    const newMessages = [...messages, userMessage];
    setMessages(prev => [...prev, userMessage]);
    setIsTyping(true);

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          messages: newMessages,
          model,
          webSearchEnabled: webSearch
        })
      });

      if (!response.ok) {
        throw new Error('Failed to fetch response from API');
      }

      const data = await response.json();
      
      const assistantMessage: ChatMessage = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: data.text,
        timestamp: new Date(),
        model: model,
        webSearchUsed: webSearch,
        artifacts: data.artifacts
      };
      
      setMessages(prev => [...prev, assistantMessage]);
      
      // Auto-open first artifact if any
      if (data.artifacts && data.artifacts.length > 0) {
        setActiveArtifact(data.artifacts[0]);
      }
    } catch (error) {
      console.error(error);
      const errorMessage: ChatMessage = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: "Sorry, I encountered an error communicating with the server.",
        timestamp: new Date(),
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsTyping(false);
    }
  }, [messages]);

  return {
    messages,
    sendMessage,
    isTyping,
    activeArtifact,
    setActiveArtifact
  };
}
