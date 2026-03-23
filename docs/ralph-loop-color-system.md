# Ralph Loop: Universal Color System Editor

## Task

Build an OKLCH-based universal color system editor into `/Users/danielraffel/Code/JUCE-Plugin-Starter/Tools/theme-designer.html`. This replaces the existing basic `PaletteGen` module with a professional-grade color system inspired by supacolors.studio.

The color system core is **platform-agnostic**. First export target is Visage/JUCE. The architecture must support future Swift/SwiftUI, CSS/Tailwind, and Android export targets without changes to the core.

## What to Build

### 1. OKLCH Color Engine (`OklchEngine` module)

Replace the current HSL-based `PaletteGen` with proper OKLCH math:

```
sRGB → Linear RGB → OKLab → OKLCH (and reverse)
```

**Required functions:**
- `srgbToOklch(r, g, b)` → `{L, C, H}` (L: 0-1, C: 0-0.4, H: 0-360)
- `oklchToSrgb(L, C, H)` → `{r, g, b}` (clamped to 0-255 sRGB gamut)
- `oklchToHex(L, C, H)` → `"#RRGGBB"`
- `hexToOklch(hex)` → `{L, C, H}`
- `isInGamut(L, C, H)` → boolean (check if OKLCH values map to valid sRGB)
- `gamutMap(L, C, H)` → `{L, C, H}` (reduce chroma until in sRGB gamut)
- `contrastRatio(hex1, hex2)` → number (WCAG 2.1 relative luminance formula)
- `contrastLevel(ratio)` → `"AAA"` | `"AA"` | `"ratio"` | `"fail"`

**OKLCH math reference (authoritative):**

sRGB to Linear RGB:
```
linear = srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055) ^ 2.4
```

Linear RGB to OKLab:
```
l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
s = 0.0883024619 * lr + 0.2220049381 * lg + 0.6696926000 * lb
l_ = cbrt(l), m_ = cbrt(m), s_ = cbrt(s)
L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
```

OKLab to OKLCH:
```
C = sqrt(a*a + b*b)
H = atan2(b, a) * 180 / PI  (normalize to 0-360)
```

WCAG contrast:
```
relativeLuminance(r,g,b) = 0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB
contrastRatio = (lighter + 0.05) / (darker + 0.05)
AAA >= 7.0, AA >= 4.5
```

### 2. Shade Ramp Generator (`ShadeGenerator` module)

Generate 11 shades (50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950) from a base color.

**Lightness targets** (from Tailwind 4 analysis):
```
shade  50: L ≈ 0.97
shade 100: L ≈ 0.95
shade 200: L ≈ 0.90
shade 300: L ≈ 0.85
shade 400: L ≈ 0.75
shade 500: L ≈ 0.60  (anchor — base color usually here)
shade 600: L ≈ 0.50
shade 700: L ≈ 0.40
shade 800: L ≈ 0.30
shade 900: L ≈ 0.20
shade 950: L ≈ 0.13
```

**Chroma behavior:** Don't keep chroma constant. At extreme lightness (very light or very dark), reduce chroma proportionally — pure whites/blacks can't hold high chroma. Scale chroma by `min(1, baseC * (1 - abs(targetL - baseL) * 0.5))`.

**Hue behavior:** Keep hue constant across all shades (unlike some systems that shift hue). This is the Tailwind approach.

**Per-shade override:** Each shade can be marked as `overridden: true` with custom L/C/H values. When the base color changes, overridden shades stay fixed while auto shades regenerate.

### 3. Built-in Palette Templates

Ship the **complete Tailwind 4 palette** with exact OKLCH values (captured from supacolors). This is the data — embed it as a JS const:

22 families: slate, gray, zinc, neutral, stone, red, orange, amber, yellow, lime, green, emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink, rose.

Each with 11 shades. Use the exact OKLCH values from the Tailwind 4 template (available in the supacolors export we captured — check the existing embedded theme data or the snapshot data in the conversation history).

### 4. Color System Data Model (`ColorSystem` module)

```js
const colorSystem = {
  meta: { name, version, description, author, created, modified },
  palettes: {
    "accent": {
      name: "accent",
      baseColor: { L: 0.606, C: 0.25, H: 292.7 },  // OKLCH
      shades: {
        50:  { L: 0.969, C: 0.016, H: 293.756, hex: "#F5F0FF", overridden: false },
        100: { L: 0.943, C: 0.029, H: 294.588, hex: "#EDE5FF", overridden: false },
        // ... all 11 shades
      }
    },
    "neutral": { ... },
    "success": { ... },
    "warning": { ... },
    "error": { ... }
  },
  semanticRoles: {
    dark: {
      "PluginBackground":    { palette: "neutral", shade: 950 },
      "PanelBackground":     { palette: "neutral", shade: 900 },
      "PanelBorder":         { palette: "neutral", shade: 700 },
      "TextPrimary":         { palette: "neutral", shade: 50 },
      "TextSecondary":       { palette: "neutral", shade: 400 },
      "AccentPrimary":       { palette: "accent",  shade: 500 },
      "KnobArc":             { palette: "accent",  shade: 500 },
      "SliderFill":          { palette: "accent",  shade: 500 },
      "UiButtonBackground":  { palette: "neutral", shade: 700 },
      "UiButtonBackgroundHover": { palette: "neutral", shade: 600 },
      "ToggleButtonOn":      { palette: "accent",  shade: 500 },
      "MeterGreen":          { palette: "success", shade: 500 },
      "MeterYellow":         { palette: "warning", shade: 500 },
      "MeterRed":            { palette: "error",   shade: 500 },
      // ... all semantic roles
    },
    light: {
      "PluginBackground":    { palette: "neutral", shade: 50 },
      "PanelBackground":     { palette: "neutral", shade: 100 },
      // ... inverted mapping
    }
  },
  exportTargets: ["visage", "css"]  // which export formats are enabled
};
```

