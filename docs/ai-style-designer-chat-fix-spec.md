# AI Style Designer — Chat Fix Spec

## Current State

The Tauri app launches, the theme designer loads, and the chat panel successfully communicates with Claude via the `claude` CLI. However, 6 critical issues prevent the chat from being usable.

## Issue 1: Style Changes Don't Visually Update the Preview

**Symptom**: Claude returns a valid JSON diff (e.g., `geometry.knob.arcWidth: 8`), the diff merges into `StyleSystem.current`, CSS vars get set on `#preview-area`, `CanvasRenderer.scheduleRedraw()` runs — but knobs, buttons, toggles don't visually change.

**Root Causes**:

1. **Missing `px` suffix on some CSS vars**: `applyToCSS()` sets `--st-knob-arc-width` to a raw number (e.g., `6`) without `px`, but `drawKnob()` reads it via `parseFloat(getPropertyValue('--st-knob-arc-width'))`. This part actually works because `parseFloat` strips units. However, some values like `size` need `px` for CSS consumption. The real issue is that most preview components are **HTML elements styled with CSS**, not canvas-drawn, so they need CSS vars with proper units to change.

2. **Canvas components only read 2 vars**: `drawKnob()` only reads `--st-knob-arc-width` and `--st-knob-thumb-size`. Changes to `shadows`, `bloom`, `gradients`, `cornerRadius`, `borderWidth` have ZERO visual effect on canvas knobs. Buttons, toggles, sliders, and text inputs are pure HTML — they need CSS rules that reference `--st-*` vars, but many are missing.

3. **HTML components missing CSS var bindings**: The preview buttons, toggles, sliders, and text inputs don't have CSS rules that use `--st-button-rounding`, `--st-toggle-track-width`, etc. The vars are set but nothing reads them.

**Fix**:
- Add CSS rules in the preview section that bind `--st-*` vars to actual visual properties (border-radius, width, height, padding, box-shadow, font-size)
- Extend `drawKnob()` to use more style vars (shadow, gradient, border)
- Add a `drawButton()` or style-button approach for DOM-based components
- After `applyToCSS()`, force style recalc on all preview components
- Test with a known diff like `{geometry:{button:{cornerRadius:20}}}` and verify the button visually rounds

## Issue 2: Chat Response Shows Raw Property Lists Instead of Human-Readable Explanation

**Symptom**: Claude's response shows up as a raw list of property changes like `"geometry.knob.arcWidth: 8, effects.shadows.blur: 12..."` instead of a natural language explanation like "I've given the knobs a thicker arc and added subtle shadows for depth."

**Root Cause**: The system prompt in `lib.rs` says "Return ONLY a valid JSON object" — Claude obeys and returns just JSON. The Rust parser then classifies everything before the `{` as "explanation" — but there's nothing before the `{` because Claude was told to return ONLY JSON.

**Fix**:
- Change the system prompt to: "First write a brief, conversational explanation of what you're changing and why (1-2 sentences, written for a designer not a developer). Then on a new line output the JSON diff."
- In the Rust parser, split on the first `{` — everything before is the human message, everything from `{` to the matching `}` is the diff
- In the frontend, show the human message in the chat bubble, and show the change summary below it in a muted style
- If Claude returns no explanation (just JSON), use the auto-generated summary as fallback

## Issue 3: Image Upload Doesn't Reach Claude

**Symptom**: Two problems: (a) `claude --print` doesn't accept image inputs, and (b) the frontend posts the image to chat history immediately instead of attaching it to the next text message.

**Root Cause**:
- The `claude` CLI's `--print` mode is text-only. It doesn't support `--image` or base64 image inputs.
- The file input handler calls `this.addMessage('user', '[Image: file.name]', imageDataUrl)` immediately, creating a separate message instead of holding the image for the next send.

