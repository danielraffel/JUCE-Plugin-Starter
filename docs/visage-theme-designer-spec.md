# Visage Theme Designer — Feature Spec

## What This Is

A visual theme design system for JUCE audio plugins that use the Visage GPU UI framework. It lets you design, preview, compare, and export color themes without compiling C++ — then generates the exact Visage palette code your plugin needs.

It works for **both Visage components AND standard JUCE LookAndFeel components**, clearly distinguishing which is which.

---

## User Experience Walkthrough

### Scenario: You just created a new plugin project

```
/juce-dev:create
  → "MyFilterPlugin"
  → Visage UI: yes
  → (project created)

/juce-dev:theme
```

Claude asks:
> What kind of look are you going for?
> 1. Start from a preset (Dark, Light, Midnight, Warm)
> 2. Describe what you want ("dark with neon cyan accents")
> 3. Open the theme designer to browse

You say: **"dark with neon cyan accents, think Blade Runner"**

Claude:
1. Generates a theme JSON with cyan/teal accents, deep blue-black backgrounds, electric highlights
2. Embeds it into `tools/theme-designer.html`
3. Opens the HTML in your browser

```
open tools/theme-designer.html
```

### What You See

A fake plugin window surrounded by a dark app shell. Inside:

```
+--[ MyFilterPlugin — Theme Preview ]------------------+
|                                                       |
|  FOUNDATIONS                                          |
|  [bg-deep] [bg-mid] [bg-surface]  Text samples...    |
|                                                       |
|  CONTROLS                                             |
|  (o) Knob  (o) Knob   [====o====] Slider             |
|  [Button] [Hover] [Active] [Disabled]                 |
|  [Toggle ON ●] [Toggle OFF ○]                         |
|  [Dropdown ▼]  [Search... 🔍]                         |
|                                                       |
|  DATA DISPLAY                                         |
|  ┃▓▓▓▓▓▓▓▓▓▓░░░░░░░░░┃  Waveform                    |
|  ▐█▌▐█▌ VU Meters   [====] Progress                   |
|                                                       |
|  LAYOUT                                               |
|  [Card] [Card] [Card] [Card]   4x4 Grid               |
|  [Tab1 | Tab2 | Tab3]  Panel with border               |
|                                                       |
|  OVERLAYS (shown as static cards)                     |
|  [Modal Dialog]  [Context Menu]  [Tooltip]             |
|                                                       |
|  STATES                                               |
|  Normal | Hover | Focus | Disabled | Error | Loading   |
|                                                       |
|  EFFECTS                                              |
|  Gradient ░▒▓  Shadow ◤  Blur ○  Bloom ✦              |
+-------------------------------------------------------+
```

Every component is color-driven by CSS custom properties that map to the theme JSON.

### How You Tweak: Three Ways

#### Way 1: Select & Tweak (react-grab style)

Hold **Cmd** (Mac) or **Ctrl** (Win/Linux). A canvas overlay activates:

- **Hover** any component — it highlights with a colored border and shows a floating badge:
  ```
  ┌─ Rotary Knob ─── 4 tokens ─┐
  ```
- **Click** to freeze the selection. The right inspector panel shows:
  ```
  INSPECTOR: Rotary Knob
  ─────────────────────────
  KnobArc         [■■] #00FFD4  α 1.0
  KnobArcBg       [■■] #1A2332  α 1.0
  KnobThumb       [■■] #FFFFFF  α 0.9
  knob_arc_width   [====●==] 4.0
  ─────────────────────────
  Source: Visage custom token
  ```
- **Edit** the color picker or slider — preview updates **instantly** (no refresh needed).
- **Arrow keys** to navigate to sibling components.
- **Cmd+C** copies the selected component's tokens as JSON.
- **Release Cmd** to exit inspect mode.

#### Way 2: Prompt Claude Code

Without touching the HTML editor at all:

```
You: "the knobs look great but make the meters more vibrant
      — brighter greens and reds, and add some glow to the
      active meter segments"

Claude: (reads the <script id="theme-data"> block,
         updates MeterGreen, MeterRed, bloom values,
         writes back to the HTML file)
        "Updated 5 tokens — refresh your browser."

You: (Cmd+R to refresh) — see the changes
```

This is the power move: natural language aesthetic direction → instant visual feedback.

#### Way 3: Left Panel Token Browser

The left panel lists ALL tokens organized by group (Button, Toggle, TextEditor, Knob, Meter, etc.) with:
- Color swatch + hex input + alpha slider per color token
- Range slider + numeric input per value token
- Search bar to filter tokens by name
- Collapsible groups

This is for when you want to browse everything or make precise adjustments.

### Power Features

#### A/B Compare

Click **A/B** in the toolbar. The preview splits with a draggable vertical divider:

