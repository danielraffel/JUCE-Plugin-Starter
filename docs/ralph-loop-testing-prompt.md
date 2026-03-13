You are completing cross-platform testing, PlunderTube porting, and juce-dev plugin work across Windows and Ubuntu VMs.

GOVERNING RULES:
- The file CLAUDE.md defines build conventions and project structure. Read it at the start of EVERY iteration.
- Do NOT modify files in /Users/danielraffel/Code/pamplejuce/ - it is a read-only reference.
- All work happens on feature branches, never on main.
- Visage is FULLY CROSS-PLATFORM (Metal/D3D11/Vulkan/WebGL via bgfx). NEVER disable Visage on non-macOS platforms.

SOURCE OF TRUTH:
- docs/cross-platform-testing-plan.md defines required work items and tracks progress.
- docs/cross-platform-learnings.md tracks development learnings and gotchas.
- docs/cross-platform-plan.md tracks the original plan (items 2.3 and 3.2 are still open).

VM ACCESS:
- Windows ARM64: ssh win (user: daniel, VS2022 + MSVC ARM64, UTM VM)
- Ubuntu 24.04 ARM64: ssh ubuntu (user: daniel, UTM VM)
- Use .bat scripts with VsDevCmd.bat for Windows builds over SSH (avoids quoting issues).
- SSH connectivity has been verified for both VMs.

CODEBASE SEARCH:
- Use RepoPrompt tools (mcp__RepoPrompt__file_search, mcp__RepoPrompt__context_builder, mcp__RepoPrompt__get_file_tree) regularly for searching large codebases like PlunderTube and Visage.
- Use context_builder with response_type="plan" before complex changes.
- Use context_builder with response_type="review" after making changes.
- Use file_search instead of Grep/Glob for cross-file analysis — it combines content, path, and regex search.

WORKING REPOS:
- /Users/danielraffel/Code/PlunderTube - Active plugin being ported (branch: feature/windows-build)
- /Users/danielraffel/Code/JUCE-Plugin-Starter - Template repo (branch: feature/cross-platform-audit)
- /Users/danielraffel/Code/generous-corp-marketplace/plugins/juce-dev - Claude Code plugin (branch: feature/port-command)
- /Users/danielraffel/Code/visage - Visage fork (read-only reference for bridge patterns)

TASK:
- Read docs/cross-platform-testing-plan.md at the start of EVERY iteration.
- Identify the NEXT incomplete item following the Execution Order section.
- Implement it.
- Update docs/cross-platform-testing-plan.md: mark as in-progress when starting, done when complete, blocked if stuck.

EXECUTION ORDER (STRICT):
Priority 1: A.1 (test shaderc on ARM64 Windows). If blocked, go to F.1/F.2.
Priority 2: C.1-C.4 (Windows VM template testing) — parallel with A.
Priority 3: A.2-A.6 (PlunderTube Windows port) — depends on A.1 or F.1.
Priority 4: E.1-E.3 (juce-dev port command finalize and merge) — MUST land BEFORE Phase H.
Priority 5: D.1-D.4 (Visage bridge research and implementation).
Priority 6: G.1-G.5 (Ubuntu VM template testing) — MUST pass BEFORE Phase H.
Priority 7: H.1-H.7 (PlunderTube Linux port using /juce-dev:port) — requires E.3 + G.5.
Priority 8: E.4 (final branch merges).

CRITICAL DEPENDENCY: Phase H (PlunderTube Linux port) CANNOT start until:
  1. Phase E is complete (port command merged to master)
  2. Phase G is complete (template verified on Ubuntu VM)
Use /juce-dev:port to drive the Linux audit in H.1.

WINDOWS BUILD PATTERN (use .bat files to avoid SSH quoting):
Write a .bat file on the Windows VM using PowerShell Set-Content via SSH, containing:
  - Call VsDevCmd.bat with -arch=arm64 -host_arch=arm64
  - cd to the project directory
  - Run cmake configure and build commands
