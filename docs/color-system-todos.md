# Color System Editor — Remaining TODO Items

## Critical Fixes

- [ ] 1. **Live preview on ALL interactions** — Verify every slider, dropdown, and drag updates the plugin preview in real-time. Test: hue slider, chroma slider, gamut drag, mode dropdown, harmony dropdown, template dropdown. Fix any path that doesn't call applyLive().

- [ ] 2. **Export modal works** — Verify clicking Export button opens modal, all 6 tabs generate content, Copy button works on file://, Download button saves correct file type.

- [ ] 3. **Import works** — Verify Import button opens file picker, loading a .json theme applies it correctly.

- [ ] 4. **Save/Load color system works** — Verify Save downloads .colorsystem.json, Load imports and applies it.

## Color Picker Polish (match supacolors)

- [ ] 5. **Triangular gamut clipping** — Clip the gamut canvas to the actual triangle shape (white top-left, black bottom-left, max chroma right). Out-of-gamut area should be dark/transparent, not filled with colors.

- [ ] 6. **Higher resolution gamut rendering** — Current step=2 pixels looks blocky. Use step=1 or render at canvas resolution with ImageData for smooth gradients.

- [ ] 7. **HEX/RGB/HSL/OKLCH format dropdown** — Add a dropdown next to the L/C/H inputs that switches between display formats: HEX (#AA88FF), RGB (R:170 G:136 B:255), HSL (H:260 S:100% L:77%), OKLCH (L:60.6 C:0.25 H:292.7). Default to OKLCH.

- [ ] 8. **Chroma slider gradient updates dynamically** — When hue or lightness changes, the chroma slider background gradient should update to show the current color going from gray to max saturation.

- [ ] 9. **Ring dot style** — The gamut dot should be a hollow ring (white circle outline with shadow), not a filled dot. Match supacolors' dot style.

- [ ] 10. **Crosshair lines** — Horizontal and vertical guide lines through the dot position on the gamut canvas, like supacolors.

## Shade Swatches Polish

- [ ] 11. **2-row grid layout** — Shades in two rows: first row = 50,100,200,300,400,500,600 / second row = 700,800,900,950. Match supacolors' 7+4 layout.

- [ ] 12. **Larger swatches** — Each swatch ~40-48px square with 8px rounded corners.

- [ ] 13. **Anchor dot on base shade** — Show a white dot inside the anchor shade (500 by default) like supacolors.

- [ ] 14. **Click shade to override** — Clicking a shade swatch should open a mini color picker to override that specific shade. Show an indicator (different border) for overridden vs auto-generated shades.

- [ ] 15. **"Shades" label** — Add a "Shades" heading above the swatch grid and the text "Click a shade to override its generated color, or modify the base color to regenerate the entire palette." below.

## Templates

- [ ] 16. **Capture Material Design template** — Delete current supacolors system, create new with Material UI template, export CSS, capture OKLCH values, add as template option.

- [ ] 17. **Capture Radix UI template** — Same process for Radix (31 palettes, 12 shades per family).

- [ ] 18. **Capture Bootstrap template** — Same for Bootstrap (11 palettes).

- [ ] 19. **Add Audio Studio Pro template** — A curated template specifically for dark audio plugin UIs with 8 palettes: accent, accent-secondary, neutral-warm, neutral-cool, success, warning, error, info.

## Accessibility

- [ ] 20. **"Aa" accessibility button** — Add an Aa button next to the chroma slider that shows a preview of the current color as text on white and black backgrounds with contrast ratios.

- [ ] 21. **Contrast warnings in preview** — When text/background combinations in the plugin preview fail WCAG AA, show a small warning icon on the affected component.

## UX Improvements

- [ ] 22. **Remove "Apply to Theme" button** — Everything should auto-apply. Keep only "Generate Opposite Mode", "Save", "Load".

- [ ] 23. **Palette reordering** — Ability to drag palettes to reorder them in the list.

- [ ] 24. **Add/remove palettes** — Button to add a new custom palette, and ability to delete palettes (except the required accent/neutral).

- [ ] 25. **Color system name editing** — Editable name field for the color system (not just the theme name in the toolbar).

## Implementation Order for Ralph Loop

Phase A: Items 1-4 (critical fixes — verify everything works)
Phase B: Items 5-10 (color picker polish)
Phase C: Items 11-15 (shade swatches polish)
Phase D: Item 22 (remove Apply button)
Phase E: Items 7, 20 (format dropdown + Aa button)
Phase F: Items 16-19 (templates — requires supacolors interaction via chrome-devtools)
Phase G: Items 21, 23-25 (remaining UX)