```
+--[ Theme A (left) ]---|-|---[ Theme B (right) ]--+
|                        |                          |
|  Dark Neon Cyan        |  Warm Analog Orange      |
|  (o) Knob              | (o) Knob                |
|  [Button]              | [Button]                 |
+--                      |                        --+
                         ↕ drag to compare
```

Theme A is your current edit. Theme B loads from a different preset or JSON file. Each side has independent CSS vars — the split is done with `clip-path` so both are always fully rendered.

#### State Scrubber

A row of pills in the toolbar:

```
[Default] [Hover] [Focus] [Active] [Disabled] [Error] [Loading]
```

Click **Hover** — every component in the preview enters its hover state simultaneously. See how your hover colors look across buttons, knobs, toggles, inputs, cards, tabs — all at once. Click **Error** — see error states everywhere.

#### Token Inspector on Hover

Even without Cmd held, hovering any component shows a subtle floating badge with the component name and token count. Clicking it scrolls the left panel to those tokens and highlights them.

#### Export Panel

Click **Export** to open a modal with four tabs:

| Tab | Output |
|-----|--------|
| **JSON** | The full theme JSON — download or copy |
| **CSS Vars** | `--vt-KnobArc: rgba(0,255,212,1.0);` for every token |
| **C++ Header** | `VISAGE_THEME_COLOR(KnobArc, 0xFF00FFD4);` declarations |
| **C++ Palette** | `palette.setColor(theme::KnobArc, Color(0xFF00FFD4));` init function |

Copy to clipboard or download as a file.

### Locking It In

When you're happy:

```
You: "perfect — generate the C++ and wire it up"

Claude:
  1. python3 scripts/generate_theme.py tools/themes/neon-cyan.json \
       --output Source/Theme.h
  2. Adds #include "Theme.h" to PluginEditor.cpp
  3. Adds palette init call in the constructor
  4. Builds: ./scripts/build.sh standalone
  → Plugin launches with your theme applied
```

---

## JUCE vs Visage: How Both Are Supported

### The Problem

A typical plugin has two kinds of styled components:

1. **Visage components** — GPU-rendered via `visage::Frame`, styled via `Palette` with `VISAGE_THEME_COLOR` / `VISAGE_THEME_VALUE`
2. **JUCE components** — CPU-rendered via `juce::Component`, styled via `LookAndFeel` with `ColourId` enums

The theme designer needs to handle BOTH, and make it clear which is which.

### The Solution

The JSON schema has three sections:

```json
{
  "colors": { ... },     // Standard Visage widget tokens (button, toggle, text editor, etc.)
  "values": { ... },     // Standard Visage value tokens (rounding, margins, widths)
  "custom": { ... },     // Project-specific tokens (both Visage AND JUCE)
  "juce": { ... }        // JUCE LookAndFeel ColourId mappings
}
```

The `juce` section maps JUCE ColourId names to colors:

```json
"juce": {
  "Slider::trackColourId":         { "value": "#00FFD4", "alpha": 1.0 },
  "Slider::thumbColourId":         { "value": "#FFFFFF", "alpha": 1.0 },
  "Slider::rotarySliderFillColourId": { "value": "#00FFD4", "alpha": 1.0 },
  "TextButton::buttonColourId":    { "value": "#1A2332", "alpha": 1.0 },
  "ComboBox::backgroundColourId":  { "value": "#0D1117", "alpha": 1.0 },
  "Label::textColourId":           { "value": "#E0E8F0", "alpha": 1.0 }
}
```

### In the HTML Preview

Components are tagged with their source framework:

```
┌─ Rotary Knob ── Visage ── 4 tokens ─┐
┌─ Combo Box ──── JUCE ──── 3 tokens ─┐
```

The left panel groups tokens by framework:

```
VISAGE TOKENS
  ▸ Button (8 colors)
  ▸ Toggle (5 colors)
  ▸ TextEditor (6 colors, 3 values)
  ▸ Custom (13 colors)

JUCE TOKENS
  ▸ Slider (5 colors)
  ▸ Button (4 colors)
  ▸ ComboBox (5 colors)
  ▸ Label (3 colors)
```

### In the C++ Codegen

The Python script generates TWO outputs:

**`Source/Theme.h`** — Visage tokens:
```cpp
namespace theme {
  VISAGE_THEME_COLOR(KnobArc, 0xFF00FFD4);
  VISAGE_THEME_VALUE(KnobArcWidth, 4.0f);
}
```

**`Source/ThemeLookAndFeel.h`** — JUCE LookAndFeel:
```cpp
class ThemeLookAndFeel : public juce::LookAndFeel_V4 {
public:
    ThemeLookAndFeel() {
        setColour(juce::Slider::trackColourId, juce::Colour(0xFF00FFD4));
        setColour(juce::Slider::thumbColourId, juce::Colour(0xFFFFFFFF));
        // ... all JUCE colors from the theme
    }
};
```

### How Melatonin Inspector Fits

