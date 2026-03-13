# Cross-Platform Testing Checklist

What to test, how to test it, and what needs your help.

---

## macOS — Confidence: HIGH

macOS is the primary development platform. All scripts were written and tested here first. The main risk is regressions from cross-platform changes to shared files (`CMakeLists.txt`, `build.sh`).

### Quick Smoke Test (5 min)

Run from any existing project (e.g., PlunderTubeSampler):

```bash
# 1. Build standalone — verifies CMake configure + compile + launch
./scripts/build.sh standalone

# 2. Build all formats — verifies AU, VST3, CLAP, AUv3, Standalone
./scripts/build.sh all

# 3. Run PluginVal tests
./scripts/build.sh all test
```

If all three pass, macOS is fine.

### Full Verification

- [x] `./scripts/build.sh standalone` — builds and launches *(tested 2026-03-06 on PlunderTube)*
- [ ] `./scripts/build.sh au` — installs to `~/Library/Audio/Plug-Ins/Components/` *(human)*
- [ ] `./scripts/build.sh vst3` — installs to `~/Library/Audio/Plug-Ins/VST3/` *(human)*
- [ ] `./scripts/build.sh clap` — installs to `~/Library/Audio/Plug-Ins/CLAP/` *(human)*
- [ ] `./scripts/build.sh all test` — PluginVal passes for AU and VST3 *(human)*
- [ ] `./scripts/build.sh all sign` — code signing works (requires Apple Developer certs) *(human)*
- [ ] `./scripts/build.sh all publish` — creates PKG, DMG, GitHub release *(human)*
- [ ] Load AU in Logic Pro / GarageBand — plugin appears and processes audio *(human)*
- [ ] Load VST3 in Reaper / Ableton — plugin appears and processes audio *(human)*
- [x] DiagnosticKit JUCE build skips on macOS with correct message *(tested 2026-03-06)*
- [ ] DiagnosticKit Swift app builds when `ENABLE_DIAGNOSTICS=true` *(human)*
- [ ] `./scripts/build.sh uninstall` — removes all installed plugins *(human)*
- [ ] New project creation: `./scripts/init_plugin_project.sh` completes successfully *(human)*

### Testing GitHub Actions from macOS

You can trigger CI without pushing to main:

```bash
# Push your feature branch
git push -u origin feature/cross-platform-audit

# Watch the CI run
gh run watch

# Or trigger manually if workflow_dispatch is enabled
gh workflow run build.yml --ref feature/cross-platform-audit
```

To test the CI workflow locally before pushing (using `act` — Docker-based):
```bash
brew install act
act -j build --matrix os:macos-latest
```

Note: `act` has limitations with macOS runners (most CI uses ubuntu). For real macOS CI testing, push to a branch and watch the GitHub Actions run.

---

## Windows — Confidence: MEDIUM

Windows build support was added but has only been tested in an ARM64 UTM VM. The core flow works (CMake configure, Ninja build, VST3/CLAP/Standalone) but edge cases are untested.

### Prerequisites

You need these installed in your Windows VM:

```powershell
# Check what's installed
cmake --version
ninja --version
git --version
cl  # (from VS Developer Command Prompt)
```

If missing:
```powershell
winget install --id Git.Git -e
winget install --id Kitware.CMake -e
winget install --id Ninja-build.Ninja -e
# VS2022 Community should already be installed; if not:
winget install --id Microsoft.VisualStudio.2022.Community -e
```

**IMPORTANT:** You must run builds from a VS Developer Command Prompt or PowerShell with the MSVC environment loaded:

```powershell
# Load MSVC environment (adjust path if needed)
Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell -SkipAutomaticLocation
```

### Getting Code to the VM

**Option A: Git (recommended for ongoing work)**
```powershell
# Clone the repo
git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter

# Switch to the branch with cross-platform changes
git checkout feature/cross-platform-audit

# Pull updates after making changes on macOS
git pull
```

**Option B: SCP/SSH (for quick one-off transfers)**
```bash
# From macOS, copy to Windows VM
scp -r . user@windows-vm-ip:C:/Users/user/Code/JUCE-Plugin-Starter/
```

Git is better for iterative development — commit on macOS, pull on Windows, fix, commit, pull back.

### Smoke Test

```powershell
# From VS Developer Command Prompt:
cd JUCE-Plugin-Starter

# 1. CMake configure
.\scripts\build.ps1 all

# 2. Check outputs exist
dir build\*_artefacts\Release\VST3\
dir build\*_artefacts\Release\Standalone\
```

### Full Verification

