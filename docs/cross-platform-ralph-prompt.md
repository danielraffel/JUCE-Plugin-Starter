Read docs/00-audit-overview.md, docs/01-feature-comparison.md, docs/02-visage-platform-support.md, docs/03-priority-roadmap.md, and docs/04-branch-strategy.md for full context.

Execute the following phases in order. After completing each phase, summarize what was done and ask for confirmation before proceeding to the next.

## Phase 1: macOS/iOS Enhancements

1.1. Add CLAP plugin format support via clap-juce-extensions to CMakeLists.txt and build.sh. Update the juce-dev plugin's build command and juce-starter skill to include CLAP as a target. Create branch `feature/cross-platform-1-clap` in both JUCE-Plugin-Starter and juce-dev repos.

1.2. Add AUv3 format support to CMakeLists.txt. Update /juce-dev:setup-ios to offer AUv3 as an option alongside standalone iOS app. Create branch `feature/cross-platform-1-auv3` in both repos.

1.3. Integrate Catch2 v3 unit testing framework. Add tests/ directory with test helpers and example plugin tests. Update build.sh to run Catch2 tests alongside PluginVal. Update juce-dev build command. Create branch `feature/cross-platform-1-catch2` in both repos.

1.4. Add .clang-format with JUCE-style conventions to the template root. Create branch `feature/cross-platform-1-clang-format`.

## Phase 2: Windows Support

2.1. Add Windows build system support to CMakeLists.txt (MSVC + Ninja generator option). Create platform-aware build scripts that work on both macOS and Windows. Add Windows-specific .env variables. Create branch `feature/cross-platform-2-windows` in JUCE-Plugin-Starter.

2.2. Add Windows code signing support (Azure Trusted Signing). Add Inno Setup installer template. Update build.sh for Windows distribution workflow. Same branch.

2.3. Create JuceVisageBridge for Windows (Win32 HWND embedding, DirectX rendering via Visage). Create branch `feature/cross-platform-2-juce-bridge-win` in the Visage repo.

2.4. Add GitHub Actions CI/CD workflow for macOS + Windows matrix builds with sccache, pluginval, and artifact upload. Create branch `feature/cross-platform-2-ci`.

2.5. Update juce-dev plugin commands for Windows platform detection, Windows paths, and Windows-specific tool checks. Create branch `feature/cross-platform-2-windows` in juce-dev repo.

## Phase 3: Android Investigation (Research Only)

3.1. Research JUCE Android support status, audio plugin landscape on Android, and whether Visage BGFX backends can target Android OpenGL ES or Vulkan. Document findings in docs/05-android-assessment.md. No code changes.

## Phase 4: Linux Support

4.1. Add Linux build system support to CMakeLists.txt (Clang + Ninja). Add Linux dependency installation script. Add Linux to CI matrix. Create branch `feature/cross-platform-4-linux`.

4.2. Create JuceVisageBridge for Linux (X11 window embedding, Vulkan rendering via Visage). Create branch `feature/cross-platform-4-juce-bridge-linux` in Visage repo.

4.3. Add Linux packaging (.deb or AppImage). Update juce-dev plugin for Linux awareness. Create branch `feature/cross-platform-4-linux` in juce-dev repo.