Melatonin Inspector is a **runtime companion** to the theme designer:

| Tool | When | What |
|------|------|------|
| **Theme Designer (HTML)** | Before building | Design the theme visually, fast iteration |
| **Melatonin Inspector** | After building | Verify colors in the real plugin, live-tweak at runtime |

The workflow:

1. **Design** in the HTML theme designer (fast, no compile)
2. **Generate** C++ and build
3. **Inspect** with Melatonin Inspector (Cmd+I in the running plugin)
   - Verify colors match your design
   - Click any component → see its actual ColourIds and values
   - Live-edit a color to test a variation
   - If you like the change, go back to step 1 and update the theme JSON
4. **Ship** when everything looks right

The theme designer does NOT replace Melatonin Inspector — they serve different stages:
- Theme designer = **design-time** (HTML preview, no compile needed)
- Melatonin Inspector = **runtime** (real plugin, real GPU rendering, real DAW host)

We already support Melatonin Inspector in the build system (`ENABLE_MELATONIN_INSPECTOR=true` in `.env`). No new integration needed — they naturally complement each other.

---

## File Inventory

| # | File | Repo | Est. Lines | Purpose |
|---|------|------|------------|---------|
| 1 | `tools/theme-designer.html` | JUCE-Plugin-Starter | ~2500 | Single-file HTML preview + editor |
| 2 | `tools/themes/default.json` | JUCE-Plugin-Starter | ~150 | Default theme (Visage defaults) |
| 3 | `tools/themes/presets/dark.json` | JUCE-Plugin-Starter | ~30 | Diff preset |
| 4 | `tools/themes/presets/light.json` | JUCE-Plugin-Starter | ~30 | Diff preset |
| 5 | `tools/themes/presets/midnight.json` | JUCE-Plugin-Starter | ~30 | Diff preset |
| 6 | `tools/themes/presets/warm.json` | JUCE-Plugin-Starter | ~30 | Diff preset |
| 7 | `scripts/generate_theme.py` | JUCE-Plugin-Starter | ~350 | JSON to C++ codegen |
| 8 | `commands/theme.md` | juce-dev plugin | ~100 | /juce-dev:theme command |
| 9 | `skills/visage-theme/SKILL.md` | juce-dev plugin | ~120 | Theme system knowledge |
| 10 | `skills/visage-theme/references/token-catalog.md` | juce-dev plugin | ~100 | All known Visage tokens |
| 11 | `skills/visage-theme/references/theme-workflow.md` | juce-dev plugin | ~60 | Design session patterns |

---

## JSON Theme Schema (Definitive)

