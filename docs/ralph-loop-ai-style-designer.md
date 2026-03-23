# Ralph Loop: AI-Powered Aesthetic Style Designer

## Branch

`feature/ai-style-designer` (already created from `feature/theme-designer` at v0.1)

## Task

Build an AI-powered aesthetic style designer that extends the v0.1 color theme designer. Users describe visual styles in natural language via a chat box, and the component showcase updates live. Uses Claude Code Agent SDK with existing Max account auth in a Tauri 2 app.

Follow phases in order. After each phase, open the HTML to test. Commit after each phase.

## Key Files

- `Tools/theme-designer.html` — existing theme designer (4100+ lines, vanilla JS/CSS)
- `Tools/themes/default.json` — existing color system tokens
- `scripts/generate_theme.py` — existing C++ codegen
- `docs/ai-style-designer-spec.md` — full feature spec
- `/Users/danielraffel/Code/Assembly/docs/proposal/` — Tauri 2 architecture reference
- `/Users/danielraffel/Code/visage/` — Visage framework (style properties reference)

## Phase 0: Scaffold

- [ ] Create `tauri/` directory for the Tauri app
- [ ] Create `tauri/CLAUDE.md` with project conventions
- [ ] Create `tauri/docs/proposal/work-items.md` with all work items from Phases 0-3
- [ ] Create `tauri/docs/LEARNINGS.md` (empty initially)
- [ ] Init Tauri 2 project: `pnpm create tauri-app` with vanilla frontend
- [ ] Copy `Tools/theme-designer.html` as the Tauri frontend source
- [ ] Verify `pnpm install && pnpm tauri dev` opens the theme designer in a Tauri window
- [ ] Commit scaffold

## Phase 1: Style System JSON Format

- [ ] Create `Tools/themes/default.stylesystem.json` extending color system with:
  - `geometry` section (cornerRadius, borderWidth, shadowBlur, knob/button/toggle/slider/textInput specific)
  - `effects` section (bloom, shadows)
  - `gradients` section (buttonGradient, knobGradient)
  - `typography` section (headingSize, bodySize, labelSize, fontWeight)
- [ ] Add CSS custom properties to theme-designer.html: `--st-knob-arc-width`, `--st-button-rounding`, `--st-toggle-rounding`, etc.
- [ ] Preview components read geometry vars: canvas knobs use `--st-knob-arc-width`, buttons use `--st-button-rounding`, etc.
- [ ] Style system embedded in HTML as `<script id="style-system-data">` (like theme-data)
- [ ] Export panel adds "Style System" tab outputting full .stylesystem.json
- [ ] Commit

## Phase 2: Chat UI

- [ ] Add chat panel to right side of theme designer (tab: Inspector | Chat)
- [ ] Chat has: message list, text input with placeholder, send button, image upload button
- [ ] Messages: user prompts right-aligned, agent responses left-aligned, in rounded bubbles
- [ ] Show "Editing: [component]" or "Editing: All" based on inspector selection
- [ ] Image upload converts to base64, shows thumbnail in chat
- [ ] Loading/typing indicator animation while agent processes
- [ ] Chat history stored in memory (persists during session)
- [ ] "Export current" button visible in chat header
- [ ] Commit

## Phase 3: Tauri Backend + Claude Agent

- [ ] Add Rust backend with Tauri IPC commands:
  - `chat_send(prompt, style_json, selected_component, image_base64)` → streams response
  - `chat_health()` → checks if agent is available
- [ ] Node.js sidecar using `@anthropic-ai/claude-code` Agent SDK:
  - Receives prompt + current style JSON + component context + optional image
  - System prompt teaches Claude about the style system format
  - Returns JSON diff of changed properties
  - Streams response via Tauri events
- [ ] Frontend receives streamed agent response, parses JSON diff
- [ ] Apply diff to current style system: merge changes, update CSS vars, redraw canvases
- [ ] Flash changed components in preview
- [ ] Auto-capture preview thumbnail after each style change (canvas.toDataURL)
- [ ] Display thumbnail in chat inline below agent response, clickable to restore
- [ ] Chat history with thumbnails = version history (click any to restore that state)
- [ ] Commit

## Phase 3b: Inspector-Scoped Prompts

- [ ] When component is Cmd+clicked, chat context includes component name and current style props
- [ ] Agent system prompt updated: "User selected [Component]. Only modify that component's properties."
- [ ] UI shows "Editing: Rotary Knob" badge in chat header
- [ ] No selection = "Editing: All Components"
- [ ] Commit

## Phase 3c: Extended Export

- [ ] `.stylesystem.json` export includes all sections (colors + geometry + effects + gradients + typography)
- [ ] Update `scripts/generate_theme.py` to read geometry/effects sections
- [ ] Generate Visage C++ code for widget construction params, post-effect setup, layout config
- [ ] Update juce-dev skill (`skills/visage-theme/SKILL.md`) with style system knowledge
- [ ] Commit

## CODEX DELEGATION (OPTIONAL)

- Use `/codex <task>` or `codex exec --full-auto <task>` for parallel work when it would speed things up.
- Good candidates for Codex delegation:
  - Writing tests for code you just wrote
  - Implementing a component while you work on another
  - Code review of completed work items
  - Extracting utilities into shared modules
- Do NOT delegate to Codex when:
  - The task depends on something you are currently building
  - Multiple agents would edit the same file
  - The task requires your current conversation context
- When delegating, run Codex in background and continue your own work.
- Check Codex output before marking the work item complete.

## EACH ITERATION MUST

1. Re-read `tauri/CLAUDE.md` (create if missing)
2. Re-read `tauri/docs/proposal/work-items.md`
3. Check `tauri/docs/LEARNINGS.md` for relevant prior learnings
4. Identify the NEXT incomplete item in sequential order
5. Implement it (and only it, unless it's trivial and the next item is closely related)
6. Write E2E tests for newly implemented features (if applicable)
7. Verify code compiles (`pnpm install && pnpm build` in `tauri/`)
8. Run tests if applicable (`pnpm test && pnpm test:e2e`)
9. If anything interesting was learned, add to `LEARNINGS.md`
10. Commit changes (if any)
11. Update `work-items.md` status
12. Re-check which items remain

## COMPLETION CONDITION

- `tauri/docs/proposal/work-items.md` contains ZERO unimplemented Phase 0 through Phase 3 items
- All Phase 0, Phase 1, Phase 2, and Phase 3 features are fully implemented and verified
- Code builds successfully (`pnpm tauri build`)
- Unit tests pass (`pnpm test`)
- E2E tests pass (`pnpm test:e2e`)
- Code and commit history comply with `tauri/CLAUDE.md`
- `tauri/docs/LEARNINGS.md` has been maintained throughout

## IF STUCK

After 20 iterations, document in `LEARNINGS.md`:
- What is blocked
- Why
- What was attempted
- What assumption may be wrong

## Success Criteria

1. Type "warm analog synth" → preview updates with rounded knobs, subtle shadows, warm palette
2. Cmd+click knob → type "more skeuomorphic" → only knobs change
3. Upload screenshot → type "like this" → preview approximates style
4. Click any chat thumbnail → restores that version
5. Export .stylesystem.json → includes geometry + effects + colors
6. No API key needed — uses Claude Code auth
7. Tauri app builds cross-platform

ONLY WHEN ALL CONDITIONS ARE MET:
Output exactly: DONE

--completion-promise "DONE" --max-iterations 120
