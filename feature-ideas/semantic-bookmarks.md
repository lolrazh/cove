# Semantic Bookmarks — Feature Spec

> Status: **Idea / Research complete** — not yet in implementation
> Created: 2026-03-08

## The Problem

Bookmarks are dumb. You save 500 things, then can't find the article about "that cool distributed systems thing" because you don't remember the exact title or URL. Traditional bookmarks rely on manual folders/tags (nobody maintains them) or keyword search (fails when you remember the *concept* but not the *words*).

## The Vision

Every bookmark gets automatically understood. When you save a page, Cove extracts its content, runs it through a local embedding model, and stores a semantic fingerprint alongside it. Later, you search by *meaning* — "articles about async patterns in Swift" finds your saved Combine tutorial even if those exact words never appeared in the title.

Zero cloud. Zero manual tagging. Everything runs on-device.

---

## Prior Art & Inspiration

### MyMind (mymind.com)
- "Remember everything, organize nothing" — zero manual organization
- AI auto-categorizes content type (article, product, recipe, image, video)
- AI auto-tags every saved item (objects, colors, brands, mood for images; topic tags for text)
- "Same Vibe" — visual similarity search across your collection
- Associative/semantic search: find by concept, not keyword
- Knowledge graph connecting saves; "Smart Collections" auto-group by theme
- **Key takeaway**: The magic is *zero user effort*. All intelligence applied at save time.

### Chrome's Internal Semantic Engine (2025-2026)
- Full DocumentChunker: walks DOM, aggregates text into 200-word passages (max 30/page)
- 1540-dimension embeddings stored in SQLite history DB
- Used for history semantic search and Gemini browsing assistant
- Cosine similarity for ranking, stored as compressed protocol buffers

### Open-Source Projects
- **Karakeep** (fka Hoarder) — self-hosted "bookmark everything" with AI auto-tagging via Ollama. Semantic search planned but not shipped.
- **Revery** — personal semantic search using FastText word embeddings (300d), cosine similarity. Indexes ~25k docs. Written in Go, no deps.
- **Bookmark++** — Chrome extension using local AI (Transformer.js embeddings + summarization). Fully private.
- **VecturaKit** — Swift vector DB for on-device RAG using MLTensor. Hybrid search (vector + BM25). Zero external deps via Apple NaturalLanguage framework. *Directly relevant to Cove.*

### Other Bookmark Tools
- **Raindrop.io** — AI assistant "Stella" auto-sorts/tags, but no vector search
- **Pinboard** — minimalist, tag-centric, no AI (in decline)
- **Are.na** — block-based, human curation, no AI

---

## Architecture Overview

### Pipeline (what happens when you bookmark a page)

```
User clicks "Bookmark" (⌘D)
         │
         ▼
  ┌─────────────────┐
  │ Content Extract  │  ← readability algorithm strips nav/ads/chrome
  │ (main text only) │    extract: title, text, meta description, OG tags
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │   Chunking       │  ← split text into ~200-word passages
  │   (if long)      │    short pages = single chunk
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │  Embedding Model │  ← local inference via MLX (or alternative)
  │  (on-device)     │    input: text chunks → output: float vectors
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │  SQLite Storage  │  ← bookmark row + embedding vectors (BLOB)
  │  + FTS5 index    │    hybrid: vector similarity + keyword search
  └─────────────────┘
```

### Search (what happens when you search bookmarks)

```
User types query in bookmark search
         │
         ▼
  ┌─────────────────┐
  │  Embed Query     │  ← same model, same dimensions
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │  Hybrid Search   │  ← cosine similarity (semantic)
  │                  │    + FTS5 match (keyword)
  │                  │    combine scores, return top-K
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │  Results UI      │  ← ranked list with title, URL, snippet, relevance
  └─────────────────┘
```

---

## Content Extraction Strategy

**In WKWebView, inject JavaScript** to extract clean content from the page:

1. **Title** — `document.title`
2. **Meta description** — `document.querySelector('meta[name="description"]')?.content`
3. **Open Graph tags** — og:title, og:description, og:image
4. **Main body text** — use a Readability-style algorithm (Mozilla's Readability.js is BSD-licensed, ~2000 lines). Strip nav, sidebars, footers, ads. Return the main article content.
5. **Fallback** — if Readability fails, grab `document.body.innerText` (noisy but better than nothing)

Inject this as a `WKUserScript` or call it via `evaluateJavaScript()` at bookmark time.

**Chunking**: Split extracted text into ~200-word passages. For most bookmarked pages (articles, blog posts), this yields 1-10 chunks. Short pages (tweets, product pages) = 1 chunk.

---

## SQLite Schema

```sql
-- Core bookmark data
CREATE TABLE bookmarks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    url         TEXT    NOT NULL UNIQUE,
    title       TEXT,
    description TEXT,           -- meta description or first paragraph
    favicon     TEXT,           -- domain key (references favicon store)
    created_at  REAL   NOT NULL, -- Unix timestamp
    thumbnail   BLOB            -- optional page screenshot/OG image
);

-- Full-text search (keyword fallback)
CREATE VIRTUAL TABLE bookmarks_fts USING fts5(
    title, description, content='bookmarks', content_rowid='id'
);

-- Embedding vectors (one per chunk per bookmark)
CREATE TABLE bookmark_embeddings (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    bookmark_id INTEGER NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL, -- 0-based position in the page
    chunk_text  TEXT,              -- original text (for snippet display)
    embedding   BLOB   NOT NULL,  -- float32 array packed as bytes
    dimensions  INTEGER NOT NULL   -- vector length (e.g., 384)
);

CREATE INDEX idx_embedding_bookmark ON bookmark_embeddings(bookmark_id);

-- FTS triggers (keep in sync)
CREATE TRIGGER bookmarks_ai AFTER INSERT ON bookmarks BEGIN
    INSERT INTO bookmarks_fts(rowid, title, description)
    VALUES (new.id, new.title, new.description);
END;

CREATE TRIGGER bookmarks_ad AFTER DELETE ON bookmarks BEGIN
    INSERT INTO bookmarks_fts(bookmarks_fts, rowid, title, description)
    VALUES ('delete', old.id, old.title, old.description);
END;
```

### Vector Search in Pure SQLite

Without sqlite-vec extension, do brute-force cosine similarity in Swift:

```swift
// Load all embeddings once, cache in memory
// For <10k bookmarks this is instant
func search(query: String) async -> [BookmarkResult] {
    let queryEmbedding = try await embed(query)

    // Score each bookmark's chunks against query
    var scores: [(bookmarkID: Int, score: Float)] = []
    for (bookmarkID, chunks) in cachedEmbeddings {
        let maxScore = chunks.map { cosineSimilarity(queryEmbedding, $0) }.max() ?? 0
        scores.append((bookmarkID, maxScore))
    }

    // Combine with FTS5 keyword scores (hybrid search)
    let ftsResults = ftsSearch(query)
    return mergeAndRank(semantic: scores, keyword: ftsResults, topK: 20)
}
```

For thousands of bookmarks, brute-force cosine similarity over 384-dimensional vectors is sub-millisecond. No vector DB needed until you hit tens of thousands of entries.

---

## Embedding Model Options

### Option A: MLX via MLXEmbedders (Recommended)

**What**: Use Apple's [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) package, specifically the `MLXEmbedders` library.

**Model**: `all-MiniLM-L6-v2` (pre-registered in MLXEmbedders as `.minilm_l6`)

| Property | Value |
|---|---|
| Parameters | 22M |
| Size (4-bit quantized) | 12.8 MB |
| Embedding dimensions | 384 |
| Inference latency | ~5ms per query (Apple Silicon) |
| MTEB quality | Good (not best, but solid for bookmarks) |
| Memory footprint | ~90 MB (fp32), ~13 MB (4-bit) |

**How it works in Swift**:
```swift
import MLXEmbedders

// Load model (downloads from HuggingFace on first use, cached after)
let container = try await MLXEmbedders.loadModelContainer(
    configuration: .minilm_l6
)

// Generate embedding
let embedding: [Float] = try await container.perform { model, tokenizer, pooling in
    let tokens = tokenizer.encode(text: text, addSpecialTokens: true)
    let result = pooling(model(tokens), normalize: true, applyLayerNorm: true)
    result.eval()
    return result.asArray(Float.self)
}
```

**Pros**:
- Native Swift API, async/await, thread-safe
- Apple's strategic ML framework (heavy WWDC investment)
- Model downloads handled automatically
- 15 pre-registered embedding models to choose from
- Active development by Apple's ml-explore team

**Cons**:
- **Breaks zero-dependency rule** — adds mlx-swift-lm as SPM dependency
- SPM dependency chain: mlx-swift → mlx-swift-lm → tokenizers
- Model download on first use (~13 MB) requires network

**EmbeddingGemma status**: Available in MLX format on HuggingFace (`mlx-community/embeddinggemma-300m-bf16`), but not yet pre-registered in MLXEmbedders Swift library. Would need custom configuration. Larger (308M params, ~200MB quantized) but higher quality. Could be added later as an upgrade path.

---

### Option B: swift-embeddings (Lighter MLX Alternative)

**What**: [jkrukowski/swift-embeddings](https://github.com/jkrukowski/swift-embeddings) — uses Apple's `MLTensor` type instead of MLX directly. Thinner dependency chain.

**Supports**: all-MiniLM-L6-v2, nomic-embed models, BERT variants.

**Pros**:
- Lighter than full mlx-swift-lm
- Uses Apple's own MLTensor type
- Still downloads from HuggingFace

**Cons**:
- Smaller community, less active than MLX
- Fewer pre-registered models

---

### Option C: Apple NLContextualEmbedding (Zero Dependencies)

**What**: Apple's built-in `NaturalLanguage` framework includes [NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding) — a transformer model shipped with macOS 14+.

| Property | Value |
|---|---|
| Dimensions | 512 |
| Size | <100 MB (downloaded by OS on demand) |
| Token limit | 256 tokens per request |
| Quality | Good (Precision@1: 1.0, MRR: 0.83 in tests) |
| Languages | Three models: Latin, Cyrillic, CJK scripts |

**How it works**:
```swift
import NaturalLanguage

let embedding = NLContextualEmbedding(language: .english)
try await embedding.load()

let result = try embedding.embeddingResult(for: text, language: .english)
// Token-level embeddings — need to average/pool for sentence-level
let vector = result.enumerateTokenVectors(...)  // manual pooling
```

**Pros**:
- **Zero dependencies** — ships with macOS
- No model download (OS handles it)
- Uses Neural Engine natively

**Cons**:
- Token-level embeddings only (must manually pool to sentence-level)
- 256 token limit per call (need to chunk aggressively)
- Different script models produce incomparable vectors
- Less well-documented, fewer community examples
- Not benchmarked on MTEB, harder to compare quality

---

### Option D: VecturaKit (Batteries-Included)

**What**: [rryam/VecturaKit](https://github.com/rryam/VecturaKit) — a complete Swift vector database with built-in embedding support.

**Includes**: Vector storage, hybrid search (cosine similarity + BM25), supports three embedding backends (swift-embeddings, MLXEmbedders, NLContextualEmbedding).

**Pros**:
- Handles storage + search + embedding in one package
- Hybrid BM25 + vector search out of the box
- Pure Swift, macOS 14+

**Cons**:
- Adds a dependency (though it wraps Apple frameworks)
- Less control over the storage layer (Cove already has SQLite)
- Might duplicate existing Database.swift infrastructure

---

### Option E: Core ML (Manual Conversion)

**What**: Convert a PyTorch embedding model to CoreML format using `coremltools`, load with Apple's CoreML framework.

**Pros**:
- Zero runtime dependency (CoreML is built into macOS)
- Neural Engine acceleration
- Model compiled ahead of time

**Cons**:
- Requires Python toolchain to convert models (manual, fragile)
- No built-in tokenizer — must bundle or port one
- Rigid model format, harder to swap models
- Much more work than MLXEmbedders for the same result

---

## Recommendation

**Start with Option A (MLXEmbedders)** with `all-MiniLM-L6-v2`.

Rationale:
- 12.8 MB model, ~5ms inference — invisible to the user
- Clean Swift API that fits Cove's async/service architecture perfectly
- Apple's strategic direction (MLX is their PyTorch competitor)
- Pre-registered model = zero configuration
- If EmbeddingGemma gets added to MLXEmbedders, it's a one-line upgrade

The zero-dependency rule is worth bending for this. MLX is Apple's own framework — it's as "native" as a dependency gets. The alternative (NLContextualEmbedding) works but requires significantly more code for worse quality.

**Migration path**: Start with MiniLM → upgrade to EmbeddingGemma when MLXEmbedders adds it → benefit from Matryoshka dimensions (768→256 with minimal quality loss).

---

## Implementation Plan (when ready)

### Phase 1: Bookmark Foundation
1. `BookmarkStore` — SQLite CRUD following HistoryStore pattern
2. `bookmarks` table + `bookmarks_fts` virtual table
3. Basic bookmark UI (⌘D to save, sidebar/panel to browse)
4. Import from Safari/Chrome

### Phase 2: Content Extraction
5. JavaScript content extractor (Readability-style, injected into WKWebView)
6. Chunking logic (split long articles into ~200-word passages)
7. Store extracted text in `bookmark_embeddings.chunk_text`

### Phase 3: Semantic Layer
8. Add mlx-swift-lm SPM dependency
9. `EmbeddingService` — loads model, runs inference on background thread
10. `bookmark_embeddings` table with vector BLOBs
11. Embed all chunks at bookmark-save time (parallel with UI)
12. Background job to embed existing bookmarks

### Phase 4: Semantic Search
13. Hybrid search: cosine similarity + FTS5
14. Semantic search UI (search bar in bookmark panel)
15. "Similar bookmarks" feature (like MyMind's "Same Vibe")

### Phase 5: Auto-Organization (stretch)
16. Auto-tagging via LLM or clustering (UMAP + HDBSCAN)
17. Smart Collections (auto-grouped by theme)
18. Visual similarity for image bookmarks

---

## Service Architecture (fits existing patterns)

```
AppServices
  └─ existing services...
  └─ BookmarkStore           ← SQLite CRUD + FTS5
  └─ EmbeddingService        ← MLX model lifecycle + inference
  └─ SemanticBookmarkSearch   ← hybrid search orchestrator

TabSessionServices
  └─ existing services...
  └─ BookmarkStore (ref)     ← for quick ⌘D save

BookmarkStore
  ├─ add(url:title:content:) → async embed + store
  ├─ remove(id:)
  ├─ search(query:) → hybrid semantic + keyword results
  ├─ similar(bookmarkID:) → "same vibe" results
  └─ importFromSafari() / importFromChrome()

EmbeddingService
  ├─ loadModel()             ← background, on app launch
  ├─ embed(text:) → [Float]  ← single text → vector
  ├─ embedBatch(texts:)      ← bulk processing
  └─ isReady: Bool            ← model loaded?
```

---

## Open Questions

1. **When to extract content?** At bookmark time (slight delay) or async after? MyMind does it at save time.
2. **How much text to embed?** Full article vs. title+description only? Title+description is faster but less semantic. Full article is better but needs chunking.
3. **Model download UX** — show a "Setting up smart bookmarks..." one-time progress bar? Or silently download in background?
4. **Storage budget** — 384 floats × 4 bytes = 1.5 KB per chunk. 10 chunks × 5,000 bookmarks = 75 MB of embeddings. Acceptable?
5. **Incremental re-embedding** — if you switch models later, re-embed everything? Background migration?
6. **Privacy** — all local, but should there be a toggle to disable the semantic layer entirely?
