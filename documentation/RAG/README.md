# RAG

Retrieval-augmented generation stack and the surfaces that consume it.

One shared backend powers every RAG-driven feature in the app:

- **Indexer**: `RAGIndexingService` (LumoKit + VecturaKit)
- **Embedder**: `SwiftEmbedder` with `minishlab/potion-base-32M`
- **Chunking**: semantic strategy, `chunkSize = 500`, `overlapPercentage = 0.15`
- **Retrieval threshold**: `0.25`
- **Indexed content**: `transcription.text` only (never `enhancedText` or variations)
- **Feature flag**: `SmartSearchFeature.isEnabled` gates indexing, search, and every consumer surface

Consumers:

- Main notes list search bar (All / Keyword / Smart modes)
- Smart Search chat (per-turn retrieval, see [Chats/Smart-Chat.md](../Chats/Smart-Chat.md))
- Cross-note search in normal chat (see [Chats/Cross-Note-Search.md](../Chats/Cross-Note-Search.md))

## Documents

| Document | Description |
|----------|-------------|
| [Smart Search RAG Architecture](Smart-Search-RAG-Architecture.md) | Full architecture: indexing, embedder setup, planner-first retrieval, prompt injection, Apple vs cloud execution |
| [Smart Search RAG Flow](Smart-Search-RAG-Flow.md) | Short operational turn-flow view of a Smart Search chat message end-to-end |
| [Search Bar RAG](Search-Bar-RAG.md) | Main notes list search: All / Keyword / Smart modes, gating rules, score pills, tag filtering |
| [Tool Provider Support](Tool-Provider-Support.md) | Provider matrix: which providers support cross-note search, web search, and Smart Search note RAG |

## Related

- [Chats](../Chats/) - chat surfaces that inject RAG results into prompts
- [Data Persistence & CloudKit Sync](../Data-Persistence-CloudKit-Architecture.md) - `Transcription` model that gets indexed
- [AI Processing](../AI-Processing-Architecture.md) - provider routing used by planners and final answer calls
