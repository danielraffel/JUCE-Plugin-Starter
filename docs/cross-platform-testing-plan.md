# Cross-Platform Testing & Completion Plan

Status tracking for remaining cross-platform work: PlunderTube porting, VM testing, juce-dev port command, and outstanding items.

**VMs Available:**
- Windows ARM64: `ssh win` (UTM, Windows 11 ARM64, VS2022 + MSVC)
- Ubuntu 24.04 ARM64: `ssh ubuntu` (UTM, Ubuntu 24.04.4 LTS)

**Active Branches:**
- PlunderTube Windows: `feature/windows-build` (in `/Users/danielraffel/Code/PlunderTube`) — exists
- PlunderTube Linux: `feature/linux-build` (in `/Users/danielraffel/Code/PlunderTube`) — create from main when starting Phase H
- juce-dev: `feature/port-command` (in `/Users/danielraffel/Code/generous-corp-marketplace/plugins/juce-dev`)
- Starter: `feature/cross-platform-audit` (in `/Users/danielraffel/Code/JUCE-Plugin-Starter`)

---

## Phase A: PlunderTube Windows Port

Branch: `feature/windows-build` (exists in PlunderTube repo)
Goal: PlunderTube builds and runs on Windows with Visage GPU UI (D3D11) enabled.

| # | Task | Status | Notes |
|---|------|--------|-------|
| A.1 | Verify bgfx shaderc builds from source on ARM64 Windows (VISAGE_BUILD_SHADERC). If VM fails, use GitHub Actions CI with windows-latest runner. | [x] | VERIFIED 2026-03-07: shaderc v1.18.129 builds from source on ARM64 Windows (MSVC 19.44, Ninja). 433 compilation units, all succeeded. shaderc.exe runs natively — no x86-64 emulation needed. Built at C:\Users\daniel\.juce_cache\bgfx-build\cmake\bgfx\shaderc.exe. |
| A.2 | Fix remaining C++ compilation errors on Windows (MSVC). Iterate: build, fix, push, rebuild. | [ ] | Expect: missing headers, MSVC template quirks, deprecated APIs. |
| A.3 | Guard macOS-only dependencies in CMakeLists.txt: Sparkle (already done?), Essentia prebuilt libs. | [ ] | Sparkle already wrapped in if(APPLE). Essentia prebuilt libs are arm64 macOS — need if(APPLE) guard or cross-platform build. |
| A.4 | Bundle Windows versions of cross-platform tools: yt-dlp.exe, ffmpeg.exe, ffprobe.exe, deno.exe, aria2c.exe. | [ ] | All tools have official Windows builds. Need download + packaging strategy. |
| A.5 | Windows installer_binaries path resolution — ensure PlunderTube finds bundled tools on Windows. | [ ] | Check Source/ for hardcoded Unix paths to installer_binaries/bin/. |
| A.6 | End-to-end test: PlunderTube standalone launches on Windows, UI renders via D3D11/Visage. | [ ] | Requires A.1-A.5 complete. |
| A.7 | If ARM64 VM is blocked for GPU/shaderc: set up GitHub Actions CI workflow for PlunderTube Windows build. | [?] | Fallback plan. GitHub Actions has native Windows ARM64 runners (free for public repos since Aug 2025, private since Jan 2026). Also windows-latest x86-64 where pre-built shaderc works. |

## Phase C: JUCE-Plugin-Starter Template Windows VM Testing

Goal: Verify the template's Windows support actually works on a real Windows machine.

