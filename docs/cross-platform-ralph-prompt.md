Read docs/00-audit-overview.md, docs/01-feature-comparison.md, docs/02-visage-platform-support.md, docs/03-priority-roadmap.md, and docs/04-branch-strategy.md for full context.

Execute the following phases in order. After completing each phase, summarize what was done and ask for confirmation before proceeding to the next.

## Codex Delegation

Use `/codex <task>` or `codex exec --full-auto <task>` for parallel work when it would speed things up.

Good candidates for Codex delegation:
- Writing Catch2 tests after you've set up the test framework (1.3)
- Writing .clang-format while you work on CLAP integration (1.4)
- Implementing the Inno Setup installer template while you work on Windows CMake (2.2)
- Writing GitHub Actions CI workflow while you work on build scripts (2.4)
- Researching JUCE Android support while you work on other tasks (4.1)
- Code review of completed work items before merging

Do NOT delegate to Codex when:
- The task depends on something you are currently building
- Multiple agents would edit the same file (e.g., both editing CMakeLists.txt or build.sh)
- The task requires cross-repo coordination (e.g., updating juce-dev plugin to match CLI changes you're still making)
- The task involves the Visage bridge layers (needs deep context about destruction ordering, event bridging)

When delegating, run Codex in background and continue your own work. Check Codex output before marking the work item complete.

## Phase 1: macOS/iOS Enhancements

1.1. Add CLAP plugin format support via clap-juce-extensions to CMakeLists.txt and build.sh. Update the juce-dev plugin's build command and juce-starter skill to include CLAP as a target. Create branch `feature/cross-platform-1-clap` in both JUCE-Plugin-Starter and juce-dev repos.

1.2. Add AUv3 format support to CMakeLists.txt. Update /juce-dev:setup-ios to offer AUv3 as an option alongside standalone iOS app. Create branch `feature/cross-platform-1-auv3` in both repos.

1.3. Integrate Catch2 v3 unit testing framework. Add tests/ directory with test helpers and example plugin tests. Update build.sh to run Catch2 tests alongside PluginVal. Update juce-dev build command. Create branch `feature/cross-platform-1-catch2` in both repos. Consider delegating test file writing to Codex after framework is set up.

1.4. Add .clang-format with JUCE-style conventions to the template root. Create branch `feature/cross-platform-1-clang-format`. Good Codex candidate - can run in parallel with other Phase 1 work.

## Phase 2: Windows Support

2.1. Add Windows build system support to CMakeLists.txt (MSVC + Ninja generator option). Create platform-aware build scripts that work on both macOS and Windows. Add Windows-specific .env variables. Create branch `feature/cross-platform-2-windows` in JUCE-Plugin-Starter.

2.2. Add Windows code signing support (Azure Trusted Signing). Add Inno Setup installer template. Update build.sh for Windows distribution workflow. Same branch. Inno Setup template is a good Codex candidate while you work on signing integration.

2.3. Create JuceVisageBridge for Windows (Win32 HWND embedding, DirectX rendering via Visage). Create branch `feature/cross-platform-2-juce-bridge-win` in the Visage repo. Do NOT delegate - requires deep Visage context.

2.4. Add GitHub Actions CI/CD workflow for macOS + Windows matrix builds with sccache, pluginval, and artifact upload. Create branch `feature/cross-platform-2-ci`. Good Codex candidate - can draft workflow YAML while you finalize build scripts.

2.5. Update juce-dev plugin commands for Windows platform detection, Windows paths, and Windows-specific tool checks. Create branch `feature/cross-platform-2-windows` in juce-dev repo. Do NOT delegate - must align with CLI changes from 2.1.

## Phase 3: Linux Support

3.1. Add Linux build system support to CMakeLists.txt (Clang + Ninja). Add Linux dependency installation script (apt-based for Ubuntu/Debian). Add Linux to CI matrix. Create branch `feature/cross-platform-3-linux`.

3.2. Create JuceVisageBridge for Linux (X11 window embedding, Vulkan rendering via Visage). Create branch `feature/cross-platform-3-juce-bridge-linux` in Visage repo. Do NOT delegate - requires deep Visage context.

3.3. Add Linux packaging (.deb or AppImage). Update juce-dev plugin for Linux awareness. Create branch `feature/cross-platform-3-linux` in juce-dev repo.

## Phase 4: Android Investigation (Research Only)

4.1. Research JUCE Android support status, audio plugin landscape on Android, and whether Visage BGFX backends can target Android OpenGL ES or Vulkan. Document findings in docs/05-android-assessment.md. No code changes. Good Codex candidate - pure research task.
