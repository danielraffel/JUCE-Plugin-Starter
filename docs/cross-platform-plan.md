# Cross-Platform Plan

Status tracking for all phases. Mark items `[~]` when starting, `[x]` when complete, `[!]` if blocked (with note). Add notes in the Notes column.

**Active scope:** Phase 1 through Phase 3. Phase 4 is tracked but deferred.

Reference docs: [01-feature-comparison.md](01-feature-comparison.md), [02-visage-platform-support.md](02-visage-platform-support.md), [03-priority-roadmap.md](03-priority-roadmap.md), [04-branch-strategy.md](04-branch-strategy.md)

## Phase 1: macOS/iOS Enhancements

| # | Task | Branch | Repos | Status | Notes |
|---|------|--------|-------|--------|-------|
| 1.1 | Add CLAP format via clap-juce-extensions. Update CMakeLists.txt, build.sh, juce-dev build command, juce-starter skill. | `feature/cross-platform-1-clap` | Starter, juce-dev | [x] | CMake configures CLAP target successfully |
| 1.2 | Add AUv3 format to CMakeLists.txt. Update /juce-dev:setup-ios to offer AUv3 alongside standalone iOS app. | `feature/cross-platform-1-auv3` | Starter, juce-dev | [x] | AUv3 target confirmed in CMake. AU vs AUv3 naming clarified in UI. |
| 1.3 | Integrate Catch2 v3. Add tests/ with helpers and example tests. Update build.sh to run Catch2 + PluginVal. Update juce-dev build command. | `feature/cross-platform-1-catch2` | Starter, juce-dev | [x] | Tests target confirmed in CMake. Catch2 v3.7.1 via FetchContent. |
| 1.4 | Add .clang-format with JUCE-style conventions to template root. | `feature/cross-platform-1-clang-format` | Starter | [x] | JUCE Allman-style, C++17, ObjC section |
| 1.5 | Update JUCE-Plugin-Starter README.md to document all current + new Phase 1 features. | `feature/cross-platform-1-docs` | Starter | [x] | Added CLAP, AUv3, Catch2, .clang-format docs |
| 1.6 | Update juce-dev plugin: juce-starter skill (CLAP, AUv3, Catch2, .clang-format), build command (clap target, test runner), setup-ios command (AUv3 option). | `feature/cross-platform-1-docs` | juce-dev | [x] | Most updates done alongside 1.1-1.3. Final pass: .clang-format + tests in skill tree. |

## Phase 2: Windows Support

| # | Task | Branch | Repos | Status | Notes |
|---|------|--------|-------|--------|-------|
| 2.1 | Windows CMake config (MSVC + Ninja). Platform-aware build scripts for macOS + Windows. Windows .env variables. | `feature/cross-platform-2-windows` | Starter | [x] | CMakeLists.txt platform-conditional, build.ps1 for Windows, .env.example updated |
| 2.2 | Windows code signing (Azure Trusted Signing). Inno Setup installer template. Windows distribution in build.ps1. | `feature/cross-platform-2-windows` | Starter | [x] | Inno Setup template, build.ps1 packaging, Azure signing vars |
| 2.3 | JuceVisageBridge for Windows (Win32 HWND, DirectX via Visage). | `feature/cross-platform-2-juce-bridge-win` | Visage | [!] | Blocked: needs Windows dev environment with DirectX SDK + deep Visage context. Human intervention needed. |
| 2.4 | GitHub Actions CI/CD: macOS + Windows matrix, sccache, pluginval, artifact upload. | `feature/cross-platform-2-ci` | Starter | [x] | sccache, Catch2 via ctest, PluginVal VST3, artifact upload |
| 2.5 | Update juce-dev plugin: build command (Windows paths, MSVC detection), create command (Windows env checks, winget/choco deps), juce-starter skill (Windows build docs, .env vars), juce-visage skill (Windows bridge patterns). | `feature/cross-platform-2-windows` | juce-dev | [x] | build: platform detection + build.ps1; create: winget deps; skill: Windows build docs; visage: noted as blocked |
| 2.6 | Cross-platform dependencies.sh: detect OS, install right prerequisites (brew/winget/apt). | `feature/cross-platform-2-windows` | Starter | [x] | Platform detection, winget for Windows, brew for macOS, Linux placeholder |
| 2.7 | Update JUCE-Plugin-Starter README.md to document Windows support, CI/CD, and all Phase 2 features. | `feature/cross-platform-2-docs` | Starter | [x] | Overview, prerequisites, build targets, build commands, CI/CD, project structure |
| 2.8 | Update juce-dev plugin README to document Windows capabilities. | `feature/cross-platform-2-docs` | juce-dev | [x] | Cross-platform description, Windows prerequisites, platform note on targets |