```json
{
  "$schema": "visage-theme/v1",

  "meta": {
    "name": "Neon Cyan",
    "description": "Dark theme with electric cyan accents",
    "author": "Your Name",
    "version": "1.0.0",
    "base": null,
    "created": "2026-03-22",
    "modified": "2026-03-22"
  },

  "colors": {
    "UiButtonBackground":        { "value": "#1A1A2E", "alpha": 1.0, "comment": "Button resting fill" },
    "UiButtonBackgroundHover":   { "value": "#2D2D4E", "alpha": 1.0 },
    "UiButtonText":              { "value": "#C8C8DC", "alpha": 1.0 },
    "UiButtonTextHover":         { "value": "#FFFFFF", "alpha": 1.0 },
    "UiActionButtonBackground":  { "value": "#00FFD4", "alpha": 1.0, "comment": "Accent button" },
    "UiActionButtonBackgroundHover": { "value": "#33FFE0", "alpha": 1.0 },
    "UiActionButtonText":        { "value": "#000000", "alpha": 1.0 },
    "UiActionButtonTextHover":   { "value": "#000000", "alpha": 1.0 },
    "ToggleButtonDisabled":      { "value": "#3A3A3A", "alpha": 0.5 },
    "ToggleButtonOff":           { "value": "#3A3A50", "alpha": 1.0 },
    "ToggleButtonOffHover":      { "value": "#4A4A60", "alpha": 1.0 },
    "ToggleButtonOn":            { "value": "#00FFD4", "alpha": 1.0 },
    "ToggleButtonOnHover":       { "value": "#33FFE0", "alpha": 1.0 },
    "TextEditorBackground":      { "value": "#0D0D1A", "alpha": 1.0 },
    "TextEditorBorder":          { "value": "#3A3A5A", "alpha": 1.0 },
    "TextEditorText":            { "value": "#E0E0F0", "alpha": 1.0 },
    "TextEditorDefaultText":     { "value": "#6A6A8A", "alpha": 1.0 },
    "TextEditorCaret":           { "value": "#00FFD4", "alpha": 1.0 },
    "TextEditorSelection":       { "value": "#00FFD4", "alpha": 0.3 },
    "PopupMenuBackground":       { "value": "#262A2E", "alpha": 1.0 },
    "PopupMenuBorder":           { "value": "#606265", "alpha": 1.0 },
    "PopupMenuText":             { "value": "#EEEEEE", "alpha": 1.0 },
    "PopupMenuSelection":        { "value": "#00FFD4", "alpha": 1.0 },
    "PopupMenuSelectionText":    { "value": "#000000", "alpha": 1.0 },
    "ScrollBarDefault":          { "value": "#FFFFFF", "alpha": 0.13 },
    "ScrollBarDown":             { "value": "#FFFFFF", "alpha": 0.33 },
    "ButtonShadow":              { "value": "#000000", "alpha": 0.53 },
    "LineColor":                 { "value": "#00FFD4", "alpha": 1.0 },
    "LineFillColor":             { "value": "#00FFD4", "alpha": 0.15,
      "gradient": { "direction": "vertical", "toValue": "#00FFD4", "toAlpha": 0.0 }
    },
    "GridColor":                 { "value": "#3A3A5A", "alpha": 0.4 }
  },

  "values": {
    "TextEditorRounding":   { "value": 4.0,   "min": 0,  "max": 24, "comment": "Corner radius px" },
    "TextEditorMarginX":    { "value": 8.0,   "min": 0,  "max": 32 },
    "TextEditorMarginY":    { "value": 6.0,   "min": 0,  "max": 32 },
    "TextButtonRounding":   { "value": 9.0,   "min": 0,  "max": 24 },
    "UiButtonRounding":     { "value": 9.0,   "min": 0,  "max": 24 },
    "PopupOptionHeight":    { "value": 22.0,  "min": 16, "max": 40 },
    "PopupFontSize":        { "value": 14.0,  "min": 10, "max": 24 },
    "ScrollBarWidth":       { "value": 20.0,  "min": 8,  "max": 32 }
  },

  "custom": {
    "PluginBackground":     { "value": "#0A0E14", "alpha": 1.0, "comment": "Main plugin bg" },
    "PanelBackground":      { "value": "#111620", "alpha": 1.0 },
    "PanelBorder":          { "value": "#1E2A3A", "alpha": 1.0 },
    "KnobArc":              { "value": "#00FFD4", "alpha": 1.0 },
    "KnobArcBackground":    { "value": "#1A2332", "alpha": 1.0 },
    "KnobThumb":            { "value": "#FFFFFF", "alpha": 0.9 },
    "AccentPrimary":        { "value": "#00FFD4", "alpha": 1.0 },
    "AccentSecondary":      { "value": "#7B61FF", "alpha": 1.0 },
    "AccentTertiary":       { "value": "#FF6B6B", "alpha": 1.0 },
    "MeterGreen":           { "value": "#22C55E", "alpha": 1.0 },
    "MeterYellow":          { "value": "#EAB308", "alpha": 1.0 },
    "MeterRed":             { "value": "#EF4444", "alpha": 1.0 },
    "WaveformLine":         { "value": "#00FFD4", "alpha": 1.0 },
    "WaveformFill":         { "value": "#00FFD4", "alpha": 0.15 },
    "WaveformPlayhead":     { "value": "#FFFFFF", "alpha": 0.8 },
    "WaveformGrid":         { "value": "#1E2A3A", "alpha": 0.6 },
    "OverlayBackground":    { "value": "#000000", "alpha": 0.75 },
    "ModalBackground":      { "value": "#111620", "alpha": 1.0 },
    "TooltipBackground":    { "value": "#1A2332", "alpha": 1.0 },
    "TooltipText":          { "value": "#E0E8F0", "alpha": 1.0 },
    "Success":              { "value": "#22C55E", "alpha": 1.0 },
    "Error":                { "value": "#EF4444", "alpha": 1.0 },
    "Warning":              { "value": "#EAB308", "alpha": 1.0 }
  },

  "juce": {
    "Slider::trackColourId":               { "value": "#1A2332", "alpha": 1.0 },
    "Slider::thumbColourId":               { "value": "#FFFFFF", "alpha": 1.0 },
    "Slider::rotarySliderFillColourId":    { "value": "#00FFD4", "alpha": 1.0 },
    "Slider::rotarySliderOutlineColourId": { "value": "#1A2332", "alpha": 1.0 },
    "Slider::textBoxBackgroundColourId":   { "value": "#0D0D1A", "alpha": 1.0 },
    "Slider::textBoxTextColourId":         { "value": "#E0E8F0", "alpha": 1.0 },
    "TextButton::buttonColourId":          { "value": "#1A1A2E", "alpha": 1.0 },
    "TextButton::buttonOnColourId":        { "value": "#00FFD4", "alpha": 1.0 },
    "TextButton::textColourOffId":         { "value": "#C8C8DC", "alpha": 1.0 },
    "TextButton::textColourOnId":          { "value": "#000000", "alpha": 1.0 },
    "ComboBox::backgroundColourId":        { "value": "#0D0D1A", "alpha": 1.0 },
    "ComboBox::textColourId":              { "value": "#E0E8F0", "alpha": 1.0 },
    "ComboBox::outlineColourId":           { "value": "#3A3A5A", "alpha": 1.0 },
    "Label::textColourId":                 { "value": "#E0E8F0", "alpha": 1.0 },
    "Label::backgroundColourId":           { "value": "#00000000", "alpha": 0.0 }
  },

  "overrides": {
    "comment": "Per-OverrideId Visage color overrides for subtree scoping (advanced)"
  }
}
```