| # | Task | Status | Notes |
|---|------|--------|-------|
| C.1 | Windows VM: Run dependencies.sh, verify all tools install (cmake, ninja, VS tools, Windows SDK). | [x] | VERIFIED 2026-03-07: CMake 4.2.3, Ninja 1.13.2, Git 2.53, VS2022 Community MSVC ARM64, Windows SDK 10 — all present. Note: dependencies.sh requires Git Bash to run on Windows; all tools were already installed via prior winget. |
| C.2 | Windows VM: Clone JUCE-Plugin-Starter, run init_plugin_project.sh (or manual .env setup), CMake configure with Ninja. | [x] | VERIFIED 2026-03-07: CMake configure succeeds with Ninja + MSVC ARM64. CLAP 1.2.7 detected, all JUCE modules configured. |
| C.3 | Windows VM: Build VST3 + CLAP + Standalone via build.ps1. | [x] | VERIFIED 2026-03-07: All 3 targets build successfully. VST3 installed to C:\Program Files\Common Files\VST3\. Standalone .exe and CLAP .clap produced. |
| C.4 | Windows VM: Run Catch2 tests. | [!] | BLOCKED: Template test files reference PluginProcessor class name which only exists after init_plugin_project.sh replaces placeholders. Catch2 library compiles fine; only test source files fail. Known pre-existing issue. |

## Phase D: JuceVisageBridge Cross-Platform (from cross-platform-plan.md)

Goal: Complete items 2.3 and 3.2 from the original cross-platform plan.

| # | Task | Status | Notes |
|---|------|--------|-------|
| D.1 | JuceVisageBridge for Windows (HWND + D3D11). Research existing Visage windowing code for Win32. | [ ] | Original item 2.3. Visage already has win32 windowing in visage_windowing/. Bridge layer connects JUCE Component to Visage window. |
| D.2 | JuceVisageBridge for Linux (X11 + Vulkan). Research existing Visage windowing code for X11. | [ ] | Original item 3.2. Same pattern as D.1 but for X11/Vulkan. |
| D.3 | Test Visage bridge in JUCE-Plugin-Starter template on Windows. | [ ] | Depends on D.1. |
| D.4 | Test Visage bridge in JUCE-Plugin-Starter template on Linux. | [ ] | Depends on D.2. |

## Phase E: juce-dev Port Command & Plugin Completion

Goal: Finish and test the /juce-dev:port command and merge outstanding branches. This must be done BEFORE Phase G (Linux port) so we can dogfood the port command.

| # | Task | Status | Notes |
|---|------|--------|-------|
| E.1 | Review and finalize /juce-dev:port command on feature/port-command branch. | [~] | Command exists, needs testing. |
| E.2 | Test /juce-dev:port on PlunderTube (dogfooding — audit-only mode on Windows). | [ ] | Run the audit, verify it catches real issues found during Phase A. |
| E.3 | Merge juce-dev feature/port-command to master. | [ ] | After E.1-E.2 verified. |
| E.4 | Merge JUCE-Plugin-Starter outstanding feature branches to main. | [ ] | Review which branches have unmerged work. |

## Phase F: GitHub Actions Fallback (if VM builds are blocked)

Goal: Use CI as alternative to local VM for testing Windows/Linux builds.

| # | Task | Status | Notes |
|---|------|--------|-------|
| F.1 | Add GitHub Actions workflow to PlunderTube for Windows CI build. | [ ] | windows-latest runner is x86-64, avoids ARM64 shaderc issue. Also windows-arm64 runners available. |
| F.2 | Add GitHub Actions workflow to PlunderTube for Linux CI build. | [ ] | ubuntu-latest runner. |
| F.3 | If ARM64 VM shaderc fails: document blocker, use CI-only Windows testing. | [?] | Contingency. |

## Phase G: JUCE-Plugin-Starter Template Ubuntu VM Testing

Goal: Verify the template's Linux support actually works on a real Ubuntu machine BEFORE attempting PlunderTube Linux port.