## Phase 3: Linux Support

| # | Task | Branch | Repos | Status | Notes |
|---|------|--------|-------|--------|-------|
| 3.1 | Linux CMake config (Clang + Ninja). Linux dependency script (apt for Ubuntu/Debian). Update dependencies.sh platform detection from 2.6. | `feature/cross-platform-3-linux` | Starter | [x] | CMake auto-detects Clang on Linux, apt deps in dependencies.sh, macOS build verified |
| 3.2 | JuceVisageBridge for Linux (X11 window embedding, Vulkan rendering via Visage). | `feature/cross-platform-3-juce-bridge-linux` | Visage | [!] | Blocked: same as 2.3 — needs Linux dev environment with Vulkan SDK + deep Visage windowing context. Human intervention needed. |
| 3.3 | Linux packaging (.deb or AppImage or tar.gz). Update build.sh for Linux distribution. | `feature/cross-platform-3-linux` | Starter | [x] | tar.gz packaging, platform-aware build.sh (Ninja on Linux, format filtering, plugin paths) |
| 3.4 | Add Linux to GitHub Actions CI matrix (extend workflow from 2.4). | `feature/cross-platform-3-linux` | Starter | [x] | ubuntu-22.04, Clang, JUCE deps, Xvfb, PluginVal Linux validation |
| 3.5 | Update juce-dev plugin: build command (Linux paths), create command (Linux env checks, apt deps), juce-starter skill (Linux build docs), juce-visage skill (Linux/X11 bridge patterns). | `feature/cross-platform-3-linux` | juce-dev | [x] | build: Linux platform, tar.gz; create: apt deps; skill: Clang+Ninja; visage: blocked note |
| 3.6 | Update JUCE-Plugin-Starter README.md to document Linux support and all Phase 3 features. | `feature/cross-platform-3-docs` | Starter | [ ] | |
| 3.7 | Update juce-dev plugin README to document Linux capabilities. | `feature/cross-platform-3-docs` | juce-dev | [ ] | |

## Phase 4: Android Investigation (Deferred)

| # | Task | Branch | Repos | Status | Notes |
|---|------|--------|-------|--------|-------|
| 4.1 | Research JUCE Android support, audio plugin landscape, Visage BGFX on Android (OpenGL ES/Vulkan). Document in docs/android-assessment.md. | `feature/cross-platform-4-android` | Starter | [ ] | Research only, no code. Codex candidate. |
| 4.2 | Visage Android backend (SurfaceView, JNI, OpenGL ES/Vulkan) - if feasible per 4.1. | `feature/cross-platform-4-android` | Visage | [ ] | Very large effort. Decision depends on 4.1. |

## Changelog

Record what was actually built/changed for each completed item. This is filled in as items complete.

