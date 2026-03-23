# Work Items — AI Style Designer

## Phase 0: Scaffold
- [ ] 0.1 Create tauri/ directory structure
- [ ] 0.2 Create tauri/CLAUDE.md with project conventions
- [ ] 0.3 Create tauri/docs/proposal/work-items.md (this file)
- [ ] 0.4 Create tauri/docs/LEARNINGS.md
- [ ] 0.5 Initialize Tauri 2 project with vanilla frontend
- [ ] 0.6 Copy/adapt Tools/theme-designer.html as Tauri frontend
- [ ] 0.7 Verify pnpm install and pnpm tauri dev opens theme designer
- [ ] 0.8 Commit scaffold

## Phase 1: Style System JSON Format
- [ ] 1.1 Create Tools/themes/default.stylesystem.json with geometry, effects, gradients, typography sections
- [ ] 1.2 Add CSS custom properties (--st-*) to theme-designer.html for geometry/style tokens
- [ ] 1.3 Canvas knobs read --st-knob-arc-width for arc thickness
- [ ] 1.4 Buttons read --st-button-rounding for border-radius
- [ ] 1.5 Toggles, sliders, text inputs read their respective --st-* vars
- [ ] 1.6 Embed style system in HTML via <script id="style-system-data">
- [ ] 1.7 Export panel adds Style System tab
- [ ] 1.8 Commit Phase 1

## Phase 2: Chat UI
- [ ] 2.1 Add tab switcher: Inspector | Chat in right panel
- [ ] 2.2 Chat panel with message list, text input, send button
- [ ] 2.3 Image upload button with base64 conversion and thumbnail preview
- [ ] 2.4 User messages right-aligned, agent messages left-aligned, rounded bubbles
- [ ] 2.5 Show "Editing: [component]" or "Editing: All" based on inspector selection
- [ ] 2.6 Loading/typing indicator animation
- [ ] 2.7 Chat history persists during session (in memory)
- [ ] 2.8 "Export current" button in chat header
- [ ] 2.9 Commit Phase 2

## Phase 3: Tauri Backend + Claude Agent
- [ ] 3.1 Rust backend: chat_send IPC command (accepts prompt, style_json, selected_component, image_base64)
- [ ] 3.2 Rust backend: chat_health IPC command
- [ ] 3.3 Node.js sidecar package.json with @anthropic-ai/claude-code dependency
- [ ] 3.4 Node.js sidecar agent.mjs: receives prompt + context, calls Claude Code SDK, returns JSON diff
- [ ] 3.5 System prompt teaching Claude about the style system format
- [ ] 3.6 Rust spawns Node.js sidecar, pipes IPC to/from it
- [ ] 3.7 Frontend: send chat message via Tauri invoke, receive streamed response
- [ ] 3.8 Frontend: parse JSON diff from agent response
- [ ] 3.9 Frontend: apply diff to style system (merge, update CSS vars, redraw)
- [ ] 3.10 Frontend: flash changed components in preview
- [ ] 3.11 Frontend: auto-capture preview thumbnail (canvas.toDataURL) after style change
- [ ] 3.12 Frontend: display thumbnail inline in chat, clickable to restore that state
- [ ] 3.13 Commit Phase 3

## Phase 3b: Inspector-Scoped Prompts
- [ ] 3b.1 When component Cmd+clicked, include name + current style props in chat context
- [ ] 3b.2 Agent system prompt updated for selected component scoping
- [ ] 3b.3 UI shows "Editing: Rotary Knob" badge in chat header
- [ ] 3b.4 No selection = "Editing: All Components"
- [ ] 3b.5 Commit Phase 3b

## Phase 3c: Extended Export
- [ ] 3c.1 .stylesystem.json export includes all sections
- [ ] 3c.2 Update generate_theme.py to read geometry/effects sections
- [ ] 3c.3 Generate Visage C++ code for widget params, post-effects, layout
- [ ] 3c.4 Update visage-theme skill documentation with style system knowledge
- [ ] 3c.5 Commit Phase 3c
