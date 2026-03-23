# AI Style Designer — Phase 4: Real Claude Agent Connection

## What's Done (Phases 0-3c)
- Tauri 2 app scaffold with theme designer frontend
- Style System JSON format (geometry, effects, gradients, typography)
- Chat UI with Inspector/Chat tabs, image upload, editing context badge
- Mock agent for browser testing
- Rust IPC commands (chat_send, chat_health)
- Node.js sidecar scaffold (tauri/sidecar/agent.mjs)
- Extended export (style system C++ codegen)
- Clear editing context button (x to dismiss component selection)

## What's Needed

### Phase 4: Connect Real Claude Agent

#### 4.1 Use Claude CLI (Max Account Auth)
- Shell out directly to `claude` CLI which uses the user's existing Max account
- NO API key needed — uses existing Claude Code authentication
- CLI invocation: `claude --output-format stream-json --model <model> --print -p "<prompt>"`
- The `--print` flag makes it non-interactive (single turn, no tool use)
- Or use `--output-format json` for a single JSON response
- Auth check: `claude --version` should return version if authenticated
- If not installed: show "Install Claude Code" instructions

#### 4.2 Model Selection UI
- Add model dropdown in chat header (between context badge and Export button)
- Two options only:
  - **Opus 4.6** (default) — "Most capable for ambitious work"
  - **Sonnet 4.6** — "Most efficient for everyday tasks"
- Model selection persisted in localStorage
- Model ID mapping:
  - Opus 4.6 → `claude-opus-4-6`
  - Sonnet 4.6 → `claude-sonnet-4-6`

#### 4.3 Direct Claude CLI Invocation (No Node.js Sidecar Needed)
- Rust backend spawns `claude` CLI directly — no Node.js sidecar required
- Uses the user's Max subscription via existing Claude Code auth
- CLI invocation from Rust:
  ```rust
  let child = Command::new("claude")
    .args(["--output-format", "stream-json", "--model", &model, "--print", "-p", &prompt])
    .stdout(Stdio::piped())
    .spawn()?;
  ```
- The `--print` flag = non-interactive single turn
- `--output-format stream-json` = NDJSON streaming on stdout
- `--model claude-opus-4-6` or `--model claude-sonnet-4-6`
- System prompt prepended to the user prompt with style system context
- No API key, no sidecar, no Node.js dependency for the agent

#### 4.4 Rust Backend Streaming
- Rust spawns Node.js sidecar via `tokio::process::Command`
- Reads stdout line-by-line (NDJSON)
- Forwards each line to the frontend via Tauri events
- Frontend accumulates the response and extracts the final JSON diff

#### 4.5 Settings Panel
- Accessible from a gear icon in the toolbar or chat header
- Shows:
  - Agent status (connected/disconnected)
  - Node.js version
  - Claude Code auth status
  - Model selection (Opus 4.6 / Sonnet 4.6)
  - "Authenticate with Claude Code" button if not logged in

#### 4.6 Error Handling
- If sidecar not installed: show "Install sidecar" instructions
- If Claude Code not authenticated: show auth instructions
- If model unavailable: fall back to Sonnet 4.6
- Timeout after 60 seconds: show error in chat
- Network errors: show retry button in chat

### Phase 5: Tauri WebDriver Testing

The tauri-plugin-webdriver plugin provides full W3C WebDriver compliance. Zero config — just register the plugin and it starts a server on port 4445.

#### 5.1 Enable WebDriver in Tauri
- Add `tauri-plugin-webdriver` (from `/Users/danielraffel/Code/tauri-plugin-webdriver`) as dependency
- Register in lib.rs: `builder.plugin(tauri_plugin_webdriver::init())` (debug builds only)
- The plugin auto-starts a WebDriver server on `127.0.0.1:4445`
- Works on macOS (WKWebView), Windows (WebView2), Linux (WebKitGTK)

#### 5.2 MCP-Based Testing
- The `mcp-tauri-automation` MCP server can control the app via Claude Code
- Tools: launch_app, click_element, type_text, capture_screenshot, execute_script
- Can run Tauri IPC commands via execute_tauri_command

#### 5.3 E2E Test Suite
- Test: app launches and shows theme designer
- Test: chat tab switch works
- Test: typing in chat input and sending
- Test: model selection dropdown
- Test: editing context badge shows/clears
- Test: export modal opens

### Phase 6: Polish

#### 6.1 Clear Editing Context
- ✅ Already done — x button next to "Editing: Rotary Knob" clears to "All Components"

#### 6.2 Agent Response Parsing
- Extract JSON diff from Claude's response (may include markdown/explanation)
- Show the explanation text in the chat bubble
- Apply only the JSON diff to the style system
- Show a summary: "Updated 5 properties: button rounding, shadow blur, ..."

#### 6.3 Preview Thumbnails
- After applying a style diff, capture the preview area as a thumbnail
- Display inline in chat below the agent response
- Click to restore that style snapshot
- Use html2canvas or canvas snapshot of the preview area

#### 6.4 Version Comparison
- Click two thumbnails to compare them side-by-side
- Reuse the A/B compare feature from the color system

## Implementation Notes

### Claude Code Agent SDK Authentication
The SDK uses the existing Claude Code configuration:
- If the user has Claude Code installed and logged in, the SDK works immediately
- Auth is stored in `~/.claude/` (managed by Claude Code)
- No separate API key needed
- The user's Claude Max plan determines rate limits

### Model IDs
- `claude-opus-4-6` — Opus 4.6 (latest, 1M context)
- `claude-sonnet-4-6` — Sonnet 4.6 (fast, efficient)

### Payload Format (stdin to sidecar)
```json
{
  "prompt": "Make the knobs more skeuomorphic",
  "styleJSON": "{ ... current style system ... }",
  "selectedComponent": "Rotary Knob",
  "model": "claude-opus-4-6",
  "image": null
}
```

### Response Format (stdout from sidecar, NDJSON)
```
{"type":"assistant","message":{"content":[{"type":"text","text":"I'll make..."}]}}
{"type":"result","result":"{\"geometry\":{\"knob\":{\"arcWidth\":6}}}"}
```

## Work Items to Add to work-items.md

### Phase 4: Real Agent Connection
- [ ] 4.1 Install @anthropic-ai/claude-code in sidecar, verify auth
- [ ] 4.2 Add model dropdown (Opus 4.6 / Sonnet 4.6) to chat header
- [ ] 4.3 Rewrite agent.mjs to use stdin for payload, query() for agent call
- [ ] 4.4 Rust backend: stream sidecar stdout via Tauri events
- [ ] 4.5 Frontend: accumulate streamed response, extract JSON diff
- [ ] 4.6 Settings panel with agent status, auth check, model selection
- [ ] 4.7 Error handling (no sidecar, no auth, timeout, retry)
- [ ] 4.8 Commit Phase 4

### Phase 5: Testing
- [ ] 5.1 Add tauri-plugin-webdriver dependency
- [ ] 5.2 Configure automation mode in tauri.conf.json
- [ ] 5.3 Write E2E tests (app launch, chat, model select, export)
- [ ] 5.4 Commit Phase 5

### Phase 6: Polish
- [ ] 6.1 Parse agent response: extract JSON diff + explanation text
- [ ] 6.2 Show change summary in chat ("Updated 5 properties...")
- [ ] 6.3 Preview thumbnails after style changes
- [ ] 6.4 Click thumbnails to restore snapshots
- [ ] 6.5 Version comparison (A/B with thumbnails)
- [ ] 6.6 Commit Phase 6
