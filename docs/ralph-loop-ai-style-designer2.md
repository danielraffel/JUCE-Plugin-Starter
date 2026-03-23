# Ralph Loop v2: AI Style Designer — Real Claude Agent + Polish

## Status
Phases 0-3c COMPLETE. This loop continues with Phases 4-6.

## Branch
feature/ai-style-designer

## Key Files
- Tools/theme-designer.html — theme designer with chat UI
- tauri/src-tauri/src/lib.rs — Rust IPC commands
- tauri/docs/proposal/work-items.md — progress tracker
- docs/ai-style-designer-phase4-spec.md — detailed spec

## CRITICAL: Auth Approach
Use the claude CLI directly. It uses the user's Max subscription. NO API key. NO Node.js sidecar.
Command: claude --output-format stream-json --model MODEL --print -p "PROMPT"

## Phase 4: Real Agent Connection
- [ ] 4.1 Verify claude CLI works: spawn claude --version from Rust
- [ ] 4.2 Add model dropdown to chat header: Opus 4.6 default, Sonnet 4.6 option. Persist in localStorage.
- [ ] 4.3 Rewrite Rust chat_send: spawn claude CLI directly, prepend style system prompt, stream NDJSON stdout, emit Tauri events
- [ ] 4.4 Frontend: listen for Tauri streamed events, accumulate text, extract JSON diff, apply to StyleSystem
- [ ] 4.5 Settings: claude CLI status check, model selection
- [ ] 4.6 Error handling: CLI not found, timeout 60s, parse failure
- [ ] 4.7 Commit Phase 4

## Phase 5: Testing
- [ ] 5.1 Add tauri-plugin-webdriver for E2E testing
- [ ] 5.2 Write E2E tests: app launch, chat send, model select, context badge
- [ ] 5.3 Commit Phase 5

## Phase 6: Polish
- [ ] 6.1 Parse agent response: separate explanation from JSON diff
- [ ] 6.2 Show change summary in chat
- [ ] 6.3 Preview thumbnails after style changes, clickable to restore
- [ ] 6.4 A/B compare between versions
- [ ] 6.5 Commit Phase 6

## Each Iteration Must
1. Re-read tauri/CLAUDE.md
2. Re-read tauri/docs/proposal/work-items.md
3. Check LEARNINGS.md
4. Identify next item
5. Implement it
6. Verify build: cd tauri/src-tauri && cargo build
7. Commit and update work-items.md

## Completion Condition
- All Phase 4-6 items complete
- Chat sends prompts to real claude CLI and receives style diffs
- Model selection works
- No API key needed
- Code builds

## Success Criteria
- Type warm analog synth -> Claude responds -> preview updates
- Model dropdown works
- Cmd+click knob -> type more metallic -> only knobs change
- Clear button returns to All Components
- Click thumbnail restores version

ONLY WHEN ALL CONDITIONS ARE MET: DONE
--completion-promise "DONE" --max-iterations 120