- [x] `.\scripts\build.ps1` — CMake configures with Ninja + MSVC *(tested 2026-03-06, ARM64 MSVC 19.44, 300s configure)*
- [x] VST3 builds and installs to `C:\Program Files\Common Files\VST3\` *(tested 2026-03-06)*
- [x] CLAP builds *(tested 2026-03-06)*
- [x] Standalone .exe builds and runs *(tested 2026-03-06, .exe links successfully)*
- [ ] Catch2 tests compile and pass — **KNOWN ISSUE**: tests reference `PluginProcessor` which is a placeholder; only works after `init_plugin_project.sh` replaces names
- [ ] `build.ps1 test` — PluginVal validates VST3 *(human: needs PluginVal installed on Windows)*
- [ ] Load VST3 in a Windows DAW (Reaper is free to evaluate) *(human)*
- [ ] DiagnosticKit is skipped with warning (not yet cross-platform)
- [ ] New project creation works (init_plugin_project.sh via Git Bash) *(human)*

### Known Issues / Gaps

1. **`build.ps1` has no DiagnosticKit support** — skipped entirely, no warning
2. **Template test files reference `PluginProcessor` class** — only works after `init_plugin_project.sh` replaces placeholders
3. **FETCHCONTENT_BASE_DIR backslash escaping** — fixed in CMakeLists.txt but worth verifying on fresh Windows install
4. **Shared JUCE cache generator mismatch** — if `~/.juce_cache` was configured with a different generator, delete it: `rmdir /s /q %USERPROFILE%\.juce_cache`
5. **`sed -i` differences** — build.sh uses platform-conditional sed, but init_plugin_project.sh may still use macOS-only `sed -i ''`

---

## Linux (Ubuntu 24.04) — Confidence: LOW

Linux support was added based on patterns from pamplejuce reference project but has NOT been tested on a real machine. CI runs on ubuntu-22.04.

### Prerequisites

```bash
# Install everything
sudo apt-get update
sudo apt-get install -y cmake ninja-build clang git pkg-config \
  libasound2-dev libx11-dev libxinerama-dev libxext-dev \
  libxrandr-dev libxcursor-dev libfreetype6-dev \
  libwebkit2gtk-4.1-dev libglu1-mesa-dev libcurl4-openssl-dev

# Verify
cmake --version
ninja --version
clang++ --version
```

Note: Ubuntu 24.04 may have `libwebkit2gtk-4.1-dev` as a different package name. If it fails:
```bash
apt-cache search webkit2gtk
# Try the available version
```

### Smoke Test

```bash
cd JUCE-Plugin-Starter

# 1. CMake configure + build
./scripts/build.sh all