### Schema Rules

- `colors.*` — Standard Visage widget tokens (from visage_widgets headers)
- `values.*` — Standard Visage value tokens
- `custom.*` — Project-specific Visage tokens
- `juce.*` — JUCE LookAndFeel ColourId mappings (keyed by `ClassName::colourIdName`)
- `meta.base` — `null` for complete themes; a preset name for diff themes (only changed keys stored)
- Color format: `value` is `#RRGGBB` (web-standard), `alpha` is 0.0-1.0 float
- Codegen converts to Visage `0xAARRGGBB` format automatically
- `gradient` is optional: `{ direction, toValue, toAlpha }` for Visage Brush gradients

---

## HTML Page Architecture

### Layout (CSS Grid)

```
┌─────────────────────────────────────────────────────────┐
│ TOOLBAR: [Theme ▼] [Presets ▼] [A/B] [States] [Export] │
├──────────────┬──────────────────────────┬───────────────┤
│ LEFT PANEL   │ PREVIEW                  │ INSPECTOR     │
│ 320px        │ (flex grow)              │ 280px         │
│              │                          │               │
│ Token groups │ Fake plugin window       │ (contextual)  │
│ by framework │ with all component       │               │
│ (Visage/JUCE)│ sections                 │ Hold Cmd to   │
│              │                          │ inspect       │
│ Search bar   │ Canvas overlay for       │               │
│              │ select+tweak             │ Selected      │
│ Collapsible  │                          │ component's   │
│ sections     │ A/B split when active    │ tokens shown  │
│              │                          │ with editors  │
├──────────────┴──────────────────────────┴───────────────┤
│ STATUS BAR: "3 tokens modified from Dark preset"        │
└─────────────────────────────────────────────────────────┘
```

### JS Architecture (Inline Object Namespaces)

```
ThemeSchema       — Token definitions, defaults, groups, metadata
TokenRegistry     — Active theme state, diffs from base, undo stack
PresetLibrary     — Built-in presets (dark, light, midnight, warm)
ColorConverter    — hex/alpha/argb/rgba conversions
CSSBridge         — JSON tokens → CSS custom properties on pane elements
ComponentRenderer — Renders all 7 sections, manages canvas components
CanvasRenderer    — Knob arcs, waveforms, VU meters, spectrum (reads CSS vars)
StateController   — State scrubber (hover/focus/disabled/error/loading)
SelectAndTweak    — react-grab pattern: Cmd+hover+click+inspect
TokenInspector    — Right panel showing selected component's tokens
ABCompare         — clip-path based split view with draggable divider
ExportPanel       — JSON/CSS/C++ header/C++ palette generation
ImportExport      — FileReader import, Blob download
UndoManager       — 50-step undo/redo with Cmd+Z/Y
LeftPanel         — Token browser with search, groups, inline editing
AppController     — Init, wiring, keyboard shortcuts
```

### CSS Architecture

- App shell uses its own design tokens (`--app-*`) — NOT theme tokens
- Theme tokens use `--vt-*` prefix (Visage Theme)
- JUCE tokens use `--jt-*` prefix (JUCE Theme)
- All component CSS uses ONLY these custom properties
- State overrides via `[data-preview-state="hover"] .component { ... }`
- A/B compare via `clip-path: inset()` on overlaid panes
- Fonts embedded as base64 data URIs (Inter for UI, JetBrains Mono for code)

### Visual Reference

See `docs/theme-designer-mockup-v2.html` and `docs/theme-designer-mockup-v2.png` for the Stitch-generated reference mockup showing the target aesthetic: clean, muted dark grays, soft purple accents, professional developer tool feel (not cyberpunk).

### Canvas Components

These can't use CSS directly, so they read vars via `getComputedStyle`:

```js
function drawKnob(ctx, value) {
  const style = getComputedStyle(ctx.canvas);
  const arcColor = style.getPropertyValue('--vt-KnobArc').trim();
  const arcBg = style.getPropertyValue('--vt-KnobArcBackground').trim();
  const thumb = style.getPropertyValue('--vt-KnobThumb').trim();
  // draw circular arc from 7 o'clock to 5 o'clock position
  // IMPORTANT: knobs must be perfectly round (circular canvas, border-radius: 50%)
}
```

Redrawn via MutationObserver watching style changes → debounced requestAnimationFrame.