| # | Task | Status | Notes |
|---|------|--------|-------|
| G.1 | Ubuntu VM: Run dependencies.sh, verify all apt packages install. | [ ] | Tests Linux dependency script (3.1). |
| G.2 | Ubuntu VM: Clone JUCE-Plugin-Starter, CMake configure with Ninja + Clang. | [ ] | Tests Linux CMake path (3.1). |
| G.3 | Ubuntu VM: Build VST3 + CLAP + Standalone. | [ ] | Tests Linux build pipeline (3.1, 3.3). |
| G.4 | Ubuntu VM: Run Catch2 tests. | [ ] | Tests cross-platform test framework (1.3 on Linux). |
| G.5 | Verify GitHub Actions CI passes on all 3 platforms (push to feature branch). | [ ] | Tests CI workflow (2.4, 3.4). |

## Phase H: PlunderTube Linux Port (using /juce-dev:port)

Branch: `feature/linux-build` (create from main when starting this phase)
Goal: PlunderTube builds on Ubuntu Linux with Visage GPU UI (Vulkan) enabled. Use /juce-dev:port command to drive the audit and porting.

Prerequisites: Phase E (port command merged) and Phase G (template verified on Linux) must be complete.

| # | Task | Status | Notes |
|---|------|--------|-------|
| H.1 | Run `/juce-dev:port linux --audit-only` on PlunderTube to generate audit report. | [ ] | Dogfood the port command for Linux. |
| H.2 | Install JUCE Linux dependencies on Ubuntu VM via dependencies.sh. | [ ] | `ssh ubuntu`, run apt packages. |
| H.3 | Clone PlunderTube on Ubuntu VM, attempt CMake configure. | [ ] | Visage should auto-detect Vulkan on Linux. |
| H.4 | Fix Linux-specific compilation errors (guided by H.1 audit). | [ ] | Expect: missing X11/Vulkan headers, Linux-specific JUCE deps. |
| H.5 | Guard macOS-only deps for Linux (same as A.3 but verify on Linux). | [ ] | Sparkle, Essentia prebuilt, macOS frameworks. |
| H.6 | Bundle Linux versions of cross-platform tools. | [ ] | yt-dlp, ffmpeg, deno, aria2c — Linux ARM64 or x86-64 builds. |
| H.7 | End-to-end test: PlunderTube builds and links on Linux. | [ ] | UI rendering test may need Xvfb or real display. |

---

## Execution Order

**Priority 1 (critical path):** A.1 — test shaderc on ARM64 Windows. If blocked, immediately go to F.1/F.2.
**Priority 2 (parallel with A):** C.1-C.4 — Windows VM template testing (independent of PlunderTube).
**Priority 3:** A.2-A.6 — PlunderTube Windows port (depends on A.1 passing or F.1 fallback).
**Priority 4:** E.1-E.3 — juce-dev port command finalize and merge (must land BEFORE Phase H).
**Priority 5:** D.1-D.4 — Visage bridge research and implementation.
**Priority 6:** G.1-G.5 — Ubuntu VM template testing (must pass BEFORE Phase H).
**Priority 7:** H.1-H.7 — PlunderTube Linux port using /juce-dev:port (requires E.3 + G.5 complete).
**Priority 8:** E.4 — Final branch merges and cleanup.

## Learnings

Reference: `docs/cross-platform-learnings.md` for known gotchas.

Key risks:
- **ARM64 Windows + bgfx shaderc**: Pre-built x86-64 crashes. Building from source should work (bgfx.cmake handles ARM64 via CMake, shaderc is CPU-only). Risk: .NET stub D3DCompiler_47.dll shadowing the real one. Fallback: GitHub Actions CI (x86-64 or ARM64 Windows runners).
- **UTM VM GPU passthrough**: UTM doesn't expose real GPU to guest — D3D11 may fall back to WARP (software rasterizer). Visage/bgfx may or may not work with WARP. Shaderc compilation does NOT need GPU.
- **Ubuntu VM display**: No physical display. May need Xvfb for any GUI tests. Vulkan may not be available without GPU passthrough.
- **dxc.exe ARM64**: Native ARM64 DirectX shader compiler available since Dec 2022. fxc.exe ARM64 ships with Windows SDK.