# 2. Check outputs
ls build/*_artefacts/Release/VST3/
ls build/*_artefacts/Release/Standalone/
```

### Full Verification

- [ ] `./scripts/build.sh` — CMake configures with Clang + Ninja
- [ ] VST3 builds
- [ ] CLAP builds
- [ ] Standalone builds and runs (may need X11 display: `export DISPLAY=:0`)
- [ ] `./scripts/build.sh all test` — PluginVal runs (needs Xvfb: `xvfb-run ./scripts/build.sh all test`)
- [ ] Plugin installs to `~/.vst3/` and `~/.clap/`
- [ ] `./scripts/build.sh all pkg` — creates tar.gz package
- [ ] DiagnosticKit is skipped with warning
- [ ] Load VST3 in Reaper (Linux version) or Bitwig
- [ ] `sed -i` works correctly (no macOS `sed -i ''` leaking through)

### Known Issues / Gaps

1. **libwebkit2gtk package name may differ** across Ubuntu versions
2. **PluginVal on Linux** — CI downloads it; local builds need it installed or the binary in PATH
3. **Headless testing** — needs Xvfb for anything that touches GUI
4. **Visage bridge blocked** — Linux Vulkan bridge not implemented (item 3.2)
5. **init_plugin_project.sh** — uses `sed -i ''` which fails on Linux (GNU sed)

---

## What I Need You To Do

### Immediate (before starting new work)

1. **macOS smoke test** — Run the 3 commands in "Quick Smoke Test" above on an existing project. This takes 5 minutes and confirms nothing is broken.

2. **Windows smoke test** — When your VM is available:
   - Clone the repo, checkout the cross-platform branch
   - Run `.\scripts\build.ps1 all` from a VS Developer Command Prompt
   - Report what works and what fails

### When Linux VM is Ready

3. **Linux smoke test** — Same idea:
   - Install prerequisites
   - Clone, checkout branch
   - Run `./scripts/build.sh all`
   - Report results

### For Porting an Existing Plugin (e.g., PlunderTubeSampler)

4. **Test the porting workflow** — Once the `/juce-dev:port` command exists (see below), try it on PlunderTubeSampler:
   - Run the audit from macOS
   - Push the branch to GitHub
   - Pull on Windows VM and attempt build
   - Report what breaks

---

## Test Results Log

### 2026-03-06: Windows ARM64 VM (UTM, `ssh win`)

**Environment:** Windows 11 ARM64, MSVC 19.44.35219, CMake 4.2.3, Ninja 1.13.2, Git 2.53.0

**Automated (via SSH from macOS):**
| Test | Result | Notes |
|------|--------|-------|
| CMake configure (Ninja + MSVC ARM64) | PASS | 300s, downloads JUCE via FetchContent |
| VST3 build + install | PASS | Installed to `C:\Program Files\Common Files\VST3\` |
| CLAP build | PASS | `.clap` module linked |
| Standalone build | PASS | `.exe` linked |
| Catch2 tests | FAIL (expected) | `PluginProcessor` undefined — template placeholder not replaced |

**Needs Human Testing:**
| Test | Status | Notes |
|------|--------|-------|
| Standalone .exe launches and shows UI | NOT TESTED | Need RDP or local access |
| VST3 loads in Windows DAW | NOT TESTED | Install Reaper on VM |
| PluginVal validation | NOT TESTED | Need PluginVal installed |
| `init_plugin_project.sh` via Git Bash | NOT TESTED | Creates new project with replaced placeholders |
| DiagnosticKit skip warning | NOT TESTED | Run `build.ps1` with ENABLE_DIAGNOSTICS=true |

**Key Learnings:**
- JUCE cache lock files from concurrent SSH sessions can block builds — kill orphan processes first
- `cmd /c` with nested quotes doesn't work over SSH — use `.bat` scripts instead
- VsDevCmd.bat is more reliable than `Enter-VsDevShell` (which changes CWD)

### 2026-03-06: macOS (PlunderTube project, Apple Silicon)

**Automated:**
| Test | Result | Notes |
|------|--------|-------|
| `build.sh standalone` (PlunderTube) | PASS | Built and launched after cache fix |
| CMake configure (Ninja) | PASS | Template repo configures cleanly |
| `build.sh` syntax check | PASS | `bash -n` passes |
| DiagnosticKit JUCE skips on macOS | PASS | Correct message: "macOS uses the native Swift app" |

**Key Issue:** Shared JUCE cache generator conflict — switching between Xcode and Ninja generators requires clearing `~/.juce_cache/` CMake files. Pre-existing issue, not from cross-platform changes.

---

## Proposed: `/juce-dev:port` Command

A new juce-dev command for porting existing macOS JUCE projects to Windows/Linux.

### What It Would Do

```
/juce-dev:port windows        # Audit + plan for Windows
/juce-dev:port linux           # Audit + plan for Linux
/juce-dev:port all             # Audit for all platforms
```

**Stage 1: Audit** — Scans the project for platform-specific dependencies:
- macOS-only APIs (`NSView`, `NSApplication`, `CoreAudio`, `AudioToolbox`, `#if JUCE_MAC`)
- macOS-only build config (Xcode generator, `.app` bundles, `codesign`)
- Hardcoded paths (`~/Library/`, `/usr/local/`)
- Missing platform conditionals in CMakeLists.txt
- External dependencies that may not exist on target platform
- Visage bridge status (macOS Metal vs Windows DirectX vs Linux Vulkan)

**Stage 2: Plan** — Generates a checklist of what needs to change:
- CMakeLists.txt additions (platform conditionals, Ninja generator)
- Source code changes (platform guards, API alternatives)
- Build script changes (build.ps1 for Windows, build.sh Linux path)
- Dependencies to install on target platform
- Known blockers (e.g., Visage bridge not available on target)

**Stage 3: Execute** — Optionally implements the changes:
- Adds platform conditionals to CMakeLists.txt
- Wraps macOS-specific code in `#if JUCE_MAC` guards
- Adds cross-platform alternatives where possible
- Creates/updates build scripts for target platform
- Commits changes to a `port/windows` or `port/linux` branch

**Stage 4: Test** — Guides user through verification:
- "Push this branch and pull it on your Windows VM"
- "Or: trigger a GitHub Actions build to test remotely"
- Provides the exact commands to run on the target platform

### Testing Strategy

The command would offer two paths:

**Local VM (recommended for iterative work):**
```
Push to git → Pull on VM → Build → Fix → Commit → Pull on macOS → Repeat
```

**GitHub Actions (quick validation):**
```
Push to branch → CI builds on all platforms → Check results → Fix locally
```

The user controls which approach via:
```
/juce-dev:port windows --test-local    # Guides VM-based testing
/juce-dev:port windows --test-ci       # Triggers GitHub Actions
```