### Select & Tweak Implementation

```
Every preview component gets: data-tokens="KnobArc,KnobArcBackground,KnobThumb"
                              data-component="Rotary Knob"
                              data-framework="visage" (or "juce")

Cmd held → canvas overlay activates (pointer-events: none)
         → pointermove → elementFromPoint() → read data-tokens
         → draw highlight rectangle + floating badge
         → badge shows: "Rotary Knob — Visage — 3 tokens"

Click   → freeze selection → populate INSPECTOR panel:
         → color pickers + hex inputs + alpha sliders for each token
         → edits fire CSSBridge.syncVar() → instant update

Release Cmd → deactivate overlay, keep inspector content
```

---

## Python Codegen: `scripts/generate_theme.py`

### Usage

```bash
# Generate Visage C++ header
python3 scripts/generate_theme.py theme.json --output Source/Theme.h

# Generate JUCE LookAndFeel class
python3 scripts/generate_theme.py theme.json --output Source/ThemeLookAndFeel.h --mode juce

# Generate both
python3 scripts/generate_theme.py theme.json --output Source/Theme --mode both

# Validate JSON only
python3 scripts/generate_theme.py theme.json --validate-only

# Print to stdout
python3 scripts/generate_theme.py theme.json
```

### Output: Visage Header (`--mode header`, default)

```cpp
#pragma once
// Generated by Visage Theme Designer
// Theme: Neon Cyan v1.0.0
// Source: tools/themes/neon-cyan.json

#include "visage_graphics/theme.h"

namespace theme {

// Button
VISAGE_THEME_COLOR(UiButtonBackground,      0xFF1A1A2E);
VISAGE_THEME_COLOR(UiButtonBackgroundHover,  0xFF2D2D4E);
// ...

// Custom (Project-Specific)
VISAGE_THEME_COLOR(KnobArc,                 0xFF00FFD4);
VISAGE_THEME_COLOR(PluginBackground,         0xFF0A0E14);
// ...

// Values
VISAGE_THEME_VALUE(TextEditorRounding, 4.0f);
VISAGE_THEME_VALUE(UiButtonRounding,   9.0f);
// ...

} // namespace theme
```

### Output: JUCE LookAndFeel (`--mode juce`)

```cpp
#pragma once
// Generated by Visage Theme Designer
// JUCE LookAndFeel colors from: Neon Cyan v1.0.0

#include <juce_gui_basics/juce_gui_basics.h>

class ThemeLookAndFeel : public juce::LookAndFeel_V4 {
public:
    ThemeLookAndFeel() {
        setColour(juce::Slider::trackColourId,
                  juce::Colour(0xFF1A2332));
        setColour(juce::Slider::thumbColourId,
                  juce::Colour(0xFFFFFFFF));
        // ... all JUCE colors
    }
};
```

### Key Functions

```python
def hex_alpha_to_argb(hex_color: str, alpha: float) -> int:
    """Convert '#RRGGBB' + alpha(0-1) to 0xAARRGGBB."""
    r = int(hex_color[1:3], 16)
    g = int(hex_color[3:5], 16)
    b = int(hex_color[5:7], 16)
    a = round(alpha * 255)
    return (a << 24) | (r << 16) | (g << 8) | b

def validate_token_name(name: str) -> bool:
    """Ensure name is a valid C++ identifier."""
    return bool(re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', name))
```

---

## juce-dev Integration

### Command: `/juce-dev:theme`

Stage-based workflow:

1. **Guard**: Check `tools/theme-designer.html` exists. If not, offer to copy from template.
2. **Detect**: Read existing theme files in `tools/themes/`. Check `.env` for `THEME_FILE`.
3. **Ask**: What do you want to do?
   - Design a new theme (natural language description)
   - Edit existing theme
   - Generate C++ from JSON
   - Open theme designer in browser
4. **Execute**: Generate/update JSON, embed in HTML, open browser, or run codegen.
5. **Report**: Summary of what was done, next steps.

### Skill: `visage-theme`

Triggers on: "theme", "colors", "palette", "styling", "branding", "dark mode", "light mode"

Provides Claude with:
- ARGB format rules (0xAARRGGBB, alpha in high byte)
- All known Visage tokens with defaults
- JSON schema reference
- Codegen usage
- Palette init patterns
- OverrideId scoping for per-component themes
- Common mistakes (ARGB vs RGBA byte order)

---

## Build Phases

### Phase 1: Foundation (JSON + Codegen)

**Goal**: Theme JSON schema and Python codegen working end-to-end.

- [ ] Create `tools/themes/` directory
- [ ] Write `tools/themes/default.json` with all known Visage tokens + JUCE tokens
- [ ] Write `scripts/generate_theme.py` — header + JUCE LookAndFeel generation
- [ ] Write 4 preset diffs (dark, light, midnight, warm)
- [ ] Test round-trip: JSON → C++ header → compiles

