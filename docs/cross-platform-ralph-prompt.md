You are adding cross-platform support to the JUCE-Plugin-Starter template and juce-dev Claude Code plugin.

GOVERNING RULES:
- The file CLAUDE.md defines build conventions and project structure. Read it at the start of EVERY iteration.
- Do NOT modify files in /Users/danielraffel/Code/pamplejuce/ - it is a read-only reference for cross-platform patterns.
- All work happens on feature branches, never on main. Branch names are specified in the plan.
- Every change to JUCE-Plugin-Starter must also consider the juce-dev plugin and vice versa.

SOURCE OF TRUTH:
- docs/cross-platform-plan.md defines required work items and tracks progress.
- docs/cross-platform-learnings.md tracks development learnings, gotchas, and improvement opportunities.

REFERENCE PROJECTS (read-only, for patterns):
- /Users/danielraffel/Code/pamplejuce/ - Cross-platform JUCE template with CI/CD, Windows signing, CLAP, Catch2
- /Users/danielraffel/Code/visage/ - GPU UI framework (Metal/DirectX/Vulkan backends)

WORKING REPOS:
- /Users/danielraffel/Code/JUCE-Plugin-Starter - Template repo (Starter)
- /Users/danielraffel/Code/generous-corp-marketplace/plugins/juce-dev - Claude Code plugin (juce-dev)
- /Users/danielraffel/Code/visage - Visage fork (for bridge work only)

TASK:
- Read docs/cross-platform-plan.md at the start of EVERY iteration.
- Identify the NEXT item with `[ ]` status, in sequential order.
- Implement it.
- Update docs/cross-platform-plan.md: mark `[~]` when starting, `[x]` when complete, `[!]` if blocked.

EXECUTION ORDER:
- Items MUST be completed in sequential order: 1.1 -> 1.2 -> 1.3 -> 1.4 -> 1.5 -> 1.6 -> 2.1 -> 2.2 -> 2.3 -> 2.4 -> 2.5 -> 2.6 -> 2.7 -> 2.8 -> 3.1 -> 3.2 -> 3.3 -> 3.4 -> 3.5 -> 3.6 -> 3.7.
- Phase 4 items (4.1, 4.2) are tracked but deferred. Do NOT work on them.
- If an item is blocked, mark it `[!]` with a clear note explaining WHY and whether it needs human intervention. Then continue to the NEXT item immediately - do not stop progress.
- Before starting Phase 2, ALL Phase 1 items must be `[x]` or `[!]`.
- Before starting Phase 3, ALL Phase 2 items must be `[x]` or `[!]`.
- `[!]` items are acceptable at phase boundaries. They don't prevent moving forward.
- See Blocker Handling section in docs/cross-platform-plan.md for expected blockers.

IMPLEMENTATION RULES:
- Local-first: everything must work without cloud services. CI/CD is opt-in.
- Existing macOS workflows must not break. Test builds after changes.
- When updating CMakeLists.txt or build.sh, verify the macOS build still works.
- When touching the juce-dev plugin, ensure commands/skills stay consistent with CLI scripts.
- README updates (1.5, 1.6, 2.7, 2.8, 3.6, 3.7) should document ALL features, not just new ones.
- Use the reference project for patterns (CI workflows, CLAP integration, Catch2 setup, Windows signing) but adapt to our architecture (FetchContent not submodules, .env config, template-based project creation).

CODEX DELEGATION:
- Use /codex <task> for parallel work when it would speed things up.
- Delegation rules are in docs/cross-platform-plan.md. Follow them.
- Run Codex in background and continue your own work.
- Check Codex output before marking the work item complete.

LEARNINGS:
- When you discover something non-obvious or encounter a tricky problem, add it to docs/cross-platform-learnings.md.
- Check existing learnings before starting work.

GIT DISCIPLINE:
- Commit at the end of EVERY iteration where changes were made.
- Commits must be small, focused, and aligned to items in cross-platform-plan.md.
- Each work item uses the branch specified in the plan. Create if it doesn't exist.
- Do NOT push to remote unless asked.

EACH ITERATION MUST:
1. Re-read CLAUDE.md
2. Re-read docs/cross-platform-plan.md
3. Check docs/cross-platform-learnings.md for relevant prior learnings
4. Identify the NEXT incomplete item in sequential order
5. Create/switch to the correct branch
6. Implement it
7. Verify macOS build still works (if build system was changed)
8. If anything interesting was learned, add to cross-platform-learnings.md
9. Commit changes
10. Update cross-platform-plan.md status AND the Changelog table with what files changed
11. Summarize what was done and ask for confirmation before proceeding

TESTING:
- Follow the Testing Strategy section in docs/cross-platform-plan.md.
- After any build system change, verify macOS build: `./scripts/build.sh standalone`
- After 1.3, every iteration should run tests: `./scripts/build.sh all test`
- After 2.4, push to feature branch to verify CI passes on all platforms.
- After adding a platform (Windows in 2.1, Linux in 3.1), run a smoke test: dependency install, CMake configure, build, plugin loads.
- Document test results and failures in cross-platform-learnings.md.

COMPLETION CONDITION:
- docs/cross-platform-plan.md contains ZERO `[ ]` items in Phase 1, Phase 2, and Phase 3
- All items are `[x]` or `[!]` with documented blockers
- macOS builds still work
- Windows and Linux builds work (or blockers documented)
- Tests pass on all configured platforms
- READMEs are comprehensive and up to date
- cross-platform-learnings.md has been maintained throughout

ONLY WHEN ALL CONDITIONS ARE MET:
Output exactly: DONE

IF STUCK:
- After 10 iterations without progress, document in cross-platform-learnings.md:
  - What is blocked
  - Why
  - What was attempted
  - What assumption may be wrong
