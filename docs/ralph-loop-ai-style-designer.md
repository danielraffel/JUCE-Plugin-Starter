# Ralph Loop: AI-Powered Aesthetic Style Designer

## Branch Setup

Create branch `feature/ai-style-designer` from tag v0.1 on `feature/theme-designer`.

## Task

Build an AI-powered aesthetic style designer that extends the v0.1 color theme designer. Users describe visual styles in natural language via a chat box, and the component showcase updates live. Uses Claude Code Agent SDK with existing Max account auth.

Follow phases in order. After each phase, open the HTML to test. Commit after each phase.

## Phase 1: Style System JSON Format

Extend the existing color system with geometry, effects, gradients, and typography sections.

**File: Tools/themes/default.stylesystem.json**

Add these sections alongside the existing colorSystem:

```json
{
  "geometry": {
    "global": { "cornerRadius": 6, "borderWidth": 1, "shadowBlur": 8, "shadowOffsetY": 4 },
    "knob": { "arcWidth": 4, "arcStyle": "rounded", "thumbSize": 4 },
    "button": { "cornerRadius": 6, "borderWidth": 0, "paddingX": 14, "paddingY": 6 },
    "toggle": { "trackWidth": 32, "trackHeight": 18, "trackRounding": 9, "thumbSize": 14 },
    "slider": { "trackHeight": 6, "trackRounding": 3, "thumbSize": 14 },
    "textInput": { "cornerRadius": 6, "borderWidth": 1, "paddingX": 8, "paddingY": 6 }
  },
  "effects": {
    "bloom": { "enabled": false, "size": 0, "intensity": 0 },
    "shadows": { "enabled": true, "blur": 8, "offsetX": 0, "offsetY": 4, "alpha": 0.4 }
  },
  "gradients": {
    "buttonGradient": { "enabled": false, "type": "linear", "angle": 180, "stops": [] },
    "knobGradient": { "enabled": false, "type": "radial", "stops": [] }
  },
  "typography": {
    "headingSize": 16, "bodySize": 13, "labelSize": 10, "fontWeight": "normal"
  }
}
```

Update `Tools/theme-designer.html`:
- Add CSS custom properties for geometry: `--st-knob-arc-width`, `--st-button-rounding`, etc.
- Preview components read geometry vars alongside color vars
- Canvas knobs use `--st-knob-arc-width` for arc thickness
- Buttons use `--st-button-rounding` for border-radius
- Toggles use `--st-toggle-track-rounding`
- Export panel adds "Style System" tab

## Phase 2: Chat UI

Add a chat panel to the right side of the theme designer.

**In the HTML:**
- Replace or add alongside the inspector panel
- Toggle between Inspector and Chat views with tabs
- Chat has: message list, text input, send button, image upload button
- Messages show: user prompts (right-aligned), agent responses (left-aligned)
- Show "Editing: [component name]" or "Editing: All" based on inspector selection
- Image upload converts to base64 for sending to agent
- Loading indicator while agent processes

**CSS:**
- Chat messages styled like a modern chat (rounded bubbles, subtle backgrounds)
- Image previews shown inline
- Typing indicator animation

## Phase 3: Tauri App with Agent Backend

Create a Tauri 2 app that bundles the theme designer as frontend and runs the Claude Code Agent SDK in a sidecar Node.js process (or directly in Rust via the Anthropic API).

**Architecture:**
```
┌─────────────────────────────────┐
│ Tauri App (single binary)       │
│                                 │
│ Frontend: theme-designer.html   │
│   ↕ Tauri IPC (invoke/events)   │
│ Backend: Rust + Node.js sidecar │
│   ↕ Claude Code Agent SDK      │
│   ↕ Uses Max account auth      │
└─────────────────────────────────┘
```

**Scaffold:** Use the Assembly proposal at `/Users/danielraffel/Code/Assembly/docs/proposal/` as reference for Tauri 2 + React setup. But our frontend is the existing vanilla HTML theme designer (not React).

Create `apps/desktop/` with:

```javascript
import { query } from '@anthropic-ai/claude-code';
import { createServer } from 'http';

const PORT = 3847;

const SYSTEM_PROMPT = `You are an aesthetic style designer for audio plugin UIs.
You receive the current style system JSON and modify it based on the user's request.
Return ONLY a JSON object with the changed properties (a diff, not the full style).
The style system has sections: colorSystem, geometry, effects, gradients, typography.
When the user describes an aesthetic ("80s Macintosh", "neon cyberpunk", "warm analog"),
translate that into specific property changes across all sections.
If a component is selected, only change properties relevant to that component.`;

createServer(async (req, res) => {
  if (req.method === 'POST' && req.url === '/chat') {
    // Parse body, call Claude Code Agent SDK, stream response
    // ...
  }
  if (req.method === 'GET' && req.url === '/health') {
    res.end('ok');
  }
}).listen(PORT);
```

**In the HTML:**
- Chat send button POSTs to `http://localhost:3847/chat`
- Body: `{ prompt, styleJSON, selectedComponent, image }`
- Response: SSE stream of agent messages
- Parse final JSON diff from agent response
- Apply diff to current style system
- Update preview live

**Startup:** User runs `node tools/style-agent-server.mjs` before using chat.
Or: add a "Start Agent" button in the UI that checks if server is running.

## Phase 4: Style Application Engine

When the agent returns a style diff JSON:
1. Merge diff into current style system
2. Apply color changes via existing CSSBridge
3. Apply geometry changes to CSS custom properties
4. Canvas components re-read geometry vars on redraw
5. Apply effect changes (shadow CSS, bloom approximation)
6. Apply typography changes
7. Flash changed components
8. Save to undo history

## Phase 5: Version History

- Save named style variations: `{ name, prompt, styleJSON, timestamp }`
- Dropdown to switch between variations
- Compare two variations side-by-side (extend A/B compare)
- Each variation preserves the prompt that created it
- "Fork" button to create a new variation from the current state
- Variations stored in localStorage and exportable as .stylesystem.json

## Phase 6: Inspector-Scoped Prompts

When a component is Cmd+clicked:
- Chat context includes: component name, type, framework, current style properties
- Agent system prompt updated: "The user has selected [Component]. Only modify properties for this component type."
- Response diff is scoped to that component's properties
- UI shows "Editing: Rotary Knob" badge in chat header

When no component is selected:
- Agent applies changes globally
- UI shows "Editing: All Components"

## Phase 7: Stitch Integration (Optional)

- "Preview with Stitch" button in chat
- Sends current style description to Stitch SDK
- Stitch generates a mockup image
- Image displayed in chat as a reference
- User can say "apply this" to derive style from the Stitch output

## Phase 8: Extended Export

- `.stylesystem.json` includes all sections (colors + geometry + effects + gradients + typography)
- Update `scripts/generate_theme.py` to read geometry/effects and generate C++ code for:
  - Visage widget construction parameters
  - Post-effect setup code
  - Layout configuration
- Update juce-dev skill with style system knowledge
- Claude Code's `/juce-dev:theme --apply` can read .stylesystem.json

## Files to Create/Modify

| File | Action |
|------|--------|
| `tools/style-agent-server.mjs` | Create — local Claude agent server |
| `tools/theme-designer.html` | Modify — add chat UI, geometry CSS vars, style application |
| `tools/themes/default.stylesystem.json` | Create — full style system with geometry/effects |
| `scripts/generate_theme.py` | Modify — handle geometry/effects in codegen |
| `docs/ai-style-designer-spec.md` | Reference — full spec |

## Implementation Order for Ralph Loop

1. Phase 1: Style system JSON + geometry CSS vars in preview
2. Phase 2: Chat UI panel with message list and input
3. Phase 3: Local agent server with Claude Code SDK
4. Phase 4: Style application (parse agent response, apply to preview)
5. Phase 5: Version history with comparison
6. Phase 6: Inspector-scoped context in prompts
7. Phase 7: Stitch preview (if SDK available)
8. Phase 8: Extended export and codegen

## Success Criteria

1. Type "warm analog synth" → preview updates with rounded knobs, subtle shadows, warm palette
2. Cmd+click knob → type "more skeuomorphic" → only knobs change
3. Upload screenshot → type "like this" → preview approximates style
4. Switch between "80s Mac" and "Neon" variations
5. Export .stylesystem.json → includes geometry + effects
6. No API key needed — uses Claude Code auth
7. Server is <100 lines of Node.js
