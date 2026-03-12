# Integration Branch Plan: `integrate/cross-platform`

## Goal

Merge the entire cross-platform feature chain into a single integration branch for hands-on testing before merging to `main`. This branch will be used to create a fresh plugin project and verify it builds and runs on macOS, Windows, and (eventually) Linux.

## What's Being Merged

**Source branch:** `feature/cross-platform-3-docs` (57 commits ahead of main, 0 behind)

This single branch contains the cumulative work from the entire linear chain:

| Phase | Branch | Commits | Features |
|-------|--------|---------|----------|
| Audit | `feature/cross-platform-audit` | 4 | Cross-platform roadmap and planning |
| 1.1 | `feature/cross-platform-1-clap` | 1 | CLAP format via clap-juce-extensions |
| 1.2 | `feature/cross-platform-1-auv3` | 1 | AUv3 app extension format |
| 1.3 | `feature/cross-platform-1-catch2` | 1 | Catch2 v3 unit testing |
| 1.4 | `feature/cross-platform-1-clang-format` | 1 | .clang-format style rules |
| 1.5-1.6 | `feature/cross-platform-1-docs` | 2 | Phase 1 README updates |
| 2.1-2.4 | `feature/cross-platform-2-windows` | 5 | Windows CMake, build.ps1, dependencies |
| 2.5 | `feature/cross-platform-2-ci` | 1 | GitHub Actions CI (macOS + Windows + Linux) |
| 2.6-2.8 | `feature/cross-platform-2-docs` | 4 | Phase 2 docs |
| 3.1-3.5 | `feature/cross-platform-3-linux` | 4 | Linux build support (build.sh, CMake, CI, deps) |
| 3.6+ | `feature/cross-platform-3-docs` | 35 | DiagnosticKit (JUCE cross-platform), pluginval, docs |

**Standalone branches (already superseded):**
- `claude/diagnostickit-fixes` — 3 commits, all features already in cross-platform-3-docs
- `claude/visage-integration` — 2 commits, Visage setup already in cross-platform-3-docs

These don't need separate merging — their work is already included.

## What Changed (47 files, +8285/-266 lines)

### New Features
- **CLAP plugin format** — via clap-juce-extensions, auto-configured in CMakeLists.txt
- **AUv3 format** — app extension format for Logic Pro and iOS
- **Catch2 v3 unit testing** — tests/ directory with plugin basics and editor tests
- **.clang-format** — JUCE-style code formatting rules
- **Windows build system** — `scripts/build.ps1`, Ninja/MSVC, Inno Setup installer template
- **Linux build system** — Platform auto-detection in build.sh, apt dependencies, tar.gz packaging
- **GitHub Actions CI/CD** — Matrix build: macOS (arm64+x86_64), Windows (MSVC), Linux (Clang)
- **DiagnosticKit (JUCE)** — Cross-platform diagnostic app (Windows/Linux) alongside existing macOS Swift version
- **Inno Setup installer template** — `templates/installer.iss` for Windows distribution

### Enhanced Scripts
- **build.sh** — Multi-format, multi-plugin auto-discovery, pluginval, code signing, notarization, publish, uninstall, unsigned, pkg modes
- **dependencies.sh** — Cross-platform: macOS (Homebrew), Windows (winget), Linux (apt)
- **CMakeLists.txt** — Platform-conditional source files, CLAP integration, Catch2 FetchContent

