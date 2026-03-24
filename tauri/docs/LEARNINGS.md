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

## Phase A (Chat Fix)
- ROOT CAUSE of style changes not visually applying: inline `style="border-radius:var(--app-radius)"` on buttons, inputs, dropdowns OVERRIDES the CSS class rules that use `--st-button-rounding` etc. Inline styles have higher specificity than class selectors.
- Fix: remove inline border-radius from HTML elements, let the CSS class rules (which already reference `--st-*` vars) take effect.
- The CSS class rules for `.preview-btn`, `.toggle-track`, `.preview-slider`, `.preview-input` already used `--st-*` vars correctly — the problem was only the inline overrides.
- Cards and panels needed updating from `--app-radius` to `--st-corner-radius` in CSS rules.
- Toggle `.on` thumb position was hardcoded to `left: 16px` — needs `calc()` to track dynamic width.
- `drawKnob()` now reads `--st-knob-size` for dynamic sizing and applies canvas shadow when `--st-shadow-alpha > 0`.
- The BIGGEST factor in visual quality is including COLOR TOKENS in the system prompt. Without them, Claude can only tweak geometry (subtle). With all 36+ color tokens listed, Claude changes backgrounds, accents, text — producing dramatic transformations (126 properties for "80s Macintosh").
- The system prompt needs concrete full examples (like the 80s Mac example with 30+ color values) to teach Claude the expected diff format and ambition level.
- `buildFullContext()` sends both current color tokens AND style system to Claude so it can see what it's working with.
- WebDriver plugin uses port 4445 by default, but mcp-tauri-automation expects 4444. Set `TAURI_WEBDRIVER_PORT=4444` env var when launching.
- Automated tests via `execute_script` work well: set a StyleSystem property, call applyToCSS(), read getComputedStyle() — confirms the pipeline end-to-end.
- Raw string literals containing `"#` sequences need `r##"..."##` (two hashes) in Rust since `"#` terminates `r#"..."#`.