### 5. UI: Replace PaletteGen Panel

Remove the existing `#palette-gen` HTML and `PaletteGen` JS module. Replace with a new **Color System panel** in the left sidebar that has:

**Panel Header:** "Color System" with a collapsible toggle

**Palette List:** Show each palette as a row with:
- Small hue circle (filled with shade-500 color)
- Palette name (editable)
- Mini shade ramp (11 tiny swatches in a row)
- Click to expand/edit

**Expanded Palette Editor (when clicked):**
- Hue slider (0-360, rainbow gradient background)
- Chroma slider (0 to max gamut)
- L/C/H numeric inputs
- The shade ramp as clickable swatches (56px tall, show shade number on hover)
- "Anchor" indicator showing which shade is the base
- WCAG contrast badge on each shade (vs white or vs shade-950)

**Bottom controls:**
- "Add Palette" button
- Mode toggle: Dark / Light
- "Apply to Theme" button — maps semantic roles to token registry

**Template selector:** Dropdown to load a built-in template (Tailwind 4 initially, more later)

### 6. Semantic Role Mapping Integration

When "Apply to Theme" is clicked:
1. Read `colorSystem.semanticRoles[currentMode]`
2. For each role, look up `palette[shade].hex`
3. Call `TokenRegistry.setColor(section, tokenName, hex, alpha)` for each
4. Trigger `CSSBridge.syncAll()`, `LeftPanel.render()`, `PreviewRenderer.render()`

This replaces the current `PaletteGen.applyToTheme()` method.

### 7. Save/Load Color Systems

- **Save:** Export `colorSystem` as `.colorsystem.json` via Blob download
- **Load:** Import via FileReader, populate the color system, re-render
- **Embed:** Store the active color system in `<script id="color-system-data">` alongside the theme data, for `file://` compatibility
- **Auto-apply:** When a color system is loaded, automatically apply semantic roles to the theme

### 8. Export Expansion

Add two new export tabs to the existing ExportPanel:

- **OKLCH CSS:** Export as `oklch()` CSS values: `:root { --color-accent-500: oklch(60.6% 0.25 292.7); }`
- **Color System JSON:** Export the raw `.colorsystem.json`

The existing JSON/CSS/C++ Header/C++ Palette tabs remain.

## Files to Modify

1. **`Tools/theme-designer.html`** — Main file. Replace PaletteGen, add OklchEngine, ShadeGenerator, ColorSystem modules. Update UI.

## Files to Read for Context

1. **`Tools/theme-designer.html`** — Current implementation (read the full file to understand all modules)
2. **`Tools/themes/default.json`** — Current token schema
3. **`docs/visage-theme-designer-spec.md`** — Feature spec with architecture details

## Constraints

- Single-file HTML, vanilla JS/CSS, no frameworks
- Must work via `file://` (no fetch, no external resources)
- All OKLCH math must be inline (no npm packages)
- Embedded Tailwind 4 data adds ~5KB — acceptable
- Keep existing token editing (left panel), preview, inspector, export working
- Don't break the existing preset system — presets should still work alongside the new color system

## Success Criteria

1. Open `Tools/theme-designer.html` — color system panel visible in left sidebar
2. Click a palette → see hue/chroma sliders and shade ramp
3. Change the hue slider → all shades regenerate with correct OKLCH math
4. Click "Apply to Theme" → preview updates with new colors
5. Change mode Dark → Light → click Apply → preview shows light theme
6. Export → C++ Header → correct `0xAARRGGBB` values generated
7. Save color system → download `.colorsystem.json`
8. Import color system → loads and applies correctly
9. All existing features (token editing, inspector, undo, presets) still work

## Additional Templates (Phase 2)

Beyond Tailwind 4, add these templates by converting their published hex values to OKLCH using the OklchEngine. The hex values for these systems are publicly documented:

- **Material Design** (19 palettes) — from material.io/design/color. Families: red, pink, purple, deep-purple, indigo, blue, light-blue, cyan, teal, green, light-green, lime, yellow, amber, orange, deep-orange, brown, gray, blue-gray
- **Radix UI** (31 palettes) — from radix-ui.com/colors. Uses 12 shades per family instead of 11.
- **Bootstrap** (11 palettes) — blue, indigo, purple, pink, red, orange, yellow, green, teal, cyan, gray
- **Audio Studio** (custom, 6 palettes) — specifically designed for dark audio plugin UIs: accent (violet), neutral (slate-blue), success (green), warning (amber), error (red), info (cyan)

For Phase 1, ship only Tailwind 4 + Audio Studio. Add others in follow-up.

## Implementation Order

1. First: `OklchEngine` module (pure math, no UI)
2. Second: `ShadeGenerator` module (uses OklchEngine)
3. Third: `ColorSystem` data model + save/load
4. Fourth: UI panel (replace PaletteGen HTML + CSS)
5. Fifth: Wire Apply to Theme (semantic role → TokenRegistry)
6. Sixth: Add OKLCH CSS export tab
7. Seventh: Embed Tailwind 4 + Audio Studio template data
8. Last: Test everything, verify all existing features still work