**Deliverable**: `python3 scripts/generate_theme.py tools/themes/default.json` prints valid C++.

### Phase 2: HTML Shell + Core Editing

**Goal**: HTML page opens, displays tokens, live editing works.

- [ ] Create `tools/theme-designer.html` skeleton (app shell, 3-column layout, toolbar)
- [ ] Embed fonts (Inter + JetBrains Mono subsets as base64)
- [ ] Implement ThemeSchema, TokenRegistry, ColorConverter
- [ ] Implement CSSBridge (JSON → CSS custom properties)
- [ ] Implement LeftPanel (token groups, search, inline color/value editing)
- [ ] Wire live editing: change a color → CSS var updates → preview changes
- [ ] Implement ImportExport (JSON load/save via FileReader + Blob)

**Deliverable**: Open HTML, see token list, edit a color, preview updates live.

### Phase 3: Component Sections

**Goal**: All 7 preview sections rendered with theme-driven styling.

- [ ] Foundations (backgrounds, text hierarchy, accents, borders)
- [ ] Controls (canvas knobs, CSS sliders, buttons with 4 states, toggles, dropdown, inputs)
- [ ] Data Display (canvas waveform with fake audio data, VU meters, spectrum, progress, param bar)
- [ ] Layout (cards in 4 states, panels, tabs, scroll area, 4x4 grid, dividers)
- [ ] Overlays (static open-state cards: modal, confirm, settings, context menu, tooltip, presets)
- [ ] States (row of each component in normal/hover/focus/disabled/error/loading)
- [ ] Effects (gradient swatches, shadow demos, blur approximation, glow approximation)
- [ ] Tag every component with `data-tokens`, `data-component`, `data-framework`

**Deliverable**: Full component showcase visible, all driven by CSS vars.

### Phase 4: Interactive Features

**Goal**: Power features that make the tool exceptional.

- [ ] Select & Tweak (Cmd+hover+click → canvas overlay → inspector panel)
- [ ] A/B Compare (clip-path split view, draggable divider, independent themes)
- [ ] State Scrubber (pill buttons, data-preview-state attribute, CSS overrides)
- [ ] Export Panel (4 tabs: JSON, CSS vars, C++ header, C++ palette)
- [ ] UndoManager (50-step, Cmd+Z/Y)
- [ ] Preset switching (dropdown → load preset diff → merge with base)
- [ ] Plugin window chrome (fake title bar with traffic lights)
- [ ] Keyboard shortcuts (Cmd+Z undo, Cmd+Y redo, Cmd+E export, Cmd+I toggle inspector)

**Deliverable**: All interactive features working. A/B compare, state scrubber, select+tweak.

### Phase 5: juce-dev Integration

**Goal**: `/juce-dev:theme` command works end-to-end.

- [ ] Write `commands/theme.md`
- [ ] Write `skills/visage-theme/SKILL.md`
- [ ] Write `references/token-catalog.md`
- [ ] Write `references/theme-workflow.md`
- [ ] Test: `/juce-dev:theme` → "neon cyberpunk" → generates theme → opens browser → export C++ → builds
- [ ] Add `THEME_FILE` to `.env.example`
- [ ] Update `init_plugin_project.sh` to copy theme designer files to new projects

**Deliverable**: Complete flow from `/juce-dev:theme` prompt to compiled plugin with custom theme.

---

## Why This Is Useful

### For the developer who's never done audio plugin UI

You don't need to know what `0xAARRGGBB` means. You don't need to know what `VISAGE_THEME_COLOR` is. You describe what you want in English, see it in a browser, click to fine-tune, and the system generates the C++ for you.

### For the experienced developer

You get a proper design system page showing every component state. A/B compare lets you evaluate variants. Token inspector shows you exactly which tokens affect which component. Export gives you copy-paste C++ code. No more guessing hex values and rebuilding to see the result.

### For iterating with Claude Code

The HTML page is the visual feedback loop. Claude understands the JSON schema (via the skill), can read/write the theme data embedded in the HTML, and can describe changes in natural language. The cycle is:

```
prompt → Claude edits JSON → refresh browser → react → prompt again
```

No compile step in the loop. Compilation only happens when you're ready to lock in.

### For supporting both JUCE and Visage

Most plugins use a mix — JUCE components for standard UI (sliders, buttons, labels) and Visage for custom GPU-rendered elements (waveforms, visualizers, custom knobs). The theme designer handles both, generates separate code for each, and clearly labels which framework owns each component.

---

## The Tool Landscape

### What Exists Today vs What We're Building

|  | **Designer** (pick colors, no compile) | **Inspector** (debug at runtime) |
|---|---|---|
| **JUCE** | Nothing exists -> **Theme Designer (Step 1)** | Melatonin Inspector (exists, keep as-is) |
| **Visage** | Nothing exists -> **Theme Designer (Step 1)** | PaletteEditor (exists, basic) -> **Visage Inspector (Step 2, future)** |

