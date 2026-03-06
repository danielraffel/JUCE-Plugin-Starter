# Priority Roadmap: Cross-Platform Expansion

## Strategic Decision: Build vs Fork

Before executing, we need to decide between two approaches:

### Option A: Extend JUCE-Plugin-Starter (Current Direction)
**Pros:**
- We own the full stack and developer experience
- Deep Claude Code plugin integration is our differentiator
- .env-driven config, init wizard, DiagnosticKit, AI release notes - none of these exist in the reference template
- Visage GPU UI is tightly integrated and we control the fork
- iOS support already works (reference template has AUv3 target but no iOS app or touch)
- Our distribution pipeline (PKG/DMG/landing page/uninstaller) is more complete
- Template-based project creation (vs fork/clone) is cleaner for new users

**Cons:**
- We'd need to build CI/CD, Windows signing, Linux packaging from scratch
- No community contributions or battle-testing on Windows/Linux
- More work to reach parity on cross-platform builds

### Option B: Fork the Reference Template
**Pros:**
- Immediate Windows + Linux CI/CD pipeline
- Battle-tested cross-platform builds (macOS, Windows, Linux)
- CLAP support included
- Catch2 testing framework included
- Windows code signing (Azure Trusted Signing) already configured
- Community-maintained, active development

**Cons:**
- Would need to port ALL our innovations into their architecture:
  - Init wizard + template system
  - .env configuration
  - Claude Code plugin integration
  - Visage GPU UI integration
  - DiagnosticKit
  - AI release notes
  - Landing page generation
  - Auto version bumping
  - iOS support
  - Skip-regen fast builds
- Their architecture differs significantly (git submodules vs FetchContent, Ninja vs Xcode, SharedCode target)
- We'd be maintaining a fork that may diverge from upstream
- Loses our clean separation of template vs project
- Their DX is "clone and modify" vs our "run wizard, get fresh project"

### Option C: Hybrid - Cherry-pick specific features
**Pros:**
- Take only what we need (CI workflows, CLAP, Catch2, Windows signing)
- Keep our architecture and DX intact
- No fork maintenance burden
- Can adapt their CI/CD patterns without adopting their build structure

**Cons:**
- More manual integration work per feature
- Need to understand both architectures

**Recommendation:** Option C (Hybrid) seems strongest. Our developer experience and architecture are significantly ahead. The reference template's main advantages are cross-platform CI/CD and a few plugin formats (CLAP, AUv3) that we can add independently.

---

## Phase 1: macOS/iOS Enhancements (No Windows Required)

### 1.1 CLAP Format Support
**Priority:** High
**Effort:** Small
**What:** Add CLAP plugin format via clap-juce-extensions
**Where:** CMakeLists.txt, build.sh, juce-dev plugin
**CLI impact:** Add `clap` as build target in build.sh
**Plugin impact:** Update /juce-dev:build to support `clap` target

### 1.2 AUv3 Format Support
**Priority:** High
**Effort:** Medium
**What:** Add AUv3 (iOS Audio Unit extension) format alongside standalone iOS app
**Where:** CMakeLists.txt, setup-ios command
**CLI impact:** New format in build.sh
**Plugin impact:** Update /juce-dev:setup-ios to offer AUv3 option

### 1.3 Unit Testing Framework (Catch2)
**Priority:** High
**Effort:** Medium
**What:** Add Catch2 test framework with JUCE GUI test helpers
**Where:** CMakeLists.txt, tests/ directory, build.sh
**CLI impact:** `./scripts/build.sh all test` runs Catch2 tests + PluginVal
**Plugin impact:** Update /juce-dev:build, add test template to /juce-dev:create

### 1.4 Code Formatting (.clang-format)
**Priority:** Medium
**Effort:** Small
**What:** Add .clang-format with JUCE-style conventions
**Where:** .clang-format in template root
**CLI impact:** None (editor/IDE picks it up)
**Plugin impact:** None needed

### 1.5 Melatonin Inspector Integration
**Priority:** Medium
**Effort:** Small
**What:** Optional runtime UI debugging tool (works alongside Visage for JUCE components)
**Where:** CMakeLists.txt, PluginEditor
**CLI impact:** Optional feature flag in .env
**Plugin impact:** Add to /juce-dev:create feature selection

---

## Phase 2: Windows Support

### 2.1 Windows Build System
**Priority:** High
**Effort:** Large
**What:** CMake configuration for Windows (MSVC + Ninja), build scripts
**Where:** CMakeLists.txt, new scripts (build.ps1 or adapt build.sh for cross-platform)
**CLI impact:** build.sh needs to work on Windows (or PowerShell equivalent)
**Plugin impact:** /juce-dev:create and /juce-dev:build need Windows paths, tools, generators