| # | What Changed | Files Modified | Commits |
|---|-------------|----------------|---------|
| 1.1 | Added CLAP format via clap-juce-extensions FetchContent. Updated build.sh signing, notarization, packaging, uninstall for CLAP. Updated uninstall_template.sh. Updated juce-dev build command and juce-starter skill. | `CMakeLists.txt`, `scripts/build.sh`, `scripts/uninstall_template.sh`, juce-dev `commands/build.md`, juce-dev `skills/juce-starter/SKILL.md` | 1292eec (Starter), 05b8bf0 (juce-dev) |
| 1.2 | Added AUv3 to FORMATS in CMakeLists.txt. Updated build.sh with AUv3 in all sections (args, schemes, build, test, sign, notarize, package). Clarified AU vs AUv3 naming in user-facing text. Updated setup-ios command with AUv3 note. Updated juce-dev build command and juce-starter skill. | `CMakeLists.txt`, `scripts/build.sh`, juce-dev `commands/build.md`, juce-dev `commands/setup-ios.md`, juce-dev `skills/juce-starter/SKILL.md` | 11646b4 (Starter), 22a3ac5 (juce-dev) |
| 1.3 | Integrated Catch2 v3 via FetchContent. Created tests/ with Catch2Main.cpp, PluginBasics.cpp, test_helpers.h. Added Tests CMake target. Updated build.sh to build and run Catch2 tests alongside PluginVal. Updated juce-dev build command and juce-starter skill with testing docs. | `CMakeLists.txt`, `tests/Catch2Main.cpp`, `tests/PluginBasics.cpp`, `tests/helpers/test_helpers.h`, `scripts/build.sh`, juce-dev `commands/build.md`, juce-dev `skills/juce-starter/SKILL.md` | a6907c3 (Starter), c648485 (juce-dev) |
| 1.4 | Added .clang-format with JUCE Allman-style conventions, C++17, ObjC section. | `.clang-format` | 2ec9423 |
| 1.5 | Updated README.md with CLAP, AUv3, Catch2 testing, .clang-format sections. Updated build targets, install paths, dependencies, project structure, packaging table. | `README.md` | 8470597 |
| 1.6 | Final juce-dev skill updates: added tests/ and .clang-format to project tree, updated build.sh format list in tree. | juce-dev `skills/juce-starter/SKILL.md` | 2179060 (Starter), 273752f (juce-dev) |
| 2.1 | Windows CMake: MSVC debug info, platform-conditional FORMATS (no AU/AUv3 on Windows), conditional post-build and VST3 helper. PowerShell build.ps1. Windows .env vars in .env.example (Azure Trusted Signing). | `CMakeLists.txt`, `scripts/build.ps1`, `.env.example` | b647919 |
| 2.2 | Created Inno Setup installer template with VST3/CLAP/Standalone task selection. Updated build.ps1 with publish/unsigned actions, artifact copying, Inno Setup invocation. | `templates/installer.iss`, `scripts/build.ps1` | fb8e015 |
| 2.4 | GitHub Actions CI/CD workflow with macOS + Windows matrix. sccache for build caching, Catch2 via ctest, PluginVal for VST3 validation, artifact upload. | `.github/workflows/build.yml` | 168c0f0 |
| 2.5 | Updated juce-dev build command (platform detection, build.ps1), create command (winget deps), juce-starter skill (Windows build docs, cross-platform CMake), juce-visage skill (Windows note). Also fixed CMakeLists.txt: FETCHCONTENT path escaping + conditional Resources link. | `CMakeLists.txt`, juce-dev `commands/build.md`, juce-dev `commands/create.md`, juce-dev `skills/juce-starter/SKILL.md`, juce-dev `skills/juce-visage/SKILL.md` | 2195d7c (Starter), 82dfa45 (juce-dev) |
| 2.6 | Cross-platform dependencies.sh with platform detection (macOS/Windows/Linux), winget for Windows, brew for macOS, Linux placeholder. Added ninja to macOS deps. | `scripts/dependencies.sh` | (part of b647919) |
| 2.7 | Updated README.md with Windows prerequisites, build commands (PowerShell), CI/CD section, cross-platform project structure. | `README.md` | (on feature/cross-platform-2-docs) |
| 2.8 | Updated juce-dev README with cross-platform description, Windows prerequisites, platform notes on targets. | juce-dev `README.md` | 4facce0 (juce-dev) |
| 3.1 | Linux CMake config: auto-detect Clang, UNIX-specific block. dependencies.sh: full apt package list for Ubuntu/Debian (ALSA, X11, FreeType, WebKit2GTK, GLU, etc). | `CMakeLists.txt`, `scripts/dependencies.sh` | (on feature/cross-platform-3-linux) |
| 3.3 | Platform-aware build.sh: detect macOS/Linux, use Ninja on Linux, filter AU/AUv3, cmake --build for Linux, Linux plugin paths (VST3→~/.vst3, CLAP→~/.clap), tar.gz packaging, PluginVal path handling. | `scripts/build.sh` | (on feature/cross-platform-3-linux) |
| 3.4 | Added Linux to CI matrix: ubuntu-22.04 with Clang, JUCE apt deps, Xvfb for PluginVal, Linux VST3 validation step. | `.github/workflows/build.yml` | (on feature/cross-platform-3-linux) |
| 3.5 | Updated juce-dev: build command (Linux platform, tar.gz), create command (apt deps), juce-starter skill (Clang+Ninja, Linux build docs), juce-visage skill (Linux Vulkan blocked note). | juce-dev `commands/build.md`, `commands/create.md`, `skills/juce-starter/SKILL.md`, `skills/juce-visage/SKILL.md` | 00c3b4e (juce-dev) |

## Human Testing Checklist

After all automated work completes, these are the manual verification steps. Items are added as each phase completes.