### Tool Definitions

- **Melatonin Inspector**: Browser DevTools for JUCE. Run your plugin, press Cmd+I, click a component, see its bounds/colors/properties. Live-tweak temporarily. Changes vanish on close. It's for debugging, not designing. We leave it alone.

- **PaletteEditor** (Visage built-in): A raw swatch editor for the Visage Palette. Left column shows color swatches, right column lists token names grouped by source file. Click a swatch to edit in ColorPicker. Drag swatches onto tokens to remap. No component preview, no visual context, no undo, no export. It's a "color database editor" — useful for developers who already know which token controls what.

- **Theme Designer** (Step 1, this feature): A visual design tool showing what components actually look like — knobs, sliders, buttons, meters, modals — all styled by your theme. You see the result before writing any C++. Works for both JUCE and Visage tokens. Generates C++ code for both frameworks.

- **Visage Inspector** (Step 2, future): Like Melatonin but for the Visage frame tree. Click a Visage component in your running plugin, see its tokens, live-edit with the real GPU renderer. Reads the same theme.json format as the Theme Designer.

### Why Two Steps

Step 1 (Theme Designer) has the highest immediate value:
- Works for everyone (Visage or not)
- Requires zero compilation for iteration
- Enables the Claude Code prompt-driven workflow
- The JSON schema and codegen it creates become shared infrastructure for Step 2

Step 2 (Visage Inspector) is genuinely novel but requires a running plugin:
- Component tree browser for Visage Frames
- Click-to-select on the actual plugin UI with real GPU rendering
- Live palette editing with undo
- Import/export to the same theme.json format
- Could ship as a debug panel in plugins (like Melatonin does for JUCE)

PaletteEditor works as a stopgap runtime tool until Step 2 is built.

---

## Future: Visage Inspector (Step 2)

### What It Would Be

A Visage-native `Frame`-based inspector panel, inspired by Melatonin Inspector's UX but built for Visage's rendering model:

- **Frame Tree Browser**: Hierarchical view of all `visage::Frame` children, like Melatonin's Component tree but for Visage
- **Click-to-Select**: Hold modifier key, click on the running plugin UI, the clicked Frame highlights and its tokens appear in the inspector
- **Token Inspector**: Shows which `ColorId` and `ValueId` tokens the selected Frame's `draw()` method reads, with live color swatches
- **Live Palette Editing**: Color pickers and value sliders that call `palette.setColor()` / `palette.setValue()` directly — changes render instantly via GPU
- **Undo/Redo**: Unlike the existing PaletteEditor, edits push to an undo stack
- **Import/Export**: Reads and writes the same `theme.json` format as the HTML Theme Designer — round-trip between design-time and runtime
- **A/B Compare**: Swap between two palettes to see real GPU-rendered differences
- **Bounds Overlay**: Melatonin-style bounding box display with distance measurements between Frames

### Integration

```cpp
// In PluginEditor.h (debug builds only)
#if JUCE_DEBUG
#include "VisageInspector.h"
visage_inspector::Inspector inspector { visageRootFrame() };
// Toggle with Cmd+Shift+I (Cmd+I stays for Melatonin)
#endif
```

### Relationship to Other Tools

```
Design Loop:
  Theme Designer (HTML) --[export JSON]--> generate_theme.py --[C++ header]--> Build
       ^                                                                         |
       |                                                                         v
       +----[import JSON]<---- Visage Inspector (runtime) <---- Running Plugin
```

Both tools share the `theme.json` format. You design in the browser, build, inspect at runtime, tweak, export back to JSON, and iterate.

### Implementation Scope

This is a separate feature tracked as a GitHub issue. Estimated effort: 2-3 weeks. Not part of the current Theme Designer implementation.

---

## Stitch SDK Mockups

Google's Stitch SDK (`@google/stitch-sdk`) can generate UI screen mockups from text prompts. We can use it to create visual reference images for this spec and for the Theme Designer's default appearance.

```ts
import { stitch } from "@google/stitch-sdk";

const project = await stitch.createProject("Visage Theme Designer");
const screen = await project.generate(
  "A dark-themed audio plugin theme designer tool with three columns: " +
  "left panel showing color token groups (Button, Toggle, TextEditor), " +
  "center panel showing a fake plugin window with rotary knobs, sliders, " +
  "buttons, VU meters, and a waveform display, " +
  "right panel showing a token inspector with color pickers. " +
  "Top toolbar has theme dropdown, A/B compare button, state scrubber pills, " +
  "and export button. Dark purple/blue color scheme like Melatonin Inspector."
);
const imageUrl = await screen.getImage();
```

Mockup images would be linked here once generated. Stitch is used only for reference images — the actual Theme Designer is hand-built vanilla HTML/CSS/JS for maximum control and `file://` compatibility.
