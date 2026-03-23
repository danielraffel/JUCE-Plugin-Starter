# Learnings — AI Style Designer

This file tracks important learnings during development.

## Phase 0
- Tauri 2 init: `cargo tauri init` creates src-tauri/ in the current directory
- frontendDist path is relative to src-tauri/, so `../../Tools` points to the existing Tools/ directory
- devUrl cannot be a relative file path — must be HTTP URL. Use frontendDist without devUrl for file:// serving
- `url` field in window config specifies which HTML file to load from frontendDist
- Tauri uses WebKit on macOS — no EyeDropper API. Could add native NSColorSampler via Tauri command later.
- Build takes ~30s first time due to Tauri dependency compilation, ~2s for incremental