Then execute the .bat file via a second SSH command.
See docs/cross-platform-learnings.md for the full pattern with proper escaping.

UBUNTU BUILD PATTERN:
SSH into ubuntu, cd to the project, then run cmake configure (with clang) and build in a single command.
See docs/cross-platform-learnings.md for the full command.

GITHUB ACTIONS FALLBACK (Phase F):
If ARM64 VM shaderc fails:
- GitHub Actions windows-latest is x86-64 (pre-built shaderc works)
- GitHub Actions also has native ARM64 Windows runners (free for public repos since Aug 2025)
- Create .github/workflows/build.yml for PlunderTube
- Use CI for verification while documenting ARM64 VM limitations

IMPLEMENTATION RULES:
- Existing macOS workflows must not break.
- When porting PlunderTube: fix compilation errors one file at a time, commit incrementally.
- For bundled binaries (yt-dlp, ffmpeg, etc.): download official Windows/Linux builds, do not compile from source.
- Essentia prebuilt libs are macOS arm64 only — guard with if(APPLE) in CMakeLists.txt.
- All cross-platform tools the user chose (yt-dlp, ffmpeg, deno, aria2c, uv, Essentia) have Windows and Linux versions.

CODEX DELEGATION:
- Use /codex for parallel research tasks.
- Use /codex for code review of port changes.
- Do NOT delegate VM SSH operations to Codex (it cannot SSH).

LEARNINGS:
- Check docs/cross-platform-learnings.md before starting any work.
- Add new learnings when you discover something non-obvious.
- Key known issues:
  - bgfx pre-built shaderc.exe is x86-64, crashes on ARM64 Windows
  - Building shaderc from source should work (CPU-only tool, no GPU needed)
  - D3DCompiler_47.dll exists natively on ARM64 Windows but beware .NET stub version
  - FETCHCONTENT_BASE_DIR backslashes cause CMake errors — use file(TO_CMAKE_PATH)
  - VsDevCmd.bat (not Enter-VsDevShell) for SSH builds
  - UTM VM has no GPU passthrough — D3D11 falls back to WARP software rasterizer
  - JUCE cache is generator-specific — delete when switching generators
  - dxc.exe and fxc.exe ARM64 native binaries ship with Windows SDK

GIT DISCIPLINE:
- Commit at the end of EVERY iteration where changes were made.
- Commits must be small, focused, and descriptive.
- Do NOT push to remote unless explicitly needed for VM pull or CI.
- PlunderTube Windows work: feature/windows-build branch (exists).
- PlunderTube Linux work: feature/linux-build branch (create from main when starting Phase H).
- Starter: feature/cross-platform-audit branch.
- juce-dev: feature/port-command branch.

EACH ITERATION MUST:
1. Re-read docs/cross-platform-testing-plan.md
2. Check docs/cross-platform-learnings.md for relevant learnings
3. Identify the NEXT incomplete item following Execution Order
4. Switch to the correct repo and branch
5. Implement it (if VM task, SSH and capture output)
6. If anything interesting was learned, add to cross-platform-learnings.md
7. Commit changes
8. Update cross-platform-testing-plan.md status
9. Summarize what was done and what is next

COMPLETION CONDITION:
- docs/cross-platform-testing-plan.md has ZERO incomplete items across Phases A-H
- All items are marked done or blocked with documented blockers
- PlunderTube builds on Windows (VM or CI) with Visage D3D11 enabled
- PlunderTube builds on Linux (VM or CI) with Visage Vulkan enabled
- JUCE-Plugin-Starter template builds verified on Windows and Ubuntu VMs
- juce-dev port command tested and merged
- macOS builds still work
- cross-platform-learnings.md maintained throughout

ONLY WHEN ALL CONDITIONS ARE MET:
Output exactly: DONE

IF STUCK:
- After 5 iterations without progress on a VM task, switch to GitHub Actions CI as alternative.
- After 10 iterations total without progress, document in cross-platform-learnings.md what is blocked and why.
