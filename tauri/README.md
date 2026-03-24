# AI Style Designer

A Tauri 2 desktop app that lets you describe visual styles for audio plugin UIs in natural language. Type "80s Macintosh" or "neon cyberpunk" and watch the entire component showcase transform — colors, widget shapes, shadows, typography, everything.

Built on top of the [JUCE-Plugin-Starter](https://github.com/danielraffel/JUCE-Plugin-Starter) theme designer. Uses your existing Claude Max subscription via the `claude` CLI — no API key needed.

**Branch:** `feature/ai-style-designer`

## What It Does

- Type a style description ("warm analog synth", "Apple Aqua", "minimal Dieter Rams") and the preview updates live
- Changes **everything**: 36+ color tokens, widget geometry, knob rendering style, button depth, toggle shape, shadows, typography
- Each chat response includes a snapshot — click "Restore this style" to get back to any previous state
- Cmd+click a component to scope prompts to just that widget type
- Export to JSON, CSS vars, C++ Visage headers, C++ Palette code, OKLCH CSS, or Style System JSON

### Widget Style Modes

The AI doesn't just change colors — it changes how widgets are drawn:

| Knob Styles | Button Styles | Toggle Styles |
|---|---|---|
| `arc` — thin arc with thumb dot | `flat` — borderless (default) | `pill` — rounded iOS-style |
| `filled` — pie-wedge fill with pointer | `raised` — 3D with inset shadow | `checkbox` — square with check |
| `notched` — tick marks around edge | `outlined` — transparent with border | `rocker` — angular rocker switch |
| `glossy` — 3D gradient sphere | `glossy` — glass-like gradient | |
| | `beveled` — classic 3D bevel | |

## Prerequisites

- **macOS** (Tauri 2 + WebKit)
- **Rust** toolchain (`rustup`)
- **Claude Code CLI** installed and authenticated with a Max subscription
  ```bash
  # Install Claude Code if you don't have it
  npm install -g @anthropic-ai/claude-code
  # Verify it's authenticated
  claude --version
  ```

## Getting Started

```bash
# Clone and switch to the feature branch
git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter
git checkout feature/ai-style-designer

# Install frontend dependencies (minimal — just Tauri CLI)
cd tauri
pnpm install   # or npm install

# Run in development mode
pnpm tauri dev
```

The app opens a window with the theme designer. Click the **Chat** tab on the right panel and start describing styles.

### Build for Production

```bash
cd tauri
pnpm tauri build
```

The built app is at `tauri/src-tauri/target/release/bundle/`.

## How It Works

### Architecture

```
Tools/theme-designer.html     Frontend (vanilla JS/CSS, single file)
    |
    | Tauri IPC (invoke)
    v
tauri/src-tauri/src/lib.rs     Rust backend
    |
    | spawns process
    v
claude --print -p "..."        Claude CLI (uses Max subscription auth)
    |
    | JSON response
    v
Frontend applies diff           Colors via TokenRegistry, geometry via StyleSystem,
                                 widget styles via CSS data-attributes + canvas modes
```

1. **Frontend** builds a context payload containing current color tokens + style system state
2. **Rust backend** prepends a system prompt that describes all available tokens, widget styles, and includes full examples
3. **Claude CLI** returns a natural language explanation + JSON diff
4. **Frontend** applies the diff: colors update via `TokenRegistry.setColor()`, geometry via `StyleSystem.applyToCSS()`, widget modes via data-attributes and canvas redraw
5. **Snapshot** is captured (all colors + style system + widget styles) for later restore

### Key Files

| File | Purpose |
|---|---|
| `Tools/theme-designer.html` | Single-file frontend (~5000 lines, vanilla JS/CSS) |
| `tauri/src-tauri/src/lib.rs` | Rust backend: system prompt, `chat_send` IPC command |
| `Tools/themes/default.json` | Default color tokens (36 Visage + 13 values + 48 custom) |
| `Tools/themes/default.stylesystem.json` | Default geometry, effects, gradients, typography |
| `scripts/generate_theme.py` | C++ codegen for Visage headers and Palette init |

### Export Formats

| Tab | Output | Use Case |
|---|---|---|
| JSON | Full theme JSON | Import/export between sessions |
| CSS Vars | `:root { --vt-*, --jt-* }` | Web/CSS projects |
| C++ Header | `VISAGE_THEME_COLOR()` macros | Visage plugin themes |
| C++ Palette | `palette.setColor()` calls | Runtime Visage palette init |
| OKLCH CSS | OKLCH color system variables | Modern CSS color workflows |
| Style System | Geometry/effects/typography JSON | Widget shape and layout config |

### Browser Mode (No Tauri)

Open `Tools/theme-designer.html` directly in a browser. Without Tauri, it runs a mock agent that responds to keywords like "round", "80s macintosh", "neon cyberpunk", "warm analog" with pre-built style diffs. Useful for frontend development without the Rust backend.

## Current Limitations

- **Text-only prompts** — image upload UI exists but images aren't sent to Claude (the CLI's `--print` mode doesn't support image input). Text descriptions work well for most styles.
- **No streaming** — Claude response comes back all at once after ~10-30 seconds. The typing indicator shows while waiting.
- **Single-turn** — each prompt is independent. Claude doesn't remember previous messages in the conversation (no multi-turn context).
- **macOS only** — Tauri 2 WebKit. Windows/Linux would need testing.
- **Local WebDriver dep** — `tauri-plugin-webdriver` is referenced by local path for automated testing. Remove or adjust for CI.

## Development

```bash
# Run with hot reload
cd tauri && pnpm tauri dev

# Check Rust compiles
cargo check --manifest-path tauri/src-tauri/Cargo.toml

# Test in browser (mock agent, no Tauri needed)
open Tools/theme-designer.html
```

### Automated Testing

The app includes `tauri-plugin-webdriver` (debug builds only) on port 4444. With the [mcp-tauri-automation](https://github.com/anthropics/mcp-tauri-automation) MCP:

```bash
# Launch with WebDriver
TAURI_WEBDRIVER_PORT=4444 ./tauri/src-tauri/target/debug/app

# Then use mcp-tauri-automation tools:
# launch_app, click_element, type_text, execute_script, capture_screenshot
```