### 2.2 Windows Code Signing
**Priority:** High
**Effort:** Medium
**What:** Azure Trusted Signing or Authenticode signing for Windows binaries
**Where:** build.sh or dedicated signing script
**CLI impact:** New .env variables for Windows certificates
**Plugin impact:** Update /juce-dev:build for Windows signing workflow

### 2.3 Windows Installer (Inno Setup)
**Priority:** High
**Effort:** Medium
**What:** Create Windows installer for VST3/CLAP/Standalone
**Where:** packaging/installer.iss template, build.sh
**CLI impact:** `./scripts/build.sh all publish` creates Windows installer
**Plugin impact:** Update distribution workflow

### 2.4 Visage Windows Bridge
**Priority:** Medium
**Effort:** Medium
**What:** JuceVisageBridge for Win32 HWND embedding
**Where:** Source/Visage/JuceVisageBridge_win32.cpp, templates/visage/
**CLI impact:** None (CMake conditional includes handle it)
**Plugin impact:** Update juce-visage skill with Windows patterns

### 2.5 GitHub Actions CI/CD
**Priority:** High
**Effort:** Medium
**What:** GitHub Actions workflow for macOS + Windows builds
**Where:** .github/workflows/build.yml
**CLI impact:** Template includes CI config
**Plugin impact:** /juce-dev:create sets up CI

### 2.6 Windows Dependencies Script
**Priority:** Medium
**Effort:** Medium
**What:** Equivalent of dependencies.sh for Windows (PowerShell)
**Where:** scripts/dependencies.ps1 or cross-platform script
**CLI impact:** /juce-dev:create detects Windows and runs appropriate setup
**Plugin impact:** Platform-aware environment checks

---

## Phase 3: Android Investigation

### 3.1 JUCE Android Assessment
**Effort:** Research only
**What:** Determine if JUCE supports Android with GPU frontends
**Questions:**
- Does JUCE's Android support work with external GPU renderers?
- Can Visage's BGFX backend target Android (OpenGL ES or Vulkan)?
- What's the Android audio plugin landscape? (no AU/VST3 on Android)
- Is there a JUCE Android app template that makes sense?

### 3.2 Visage Android Backend (if feasible)
**Effort:** Very Large
**What:** Would require new windowing (SurfaceView), JNI bridge, OpenGL ES/Vulkan
**Decision:** Likely defer unless JUCE Android is mature enough

---

## Phase 4: Linux Support

### 4.1 Linux Build System
**Priority:** Medium
**Effort:** Medium
**What:** CMake for Linux (Clang + Ninja), dependency installation
**Where:** CMakeLists.txt, dependencies script
**CLI impact:** build.sh works on Linux
**Plugin impact:** Platform-aware /juce-dev:create and /juce-dev:build

### 4.2 Linux Packaging
**Priority:** Medium
**Effort:** Small
**What:** .deb/.rpm or AppImage or tar.gz distribution
**Where:** packaging scripts
**Plugin impact:** Update distribution workflow

### 4.3 Visage Linux Bridge
**Priority:** Medium
**Effort:** Medium
**What:** JuceVisageBridge for X11 window embedding
**Where:** Source/Visage/JuceVisageBridge_linux.cpp
**Plugin impact:** Update juce-visage skill with Linux patterns

### 4.4 Linux CI
**Priority:** Medium
**Effort:** Small (once Windows CI exists)
**What:** Add Linux to GitHub Actions matrix
**Where:** .github/workflows/build.yml

---

## CLI/Plugin Extension Map

For each feature added, both the CLI scripts and Claude Code plugin need updates:

| Feature | CLI (scripts/) | Plugin (commands/) | Plugin (skills/) | .env |
|---------|---------------|-------------------|------------------|------|
| CLAP | build.sh | /juce-dev:build | juce-starter | BUILD_FORMATS |
| AUv3 | build.sh, CMake | /juce-dev:setup-ios | juce-starter | - |
| Catch2 | build.sh | /juce-dev:build | juce-starter | RUN_UNIT_TESTS |
| .clang-format | - | /juce-dev:create | - | - |
| Windows build | build.sh/ps1 | /juce-dev:build | juce-starter | WIN_GENERATOR |
| Windows signing | build.sh/ps1 | /juce-dev:build | juce-starter | AZURE_* vars |
| Windows installer | build.sh/ps1 | /juce-dev:build | juce-starter | - |
| Visage Win bridge | CMake | - | juce-visage | - |
| CI/CD | - | /juce-dev:create | juce-starter | - |
| Linux build | build.sh | /juce-dev:build | juce-starter | - |
| Visage Linux bridge | CMake | - | juce-visage | - |
