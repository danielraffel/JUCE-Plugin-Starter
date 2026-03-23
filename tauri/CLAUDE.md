# AI Style Designer — Tauri App

## Project Structure

```
tauri/
├── src/              ← Vanilla HTML/JS/CSS frontend (theme-designer.html)
├── src-tauri/        ← Rust backend (Tauri 2)
│   ├── src/
│   │   ├── main.rs   ← Entry point
│   │   └── lib.rs    ← IPC commands (chat_send, chat_health)
│   ├── Cargo.toml
│   └── tauri.conf.json
├── sidecar/          ← Node.js sidecar for Claude Code Agent SDK
│   ├── agent.mjs     ← Agent server using @anthropic-ai/claude-code
│   └── package.json
├── docs/
│   ├── proposal/
│   │   └── work-items.md
│   └── LEARNINGS.md
├── package.json
└── CLAUDE.md         ← This file
```

## Conventions

- Frontend: vanilla JS/CSS in a single HTML file (theme-designer.html)
- Backend: Rust with Tauri 2 IPC commands
- Agent: Node.js sidecar using `@anthropic-ai/claude-code` SDK
- No React, no framework — keep it simple
- All style data in JSON format (.stylesystem.json)
- CSS custom properties for style values: `--st-*` prefix for style tokens, `--vt-*` for color tokens
- Commits: descriptive messages, one logical change per commit

## Build Commands

```bash
pnpm install          # Install dependencies
pnpm tauri dev        # Development mode (hot reload)
pnpm tauri build      # Production build
pnpm test             # Run tests (if any)
```

## Key Patterns

- Style system extends the v0.1 color system with geometry, effects, gradients, typography
- Chat panel uses Tauri IPC to communicate with the Rust backend
- Rust backend spawns Node.js sidecar for Claude Code Agent SDK
- Agent responses are JSON diffs applied to the current style system
- Each style change auto-captures a preview thumbnail for version history
- Inspector selection scopes agent prompts to specific components
