# Work Items — AI Style Designer

## Phase 0: Scaffold
- [x] 0.1 Create tauri/ directory structure
- [x] 0 Create tauri/CLAUDE.md with project conventions
- [x] 0 Create tauri/docs/proposal/work-items.md (this file)
- [x] 0 Create tauri/docs/LEARNINGS.md
- [x] 0 Initialize Tauri 2 project with vanilla frontend
- [x] 0 Copy/adapt Tools/theme-designer.html as Tauri frontend
- [x] 0 Verify pnpm install and pnpm tauri dev opens theme designer
- [x] 0 Commit scaffold

## Phase 1: Style System JSON Format
- [x] 1.1 Create Tools/themes/default.stylesystem.json with geometry, effects, gradients, typography sections
- [x] 1.2 Add CSS custom properties (--st-*) to theme-designer.html for geometry/style tokens
- [x] 1.3 Canvas knobs read --st-knob-arc-width for arc thickness
- [x] 1.4 Buttons read --st-button-rounding for border-radius
- [x] 1.5 Toggles, sliders, text inputs read their respective --st-* vars
- [x] 1.6 Embed style system in HTML via <script id="style-system-data">
- [x] 1.7 Export panel adds Style System tab
- [x] 1.8 Commit Phase 1

## Phase 2: Chat UI
- [x] 2.1 Add tab switcher: Inspector | Chat in right panel
- [x] 2.2 Chat panel with message list, text input, send button
- [x] 2.3 Image upload button with base64 conversion and thumbnail preview
- [x] 2.4 User messages right-aligned, agent messages left-aligned, rounded bubbles
- [x] 2.5 Show "Editing: [component]" or "Editing: All" based on inspector selection
- [x] 2.6 Loading/typing indicator animation
- [x] 2.7 Chat history persists during session (in memory)
- [x] 2.8 "Export current" button in chat header
- [x] 2.9 Commit Phase 2

## Phase 3: Tauri Backend + Claude Agent
- [x] 3.1 Rust backend: chat_send IPC command (accepts prompt, style_json, selected_component, image_base64)
- [x] 3.2 Rust backend: chat_health IPC command
- [x] 3.3 Node.js sidecar package.json with @anthropic-ai/claude-code dependency
- [x] 3.4 Node.js sidecar agent.mjs: receives prompt + context, calls Claude Code SDK, returns JSON diff
- [x] 3.5 System prompt teaching Claude about the style system format
- [x] 3.6 Rust spawns Node.js sidecar, pipes IPC to/from it
- [x] 3.7 Frontend: send chat message via Tauri invoke, receive streamed response
- [x] 3.8 Frontend: parse JSON diff from agent response
- [x] 3.9 Frontend: apply diff to style system (merge, update CSS vars, redraw)
- [x] 3.10 Frontend: flash changed components in preview
- [x] 3.11 Frontend: auto-capture preview thumbnail (canvas.toDataURL) after style change
- [x] 3.12 Frontend: display thumbnail inline in chat, clickable to restore that state
- [x] 3.13 Commit Phase 3

## Phase 3b: Inspector-Scoped Prompts
- [x] 3b.1 When component Cmd+clicked, include name + current style props in chat context
- [x] 3b.2 Agent system prompt updated for selected component scoping
- [x] 3b.3 UI shows "Editing: Rotary Knob" badge in chat header
- [x] 3b.4 No selection = "Editing: All Components"
- [x] 3b.5 Commit Phase 3b

## Phase 3c: Extended Export
- [x] 3c.1 .stylesystem.json export includes all sections
- [x] 3c.2 Update generate_theme.py to read geometry/effects sections
- [x] 3c.3 Generate Visage C++ code for widget params, post-effects, layout
- [x] 3c.4 Update visage-theme skill documentation with style system knowledge
- [x] 3c.5 Commit Phase 3c

## Phase 4: Real Agent Connection (claude CLI, Max subscription)
- [x] 4.1 Verify claude CLI from Rust: spawn "claude --version"
- [x] 4.2 Add model dropdown to chat header: Opus 4.6 (default) / Sonnet 4.6
- [x] 4.3 Rust chat_send: spawn claude CLI directly, stream NDJSON, emit Tauri events
- [x] 4.4 Frontend: listen for Tauri events, accumulate response, extract JSON diff, apply
- [x] 4.5 Settings: CLI status check, model selection
- [x] 4.6 Error handling: CLI not found, timeout, parse failure
- [x] 4.7 Commit Phase 4

## Phase 5: Testing
- [x] 5.1 Add tauri-plugin-webdriver or automation setup
- [x] 5.2 Configure automation mode in tauri.conf.json
- [x] 5.3 Write E2E tests (app launch, chat, model select, context, export)
- [x] 5.4 Commit Phase 5

## Phase 6: Polish
- [x] 6.1 Parse agent response: separate explanation from JSON diff
- [x] 6.2 Show change summary in chat
- [x] 6.3 Capture real preview thumbnail after style change
- [x] 6.4 Thumbnails clickable to restore state
- [x] 6.5 A/B compare between thumbnail versions
- [x] 6.6 Commit Phase 6
