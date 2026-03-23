# JUCE+Visage Integration Notes — JUCE Plugin Starter

<!-- This file is used by the juce-visage Claude skill. -->
<!-- It stores project-specific Visage integration details. -->
<!-- Fill in sections as you build out your Visage integration. -->

## Bridge Layer Files

| File | Purpose |
|------|---------|
| <!-- e.g. Source/Visage/Bridge.h/cpp --> | <!-- Primary bridge: window, events, focus --> |

## Visage Patches Applied

- [ ] `performKeyEquivalent:` (windowing_macos.mm) — Cmd+A/C/V/X/Z for TextEditor in plugins
- [ ] Cmd+Q propagation (windowing_macos.mm) — `[[self nextResponder] keyDown:event]`
- [ ] MTKView 60 FPS cap (windowing_macos.mm) — Prevent excessive GPU on ProMotion displays
- [ ] Popup menu overflow positioning (popup_menu.cpp) — Above-position fix
- [ ] Single-line Up/Down arrows (text_editor.cpp) — Up→start, Down→end
- [ ] setAlwaysOnTop guard (application_window.cpp) — Only call when always_on_top_ is true

## Destruction Sequence

<!-- Document your plugin editor destructor ordering here -->
<!-- Example:
1. Stop timers
2. shutdownRendering()
3. Destroy overlays/modals
4. Destroy panels
5. Disconnect bridge from frame tree
6. removeAllChildren()
7. Destroy root frame
8. Destroy bridge
-->

## PopupMenu Instances

<!-- List all visage::PopupMenu usage locations -->

## Dropdown Instances

<!-- List all VisageDropdownComboBox usage locations -->

## Modal Dialog Instances

<!-- List all VisageModalDialog::show() and VisageOverlayBase usage locations -->

## JUCE AlertWindow Exceptions

<!-- List any places where JUCE native UI is used instead of Visage, with justification -->

## Known Technical Debt

<!-- Track Visage-related technical debt items -->

## Project-Specific Learnings

<!-- Debugging insights, workarounds, and patterns specific to this project -->