### Documentation
- **README.md** — Comprehensive updates for all three platforms, build commands, CI, testing
- **docs/** — Planning docs from the cross-platform effort (see cleanup notes below)

## What's NOT Ready

### Linux
Linux support is **included but untested locally**. It:
- Builds in CI (GitHub Actions ubuntu-22.04 with Clang)
- Has platform guards in all shared scripts (`if APPLE`, `if MSVC`, `if(UNIX AND NOT APPLE)`)
- Won't affect macOS or Windows in any way (auto-detected, no manual flags)
- Will need hands-on testing when a Linux VM/machine is available

Including it now is **safe** — it's purely additive and gated behind platform detection.

## Branch Creation Steps

1. Create `integrate/cross-platform` from `main`
2. Merge `feature/cross-platform-3-docs` into it (fast-forward or merge commit)
3. Clean up planning docs that shouldn't ship in the template
4. Update README if needed
5. Commit cleanup

## Testing Plan

### macOS Testing
- [ ] Run `./scripts/init_plugin_project.sh` to create a fresh plugin project
- [ ] Build standalone: `./scripts/build.sh standalone`
- [ ] Build AU: `./scripts/build.sh au`
- [ ] Build VST3: `./scripts/build.sh vst3`
- [ ] Build CLAP: `./scripts/build.sh clap`
- [ ] Run tests: `./scripts/build.sh all test`
- [ ] Generate Xcode project: `./scripts/generate_and_open_xcode.sh`
- [ ] Verify plugin loads in a DAW (Logic Pro or similar)

### Windows Testing
- [ ] Clone the created plugin project on Windows VM
- [ ] Run `scripts/dependencies.sh` or install manually
- [ ] Build: `.\scripts\build.ps1`
- [ ] Build standalone: `.\scripts\build.ps1 standalone`
- [ ] Build VST3: `.\scripts\build.ps1 vst3`
- [ ] Verify standalone launches

### iOS Testing (via AUv3)
- [ ] Build AUv3 target in Xcode
- [ ] Deploy to device/simulator
- [ ] Verify plugin loads in GarageBand or AUM

### Linux (deferred)
- [ ] Set up Linux VM with dependencies
- [ ] Build standalone and VST3
- [ ] Verify standalone launches

## Docs Cleanup

The `docs/` directory contains planning documents from the cross-platform effort. These are useful as historical reference but shouldn't ship in the starter template:

| File | Purpose | Keep? |
|------|---------|-------|
| `00-audit-overview.md` | Initial audit | Remove (planning) |
| `01-feature-comparison.md` | Platform comparison | Remove (planning) |
| `02-visage-platform-support.md` | Visage notes | Remove (planning) |
| `03-priority-roadmap.md` | Priority list | Remove (planning) |
| `04-branch-strategy.md` | Branch strategy | Remove (planning) |
| `cross-platform-plan.md` | Phase tracker | Remove (planning) |
| `cross-platform-learnings.md` | Lessons learned | Remove (planning) |
| `cross-platform-ralph-prompt.md` | Ralph loop prompt | Remove (planning) |
| `cross-platform-testing-plan.md` | Testing plan | Remove (planning) |
| `port-command-spec.md` | Port command spec | Remove (planning) |
| `ralph-loop-testing-prompt.md` | Testing prompt | Remove (planning) |
| `testing-checklist.md` | Testing checklist | Remove (planning) |
| `integration-plan.md` (this file) | Integration plan | Keep until merge to main |

**Recommendation:** Remove all planning docs before merging to main. They served their purpose during development. Keep `integration-plan.md` as the active tracker.

## Branch Cleanup (After Main Merge)

Once `integrate/cross-platform` is tested and merged to `main`, these branches can be deleted:

**Linear chain (all contained in cross-platform-3-docs):**
- `feature/cross-platform-audit`
- `feature/cross-platform-1-clap`
- `feature/cross-platform-1-auv3`
- `feature/cross-platform-1-catch2`
- `feature/cross-platform-1-clang-format`
- `feature/cross-platform-1-docs`
- `feature/cross-platform-2-windows`
- `feature/cross-platform-2-ci`
- `feature/cross-platform-2-docs`
- `feature/cross-platform-3-linux`
- `feature/cross-platform-3-docs`

**Superseded standalone branches:**
- `claude/diagnostickit-fixes`
- `claude/visage-integration`

**Already merged:**
- `update-build-script`

**Remote-only (investigate before deleting):**
- `origin/integrate`
- `origin/new-features`
