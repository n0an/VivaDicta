# Chats

Conversational surfaces on top of the user's notes.

VivaDicta has three chat modes, each with its own view model and persistence:

- **Single-note chat** - `ChatView` + `ChatViewModel`, attached to one `Transcription`. Conversation cascade-deletes with the note.
- **Multi-note chat** - `MultiNoteChatView` + `MultiNoteChatViewModel`, built from a set of notes captured into `conversation.noteContext` at creation time.
- **Smart Search chat** - `SmartSearchChatView` + `SmartSearchChatViewModel`. No fixed note context; retrieves relevant notes per turn via RAG.

All three share `ChatMessage`, `ChatBubbleView`, `ChatInputBar`, `TypingIndicator`, and the same Apple FM / cloud provider routing.

## Documents

| Document | Description |
|----------|-------------|
| [Chat Architecture](Chat-Architecture.md) | Single-note and multi-note chat: data models, context assembly, compaction, entry points, cleanup |
| [Apple FM Chat Integration](Apple-FM-Chat-Integration.md) | Apple Foundation Models session lifecycle, synthesized transcripts, prewarming, reactive compaction, tool calling |
| [Cross-Note Search](Cross-Note-Search.md) | Explicit armed search and implicit Apple FM tool / cloud tool-decision paths; planner, RAG, `<OTHER_NOTES_SEARCH_RESULTS>` envelope |
| [Smart Chat](Smart-Chat.md) | Smart Search chat turn: planner without note text, per-turn RAG, SOURCE injection, deterministic no-evidence reply |
| [Web Search](Web-Search.md) | Exa-backed web search: explicit arming, implicit Apple FM tool, cloud tool-decision helper, `<WEB_SEARCH_RESULTS>` envelope |

## Related

- [RAG](../RAG/) - retrieval stack consumed by cross-note search and Smart Chat
- [AI Processing](../AI-Processing-Architecture.md) - provider routing shared by chat and non-chat AI calls
- [OAuth](../OAuth-Architecture.md) - sign-in flows for providers that chat can route through
