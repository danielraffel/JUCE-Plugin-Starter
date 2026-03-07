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

- [ ] `./scripts/build.sh standalone` — builds and launches
- [ ] `./scripts/build.sh au` — installs to `~/Library/Audio/Plug-Ins/Components/`
- [ ] `./scripts/build.sh vst3` — installs to `~/Library/Audio/Plug-Ins/VST3/`
- [ ] `./scripts/build.sh clap` — installs to `~/Library/Audio/Plug-Ins/CLAP/`
- [ ] `./scripts/build.sh all test` — PluginVal passes for AU and VST3
- [ ] `./scripts/build.sh all sign` — code signing works (requires Apple Developer certs)
- [ ] `./scripts/build.sh all publish` — creates PKG, DMG, GitHub release
- [ ] Load AU in Logic Pro / GarageBand — plugin appears and processes audio
- [ ] Load VST3 in Reaper / Ableton — plugin appears and processes audio
- [ ] DiagnosticKit builds when `ENABLE_DIAGNOSTICS=true`
- [ ] `./scripts/build.sh uninstall` — removes all installed plugins
- [ ] New project creation: `./scripts/init_plugin_project.sh` completes successfully

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

- [ ] `.\scripts\build.ps1` — CMake configures with Ninja + MSVC
- [ ] VST3 builds and installs to `C:\Program Files\Common Files\VST3\`
- [ ] CLAP builds
- [ ] Standalone .exe builds and runs
- [ ] Catch2 tests compile and pass (may fail if template placeholders not replaced)
- [ ] `build.ps1 test` — PluginVal validates VST3
- [ ] Load VST3 in a Windows DAW (Reaper is free to evaluate)
- [ ] DiagnosticKit is skipped with warning (not yet cross-platform)
- [ ] New project creation works (init_plugin_project.sh via Git Bash)

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