### Phase 1 Manual Verification
- [ ] Create a new project with `/juce-dev:create` - verify CLAP shows up in build formats
- [ ] Build CLAP plugin locally and load in a CLAP-compatible DAW
- [ ] Build AUv3 and test in iOS simulator
- [ ] Run `./scripts/build.sh all test` and verify Catch2 + PluginVal both run
- [ ] Open project in IDE and verify .clang-format applies
- [ ] Review updated README for accuracy and completeness
- [ ] Review updated juce-dev plugin skills - test each command

### Phase 2 Manual Verification
- [ ] SSH to Windows VM (`ssh win`), clone project, run dependencies script
- [ ] Build plugin on Windows via CMake + Ninja
- [ ] Verify VST3 and CLAP load in a Windows DAW (or pluginval)
- [ ] Test Windows installer (Inno Setup) installs to correct locations
- [ ] Verify Visage GPU UI renders on Windows (DirectX)
- [ ] Push to GitHub and verify CI builds pass on both macOS and Windows
- [ ] Run `/juce-dev:create` on Windows (or verify plugin detects Windows correctly)
- [ ] Review updated README for accuracy

### Phase 3 Manual Verification
- [ ] On Linux (or CI), run dependencies script and verify all deps install
- [ ] Build plugin on Linux via CMake + Ninja
- [ ] Verify VST3 and CLAP load (pluginval on Linux)
- [ ] Verify Visage GPU UI renders on Linux (Vulkan/X11)
- [ ] Verify CI matrix now includes Linux and passes
- [ ] Test Linux package (.deb/AppImage) installs correctly
- [ ] Review updated README for accuracy

## Testing Strategy

Tests must be added and verified as part of each phase, not deferred.

**Build verification (every iteration that touches build system):**
- macOS: `./scripts/build.sh standalone` must succeed
- Windows: build via CMake + Ninja on `ssh win` VM (Phase 2+)
- Linux: build via CMake + Ninja in CI or local Linux env (Phase 3+)

**Unit tests (from 1.3 onward):**
- `./scripts/build.sh all test` runs Catch2 tests + PluginVal
- New features should include test coverage where practical
- Tests run in CI once GitHub Actions is set up (2.4+)

**Plugin validation:**
- PluginVal runs against AU and VST3 on every `test` build
- CLAP validation added alongside 1.1

**CI verification (from 2.4 onward):**
- Push to feature branch triggers CI build on all configured platforms
- All platforms must pass before merging

**Cross-platform smoke tests:**
- After each platform is added, verify: dependency install, CMake configure, build, plugin loads
- Document results in cross-platform-learnings.md

## Blocker Handling

When an item is blocked:
1. Mark it `[!]` in Status with a clear note explaining WHY it's blocked
2. Note whether it needs human intervention (e.g., "needs Windows VM setup", "needs Apple Developer cert")
3. Continue to the NEXT item - do not stop all progress
4. If the blocker is resolved later, return to the item and complete it
5. At phase boundaries, review all `[!]` items before proceeding

Common expected blockers:
- Windows VM needs dev tools installed (human intervention for 2.1+)
- Code signing certs not available in CI (can stub with unsigned builds)
- Linux-specific issues that need a Linux environment to debug
- Visage bridge work may need manual testing on target platform

## Codex Delegation Rules

Delegate to Codex when:
- Writing tests after framework is set up (1.3)
- Writing .clang-format in parallel with other work (1.4)
- Drafting Inno Setup template while working on signing (2.2)
- Drafting CI workflow YAML while finalizing build scripts (2.4)
- Android research (4.1)

Do NOT delegate when:
- Task depends on something currently being built
- Multiple agents would edit the same file
- Task requires cross-repo coordination
- Task involves Visage bridge layers

Run Codex in background, check output before marking complete.

## Repo Paths

| Repo | Path |
|------|------|
| JUCE-Plugin-Starter | `/Users/danielraffel/Code/JUCE-Plugin-Starter` |
| juce-dev plugin | `/Users/danielraffel/Code/generous-corp-marketplace/plugins/juce-dev` |
| Visage fork | `/Users/danielraffel/Code/visage` |

## Dev Environments

**Windows:**
- SSH: `ssh win` (configured in ~/.ssh/config, key already added)
- UTM VM, running, needs dev tools configured in Phase 2

**Linux:**
- No VM set up yet. Can create one if needed during Phase 3.
- CI (GitHub Actions) may be sufficient for Linux verification until then.
