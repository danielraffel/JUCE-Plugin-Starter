# AI-Powered Aesthetic Style Designer — Feature Spec

## Vision

Extend the v0.1 color theme designer into a full AI-powered aesthetic design tool. Users describe visual styles in natural language, optionally attach reference images, and see their component showcase update in real-time. The output is a complete style specification exportable to Visage/JUCE, Swift/SwiftUI, and CSS.

## Two Agents, One Workflow

- **Claude** (primary): Understands intent, generates/modifies style JSON, reasons about aesthetics, scopes changes to selected components
- **Stitch** (optional renderer): Generates polished UI mockup images for inspiration/preview before committing style changes

## Core UX Flow

### Global Style Change
1. User types in chat: "Make this look like 1980s Macintosh"
2. Claude generates a style variation (colors + geometry + effects)
3. Preview updates live
4. Variation saved with prompt in history

### Component-Scoped Change
1. User Cmd+clicks a knob (inspector shows it)
2. User types: "Make this more skeuomorphic with a metallic gradient"
3. Claude sees the selected component context
4. Only knob-related styles update
5. Preview updates live

### Image-Referenced Change
1. User uploads a screenshot of a plugin they admire
2. User types: "I want something that looks like this"
3. Claude analyzes the image and derives style properties
4. Preview updates to match

### Stitch-Powered Preview
1. User types: "Show me what a warm analog version could look like"
2. Stitch generates a UI mockup image
3. User reviews the image
4. User says: "Yes, apply that style"
5. Claude translates the Stitch visual into style JSON

## Style System JSON Format

Extends the v0.1 color system with geometry, effects, gradients, typography:

```json
{
  "$schema": "style-system/v1",
  "meta": {
    "name": "80s Macintosh",
    "prompt": "Flat, monochrome, pixel-perfect corners inspired by early Mac",
    "version": "1.0.0",
    "parentVersion": "default",
    "created": "2026-03-23"
  },

  "colorSystem": { ... },  // existing v0.1 color system

  "geometry": {
    "global": {
      "cornerRadius": 0,
      "borderWidth": 2,
      "shadowBlur": 0,
      "shadowOffsetY": 2
    },
    "knob": {
      "arcWidth": 3,
      "arcStyle": "flatArc",
      "thumbSize": 4,
      "thumbShape": "circle"
    },
    "button": {
      "cornerRadius": 0,
      "borderWidth": 2,
      "depth": "flat",
      "paddingX": 12,
      "paddingY": 6
    },
    "toggle": {
      "trackWidth": 32,
      "trackHeight": 18,
      "trackRounding": 2,
      "thumbSize": 14,
      "thumbRounding": 0
    },
    "slider": {
      "trackHeight": 4,
      "trackRounding": 0,
      "thumbSize": 12,
      "thumbShape": "square"
    },
    "textInput": {
      "cornerRadius": 0,
      "borderWidth": 1,
      "paddingX": 4,
      "paddingY": 2
    }
  },

  "effects": {
    "bloom": { "enabled": false, "size": 0, "intensity": 0 },
    "blur": { "enabled": false, "radius": 0 },
    "shadows": {
      "enabled": true,
      "blur": 0,
      "offsetX": 1,
      "offsetY": 1,
      "color": "#000000",
      "alpha": 1.0
    }
  },

  "gradients": {
    "accentGradient": {
      "enabled": false,
      "type": "solid"
    },
    "buttonGradient": {
      "enabled": false,
      "type": "solid"
    }
  },

  "typography": {
    "headingSize": 12,
    "bodySize": 10,
    "labelSize": 9,
    "monoFont": true,
    "fontWeight": "normal"
  },

  "history": [
    {
      "prompt": "Make this look like 1980s Macintosh",
      "timestamp": "2026-03-23T10:30:00Z",
      "changes": ["geometry.global.cornerRadius: 6 -> 0", "effects.bloom.enabled: true -> false"]
    }
  ]
}
```

## Architecture

### Phase 1: Style System Format + Extended Preview
- Define .stylesystem.json schema
- Extend preview components to read geometry/effects/gradient properties
- CSS custom properties for geometry (--st-knob-arc-width, --st-button-rounding, etc.)
- Canvas components read style properties alongside color vars

### Phase 2: Chat UI
- Chat panel (right side, alongside/replacing inspector)
- Message history with prompt/response pairs
- Image upload button (drag-and-drop or file picker)
- Component selection context indicator ("Editing: Rotary Knob" or "Editing: All")
- Send button + Enter to submit

### Phase 3: Claude Agent Connection
- Investigate Assembly app patterns for Max account auth
- Options:
  a) Claude Code Agent SDK (spawns local process)
  b) Anthropic API with OAuth (needs API key — user doesn't want this)
  c) MCP bridge to running Claude Code session
  d) Tauri app wrapping Claude Code subprocess
- The agent receives: current style JSON + selected component + prompt + optional image
- Returns: modified style JSON (or diff)

### Phase 4: Style Application Engine
- Parse returned style JSON
- Apply geometry changes to CSS vars and canvas draw params
- Apply effect changes (bloom, blur, shadow)
- Apply gradient changes
- Apply typography changes
- Live preview update

### Phase 5: Version History
- Save named variations with prompts
- Compare two versions side-by-side (extend A/B feature)
- Revert to any previous version
- Export specific version

### Phase 6: Inspector-Scoped Prompts
- When component is selected via Cmd+click, chat context includes:
  - Component name and type
  - Current style properties for that component
  - Available style properties that can be changed
- Agent scopes its response to that component only

### Phase 7: Stitch Integration
- "Preview with Stitch" button generates a polished mockup
- Stitch SDK called with current style description
- Image displayed alongside the live preview
- "Apply from Stitch" button parses the generated HTML for style properties

### Phase 8: Export
- .stylesystem.json download
- Extended C++ codegen (geometry + effects, not just colors)
- juce-dev skill updated with style system knowledge
- Claude Code can consume the file to generate implementation code

## Key Decision: How to Connect to Claude

This is the critical unknown. Options ranked by preference:

1. **Claude Code subprocess** (via Agent SDK) — user's Max account, no API key, full tool access. Assembly app may use this pattern.
2. **MCP bridge** — theme designer connects to a running Claude Code session via MCP. Zero auth needed since Claude Code handles it.
3. **Anthropic API** — needs API key, most straightforward but user doesn't want separate key.
4. **Tauri wrapper** — desktop app that spawns Claude Code, communicates via IPC.

Investigating Assembly app to determine which pattern they use.

## Feature Branch

`feature/ai-style-designer` branching from `feature/theme-designer` at tag v0.1.

## Success Criteria

1. Type "warm analog synth" → preview updates with warm colors, rounded knobs, subtle shadows
2. Cmd+click a button → type "add depth" → only buttons get shadow/gradient treatment
3. Upload screenshot of Serum → type "like this" → preview approximates the style
4. Compare "80s Mac" vs "Neon" vs "Warm Analog" side by side
5. Export .stylesystem.json → Claude Code generates Visage C++ code from it
6. Works with existing Claude Max account (no API key needed)
