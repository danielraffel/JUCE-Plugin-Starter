"Fix the AI Style Designer chat so style changes VISUALLY UPDATE the preview and chat responses are human-readable. Continue on feature/ai-style-designer branch.

Follow phases in order. After each phase, verify in the Tauri app (pnpm tauri dev). Commit after each phase.

Key Files

- `Tools/theme-designer.html` — single-file frontend (all JS/CSS inline)
- `tauri/src-tauri/src/lib.rs` — Rust backend with chat_send IPC command
- `Tools/themes/default.stylesystem.json` — style system defaults
- `docs/ai-style-designer-chat-fix-spec.md` — full spec for all issues
- `tauri/docs/LEARNINGS.md` — accumulated learnings

Phase A: Make Style Changes Visually Work

This is the #1 blocker. Claude returns a JSON diff but nothing visually changes.

- [x] A.1 Audit which preview components are HTML vs canvas. Buttons, toggles, sliders, text inputs are HTML. Knobs are canvas.
- [x] A.2 Add CSS rules in the preview section that bind --st-* vars to visual properties. Example: `.preview-section .btn { border-radius: var(--st-button-rounding, 6px); }` and `.preview-section .toggle-track { width: var(--st-toggle-track-width, 36px); height: var(--st-toggle-track-height, 18px); border-radius: var(--st-toggle-track-rounding, 9px); }`
- [x] A.3 For each HTML component type (button, toggle, slider, text input, card, panel), ensure the CSS uses the matching --st-* var for border-radius, padding, width, height, font-size, box-shadow
- [x] A.4 Extend drawKnob() to use --st-knob-size for the overall size, and apply shadow if effects.shadows.enabled
- [x] A.5 Add CSS for box-shadow on preview components: `.preview-section [data-component] { box-shadow: var(--st-box-shadow, none); }`
- [x] A.6 Add CSS for typography: preview headings use --st-heading-size, labels use --st-label-size, body text uses --st-body-size
- [x] A.7 Test in browser (no Tauri): type "round" in chat input, verify mock agent applies rounded corners to buttons and toggles
- [x] A.8 Test in Tauri: run `pnpm tauri dev`, type "make it look like an 80s Macintosh" in chat, verify flat corners and no shadows
- [x] A.9 Commit Phase A

Phase B: Human-Readable Chat Responses

- [x] B.1 Update STYLE_SYSTEM_PROMPT in lib.rs: change "Return ONLY a valid JSON object" to "First write 1-2 sentences explaining what you're changing in conversational, designer-friendly language. Then output the JSON diff on a new line. Do not wrap in markdown code fences."
- [x] B.2 Update Rust parser: split response at first `{`, text before is explanation, `{...}` is diff JSON
- [x] B.3 Frontend: in send() response handler, show explanation text in chat bubble, show change summary (from summarizeChanges) in muted small text below
- [x] B.4 Test: send "warm analog synth" in Tauri, verify chat shows something like "I'll warm this up with rounded corners and soft shadows" not "geometry.button.cornerRadius: 16"
- [x] B.5 Commit Phase B

Phase C: Fix Image Attachment UX

- [x] C.1 Remove the line in file input handler that calls `this.addMessage('user', '[Image: ...]', imageDataUrl)` — images should NOT post to chat immediately
- [x] C.2 When an image is selected, show a small thumbnail (40x40) in the chat input area (next to the text input) with an "x" button to remove it
- [x] C.3 When user sends a message, include pendingImage with the prompt. After sending, clear the thumbnail from the input area.
- [x] C.4 Since claude --print doesn't support images: for now, add a note in the prompt saying "[User attached an image for reference]" but don't send actual image data. This is a v2 feature.
- [x] C.5 Commit Phase C

Phase D: Validate with Automated Testing

- [x] D.1 Verify tauri-plugin-webdriver starts: run `pnpm tauri dev` and check if localhost:4445 responds
- [x] D.2 Use mcp-tauri-automation to launch app and verify it loads
- [x] D.3 Use execute_script to test: set StyleSystem.current.geometry.button.cornerRadius = 20, call StyleSystem.applyToCSS(), read computed border-radius on a preview button, verify it's 20px
- [x] D.4 Use type_text + click_element to send "make it very rounded" in chat (requires real Claude), capture_screenshot to verify visual change
- [x] D.5 Document results in tauri/docs/LEARNINGS.md
- [x] D.6 Commit Phase D

EACH ITERATION MUST

1. Re-read `docs/ai-style-designer-chat-fix-spec.md` for context
2. Re-read `tauri/docs/LEARNINGS.md` for relevant prior learnings
3. Identify the NEXT incomplete item in sequential order
4. Implement it (and only it, unless trivial and closely related to the next item)
5. Verify the change works:
   - For Phase A: open in browser (file:// or pnpm tauri dev), use mock or real agent
   - For Phase B: run in Tauri with real Claude
   - For Phase C: visual check of image attachment UX
   - For Phase D: use mcp-tauri-automation tools
6. If anything interesting was learned, add to `tauri/docs/LEARNINGS.md`
7. Commit changes (if any)
8. Update this file: change `[ ]` to `[x]` for completed items

COMPLETION CONDITION

- All Phase A through Phase D items are checked off
- Style changes from Claude visually update the preview (buttons round, knobs change, shadows appear/disappear)
- Chat responses are human-readable (not raw JSON property lists)
- Image upload attaches to next message (doesn't post immediately)
- At least one automated test verifies a style change applied
- Code builds successfully: `cd tauri && pnpm tauri build`
- All changes committed on feature/ai-style-designer branch

IF STUCK

After 10 iterations on the same item, document in `tauri/docs/LEARNINGS.md`:
- What is blocked
- Why
- What was attempted
- What assumption may be wrong

Success Criteria

1. Type "warm analog synth" -> preview shows rounded knobs, subtle shadows, warm feel
2. Type "80s Macintosh" -> preview goes flat, sharp corners, no shadows
3. Chat shows conversational explanation, not property dumps
4. Image attaches as thumbnail in input area, not posted as separate message
5. At least one automated test proves style changes apply

ONLY WHEN ALL CONDITIONS ARE MET:
Output exactly: DONE" --completion-promise "DONE" --max-iterations 120