**Fix — Image Attachment UX**:
- Don't post the image as a message. Instead, show a small thumbnail in the input area (like Assembly does) indicating an image is "attached"
- Add an "x" button on the thumbnail to remove the attachment
- When the user types text and sends, include both text and image
- Clear the attachment after sending

**Fix — Image Delivery to Claude**:
- Option A (simpler): Write the image to a temp file, pass it via `claude` CLI's stdin or a temp file reference. Check if `claude --print` supports `--file` or similar flags.
- Option B (if CLI can't do images): Switch to spawning `claude` in conversation mode with a temp file, or use the Claude API directly via a small Node.js helper that reads `~/.claude/` auth.
- Option C (pragmatic): For v1, disable image upload and focus on text prompts. Add image support in v2 when the Agent SDK or CLI adds image support.

**Recommendation**: Option C for now. Hide the image upload button or show "Coming soon" tooltip. Text-only prompts cover 90% of use cases.

## Issue 4: Automated Testing to Verify Visual Changes

**Current State**: `tauri-plugin-webdriver` is already wired in `Cargo.toml` and `lib.rs` for debug builds. The `mcp-tauri-automation` MCP is available.

**What's Needed**:
- Verify the WebDriver server actually starts when the app launches in debug mode
- Use `mcp-tauri-automation` to: launch app, send a chat message, capture screenshot before/after, verify visual difference
- Key test: send "make buttons very rounded" -> verify `border-radius` on preview buttons changed
- Key test: send "make knob arcs thicker" -> verify canvas knob arc width changed

**Approach**:
- Manual validation first: launch `pnpm tauri dev`, check if port 4445 responds
- Then use `mcp-tauri-automation` tools to automate: `launch_app`, `type_text` in chat input, `click_element` send button, `capture_screenshot`, `execute_script` to read computed styles

## Issue 5: Image Upload UX is Wrong

(Covered in Issue 3 fix above — the UX fix is: attach to next message, don't post immediately)

## Issue 6: Settings Panel (from Assembly Reference)

**Current State**: No settings panel exists. Model selection is in the chat header dropdown.

**What's Needed** (low priority):
- Gear icon that opens a settings panel
- Shows: Claude CLI version, auth status, selected model
- "Test Connection" button
- This is polish — defer until core functionality works

## Implementation Phases

### Phase A: Make Style Changes Visually Work (CRITICAL)

1. Add CSS rules in `.preview-section` that use `--st-*` vars for all HTML components
2. Extend canvas `drawKnob()` to read more style vars
3. Test with mock agent in browser (no Tauri needed) — type "round" and verify buttons round
4. Test with real Claude in Tauri — type "make it look like an 80s Macintosh" and verify flat corners, no shadows
5. Verify `CanvasRenderer.scheduleRedraw()` actually triggers after diff is applied

### Phase B: Human-Readable Chat Responses

1. Update system prompt in `lib.rs` to request explanation + JSON
2. Update Rust parser to split explanation from JSON diff
3. Frontend: render explanation as chat text, summary as muted detail
4. Test that conversational responses appear in chat

### Phase C: Fix Image Attachment UX

1. Remove immediate posting of image to chat
2. Show thumbnail in input area with "x" to remove
3. Send image data with next text message
4. For v1: disable actual image delivery to Claude (text-only), show "Image reference attached" in the prompt context

### Phase D: Automated Testing

1. Verify WebDriver starts on port 4445 in dev mode
2. Write manual test script using mcp-tauri-automation
3. Automate: send prompt -> verify style change -> screenshot

## Success Criteria

1. Type "warm analog synth" -> buttons get rounded corners, knobs get thicker arcs, shadows appear
2. Type "80s Macintosh" -> corners go sharp (0px), shadows disabled, clean flat look
3. Chat shows "I'll give this a warm analog feel with rounded corners and soft shadows" NOT "geometry.button.cornerRadius: 16, effects.shadows.enabled: true"
4. Image attachment shows as thumbnail in input bar, not as a separate message
5. Clicking a chat thumbnail restores that visual state
