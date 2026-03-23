# Ralph Loop v2: AI Style Designer — Real Agent Connection + Polish

## Status
Phases 0-3c COMPLETE. This loop continues with Phases 4-6.

## Branch
feature/ai-style-designer

## Key Files
- Tools/theme-designer.html — theme designer with chat UI (4500+ lines)
- tauri/src-tauri/src/lib.rs — Rust IPC commands
- tauri/sidecar/agent.mjs — Node.js sidecar for Claude agent
- tauri/sidecar/package.json — sidecar dependencies
- tauri/docs/proposal/work-items.md — progress tracker
- tauri/docs/LEARNINGS.md — learnings
- docs/ai-style-designer-phase4-spec.md — detailed Phase 4-6 spec

## References
- /Users/danielraffel/Code/PlunderTube/node_modules/@anthropic-ai/claude-code/ — SDK types
- /Users/danielraffel/Code/mcp-tauri-automation — Tauri testing MCP
- /Users/danielraffel/Code/tauri-plugin-webdriver — WebDriver plugin
- https://platform.claude.com/docs/en/agent-sdk/overview — SDK docs

## Phase 4: Real Agent Connection

- [ ] 4.1 cd tauri/sidecar and pnpm install @anthropic-ai/claude-code. Verify the SDK loads.
- [ ] 4.2 Add model dropdown to chat header UI: Opus 4.6 (default, model id claude-opus-4-6) and Sonnet 4.6 (model id claude-sonnet-4-6). Persist selection in localStorage.
- [ ] 4.3 Rewrite tauri/sidecar/agent.mjs:
  - Read JSON payload from stdin (not CLI args — payloads are large)
  - import { query } from @anthropic-ai/claude-code
  - Call query() with prompt, model from payload, customSystemPrompt about style system
  - Stream NDJSON lines to stdout (one JSON object per line)
  - System prompt teaches Claude about the full style system JSON format
- [ ] 4.4 Update Rust lib.rs chat_send:
  - Use tokio::process::Command to spawn node sidecar/agent.mjs
  - Write payload JSON to child stdin
  - Read stdout line-by-line
  - Emit each line as a Tauri event to frontend
  - Return final accumulated response
- [ ] 4.5 Update frontend ChatUI.callAgent:
  - In Tauri mode: listen for streamed events via __TAURI__.event.listen
  - Accumulate assistant text messages
  - Extract JSON diff from the final result message
  - Apply diff to StyleSystem and preview
- [ ] 4.6 Add settings panel accessible from gear icon:
  - Agent status check (calls chat_health)
  - Model selection
  - Auth status and instructions
- [ ] 4.7 Error handling:
  - Sidecar missing: install instructions in chat
  - Auth failure: Claude Code login instructions
  - Timeout 60s: error with retry button
  - JSON parse failure: show raw response
- [ ] 4.8 Commit Phase 4

## Phase 5: Testing

- [ ] 5.1 Research and add tauri-plugin-webdriver or mcp-tauri-automation setup
- [ ] 5.2 Configure automation mode in tauri.conf.json
- [ ] 5.3 Write E2E tests: app launch, chat send, model select, context badge, export
- [ ] 5.4 Commit Phase 5

## Phase 6: Polish

- [ ] 6.1 Parse agent response: separate explanation text from JSON diff
- [ ] 6.2 Show change summary in chat: "Updated 5 properties: button rounding..."
- [ ] 6.3 Capture real preview thumbnail after style change
- [ ] 6.4 Display thumbnail in chat, clickable to restore state
- [ ] 6.5 A/B compare between two chat thumbnail versions
- [ ] 6.6 Commit Phase 6

## Codex Delegation (Optional)
- Good: tests, code review, isolated components
- Bad: shared files, needs conversation context

## Testing and Automation
- Use native Tauri app for verification, not browser
- mcp-tauri-automation and tauri-plugin-webdriver for E2E
- May need repo-specific integration work

## Each Iteration Must
1. Re-read tauri/CLAUDE.md
2. Re-read tauri/docs/proposal/work-items.md
3. Check tauri/docs/LEARNINGS.md
4. Identify next incomplete Phase 4-6 item
5. Implement it
6. Write tests when applicable
7. Verify build: cd tauri/src-tauri && cargo build
8. Add learnings to LEARNINGS.md
9. Commit
10. Update work-items.md
11. Re-check remaining

## Completion Condition
- All Phase 4, 5, 6 items complete
- Chat connects to real Claude agent (not mock)
- Model selection works (Opus 4.6 / Sonnet 4.6)
- Style diffs apply to preview live
- Tests pass
- Code builds

## Success Criteria
- Type "warm analog synth" → Claude responds → preview updates with warm rounded style
- Model dropdown switches between Opus 4.6 and Sonnet 4.6
- Cmd+click knob → type "more metallic" → only knobs change
- Clear button (x) returns to "Editing: All Components"
- Click chat thumbnail → restores that version
- Settings shows connection status
- No API key needed

ONLY WHEN ALL CONDITIONS ARE MET, output: DONE

--completion-promise "DONE" --max-iterations 120
