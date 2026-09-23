// These are the JSON schemas for the tools your LLM can call.
// This is formatted in the standard OpenAI tool calling schema structure.

export const tools = [
  {
    type: "function",
    function: {
      name: "generate_artifact",
      description: "Generates an artifact such as an HTML preview, PowerPoint presentation, Excel spreadsheet, Markdown document, PDF, or Project Folder structure. Use this when the user asks for a file, presentation, code, or document.",
      parameters: {
        type: "object",
        properties: {
          type: {
            type: "string",
            enum: ["html", "md", "pptx", "xlsx", "csv", "pdf", "folder", "code", "json"],
            description: "The type of artifact to generate."
          },
          title: {
            type: "string",
            description: "A short, descriptive title for the artifact."
          },
          description: {
            type: "string",
            description: "A brief description of what this artifact contains."
          },
          content: {
            type: "string",
            description: "The raw content of the artifact. For HTML, MD, CODE, or JSON, put the full text/code here."
          },
          metadata: {
            type: "object",
            description: "Structured data required for certain complex artifacts.",
            properties: {
              slides: {
                type: "array",
                description: "Required if type is 'pptx'. An array of slide objects.",
                items: {
                  type: "object",
                  properties: {
                    title: { type: "string" },
                    content: { type: "string" },
                    bullets: { type: "array", items: { type: "string" } }
                  }
                }
              },
              data: {
                type: "array",
                description: "Required if type is 'xlsx' or 'csv'. An array of objects representing rows.",
                items: {
                  type: "object",
                  additionalProperties: true
                }
              },
              files: {
                type: "array",
                description: "Required if type is 'folder'. An array of file objects.",
                items: {
                  type: "object",
                  properties: {
                    path: { type: "string", description: "File path, e.g., src/index.js" },
                    content: { type: "string", description: "File content" }
                  },
                  required: ["path", "content"]
                }
              }
            }
          }
        },
        required: ["type", "title", "description", "content"]
      }
    }
  },
  {
    type: "function",
    function: {
      name: "search_web",
      description: "Searches the web for up-to-date information. Use this when the user asks a question about current events or requires external knowledge.",
      parameters: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "The search query to look up on the web."
          }
        },
        required: ["query"]
      }
    }
  }
];
