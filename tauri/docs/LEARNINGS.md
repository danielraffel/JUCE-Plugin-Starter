# Learnings — AI Style Designer

This file tracks important learnings during development.

## Phase 0
- Tauri 2 init: `cargo tauri init` creates src-tauri/ in the current directory
- frontendDist path is relative to src-tauri/, so `../../Tools` points to the existing Tools/ directory
- devUrl cannot be a relative file path — must be HTTP URL. Use frontendDist without devUrl for file:// serving
- `url` field in window config specifies which HTML file to load from frontendDist
- Tauri uses WebKit on macOS — no EyeDropper API. Could add native NSColorSampler via Tauri command later.
- Build takes ~30s first time due to Tauri dependency compilation, ~2s for incremental

## Phase 1
- CSS custom properties with fallbacks (e.g., `var(--st-button-rounding, 6px)`) let the preview work even without style system loaded
- Canvas components can read CSS vars via getComputedStyle + parseFloat
- Style system JSON embedded in HTML alongside theme data works for file:// compat

## Phase 2
- Chat UI as a tab alongside Inspector works well — user can switch between inspecting tokens and chatting
- Inspector selection context flows to chat via ChatUI.updateContext()
- textarea with rows=1 and max-height creates a compact single-line input that can expand

## Phase 3
- Tauri IPC with serde_json works cleanly for passing complex payloads
- Node.js sidecar spawned via std::process::Command is simplest approach for Claude Code SDK
- Mock agent in browser mode is essential for testing without Tauri
- Deep merge for style diffs: recursive object merge preserves existing properties not in the diff
- `camel_to_snake` regex: use two-pass regex for proper camelCase conversion (e.g., cornerRadius → corner_radius)
