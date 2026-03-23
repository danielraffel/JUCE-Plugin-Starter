# Ralph Loop v2: Color System Polish

## Context

The OKLCH color system editor is built and functional. This loop focuses on polish to match supacolors.studio quality and fix real usability issues.

Reference screenshots from supacolors are in the conversation history. Key differences to close:

## Phases

### Phase 1: Fix Live Preview (CRITICAL)

The gamut triangle drag and hue slider do NOT update the plugin preview in real-time. The `applyLive()` call exists in `render()` but the slider/drag handlers bypass `render()` for performance and do their own inline updates — which skip `applyLive()`.

**Fix:** After every palette change (slider input, gamut drag, numeric input change, harmony change, mode change, template change), call `ColorSystemModel.applyLive(mode)`. This must happen in:
- The `.cs-slider` input handler (hue slider) — currently only updates shade swatches inline
- The `GamutPicker.initDrag` callback — currently only updates dot position and shade swatches
- The `.cs-oklch-input` change handler — currently calls `this.render()` which does apply, but is slow

Make ALL of these call `applyLive()` so the plugin preview updates as you drag. Do NOT call `render()` during drag — that's too expensive. Only update CSS vars + canvas redraws.

### Phase 2: Triangular Gamut Shape

Current gamut picker is rectangular. Supacolors shows a proper triangular shape where:
- Top vertex = white (L=1, C=0)
- Bottom-left vertex = black (L=0, C=0)
- Right boundary = maximum chroma curve (varies by lightness)
- Out-of-gamut area is dark/transparent

**Implementation:**
1. In `GamutPicker.draw()`, after rendering pixels, draw the gamut boundary as a filled path
2. Use `ctx.globalCompositeOperation = 'destination-in'` to clip to the triangular shape
3. Or: render the background as dark first, then only draw in-gamut pixels within the triangle

Also add:
- Crosshair lines (horizontal + vertical) through the dot position
- The dot should be a ring (stroke circle, not filled) — white ring with dark shadow

### Phase 3: Second Slider (Chroma)

Supacolors has TWO sliders below the gamut:
1. **Hue slider** — rainbow gradient (we have this)
2. **Chroma/saturation slider** — goes from the current color desaturated (left) to maximum saturation (right)

Add a chroma slider below the hue slider. Its background gradient should show the current hue going from gray to max chroma. When dragged, it updates `baseColor.C`, the gamut dot position, and the preview live.

### Phase 4: Larger Shade Swatches

Current shade swatches are tiny (28px tall, in one row). Supacolors shows them in a 2-row grid (7+4) with ~48px squares, rounded corners, and shade numbers underneath.

**Change:**
- Make shade swatches 40px x 40px with 6px border-radius
- Layout in 2 rows: first row = 50,100,200,300,400,500,600 / second row = 700,800,900,950
- Show shade number under each swatch
- Show WCAG contrast badge INSIDE the swatch (like supacolors)
- Mark the "anchor" shade (500 by default) with a dot inside

### Phase 5: Automatic Contrast / Readability

Text in the preview is sometimes unreadable against its background (e.g., light text on light backgrounds in light mode).

**Solution:** After applying semantic roles, run a contrast check pass:
1. For every text token, find its most likely background token
2. Calculate WCAG contrast ratio
3. If below AA (4.5:1), automatically adjust the text shade darker or lighter until it passes
4. Show warnings in the shade ramp for any shade that has poor contrast

Pairs to check:
- TextPrimary vs PluginBackground
- TextSecondary vs PanelBackground
- UiButtonText vs UiButtonBackground
- PopupMenuText vs PopupMenuBackground
- TooltipText vs TooltipBackground

Reference /Users/danielraffel/Code/Solar for how their theme system handles this — look at SolarTheme.swift and ThemeConfiguration.swift for contrast/foreground logic.

### Phase 6: Remove Apply Button

The "Apply to Theme" button should be removed or changed to "Full Refresh" since everything auto-applies now. It's confusing to have it when changes are supposed to be live.

## Files to Modify

1. `Tools/theme-designer.html` — all changes in this single file

## Success Criteria

1. Drag gamut dot → plugin preview updates in real-time (knobs, buttons, everything)
2. Drag hue slider → preview updates in real-time
3. Change mode Dark/Light → preview updates immediately
4. Gamut area shows triangular shape with proper boundary
5. Two sliders: hue + chroma
6. Shade swatches are large, in 2 rows, with shade numbers and contrast badges
7. Text is always readable against its background
8. No "Apply to Theme" button needed (or renamed to "Full Refresh")
