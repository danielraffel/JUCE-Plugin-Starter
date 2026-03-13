# Cross-Platform Testing Guide

**Branch:** `integrate/cross-platform`
**Purpose:** Verify the cross-platform starter template works end-to-end on macOS, Windows, and iOS before merging to `main`.

This document is a testing checklist for you (Daniel). It won't ship with the template — it lives in `docs/` which gets cleaned up before the final merge to `main`.

---

## 0. Before You Start

Make sure you're on the integration branch:

```bash
cd /Users/danielraffel/Code/JUCE-Plugin-Starter
git checkout integrate/cross-platform
```

---

## 1. GitHub Actions CI/CD

The CI workflow (`.github/workflows/build.yml`) triggers on pushes to `main` and `feature/**` branches. The `integrate/**` pattern isn't included, so you have two options:

### Option A: Push the branch and trigger CI manually

```bash
git push -u origin integrate/cross-platform
```

Then go to **Actions** > **Build & Test** > **Run workflow** and select `integrate/cross-platform` from the branch dropdown. The workflow has `workflow_dispatch` enabled so this works.

### Option B: Temporarily add the branch pattern

Edit `.github/workflows/build.yml` line 6:

```yaml
# Change this:
branches: [main, "feature/**"]
# To this:
branches: [main, "feature/**", "integrate/**"]
```

Then push — CI will trigger automatically. (Revert before merging to main.)

### What CI Tests

The matrix builds on all three platforms:
- **macOS** (macos-14, arm64+x86_64 universal binary via Ninja)
- **Windows** (windows-latest, MSVC + Ninja)
- **Linux** (ubuntu-22.04, Clang + Ninja)

Each platform: CMake configure, build, Catch2 unit tests, pluginval VST3 validation, artifact upload.

### What to Check in CI Results

- [ ] All 3 platforms build successfully (green checks)
- [ ] Catch2 tests pass on all platforms
- [ ] pluginval validates VST3 on macOS and Linux (Windows pluginval may crash in CI due to headless GPU — that's a known issue, not a blocker)
- [ ] Build artifacts are uploaded and downloadable

---

## 2. Create a Test Plugin Project

Use `init_plugin_project.sh` from the integration branch to create a fresh plugin. This is the real end-to-end test — it exercises the template the way a new user would.

### Test Plugin Proposal: "TinySynth"

A minimal subtractive synth that exercises the key template features without being complex:

**What it does:**
- Generates a sawtooth oscillator
- Applies a simple low-pass filter with a cutoff knob
- Has an ADSR envelope
- Responds to MIDI note on/off

**Why this is a good test:**
- Uses `juce_audio_utils` and `juce_dsp` (tests JUCE module linking)
- Needs MIDI input (tests plugin I/O configuration)
- Has a simple UI with a few knobs (tests editor rendering)
- Builds as Standalone, AU, VST3, and CLAP (tests all format targets)
- Small enough to build in a few minutes on any platform

### Create the Project

```bash
cd /Users/danielraffel/Code/JUCE-Plugin-Starter
./scripts/init_plugin_project.sh
```

When prompted:
- **Plugin name:** TinySynth
- **Developer name:** (your name)
- **GitHub repo:** Optional — create one if you want to test CI on the new project too
- **DiagnosticKit:** Skip for this test (say no)

The script will create `../TinySynth/` with all template files customized.

---

## 3. macOS Testing

```bash
cd ../TinySynth
```

### 3.1 Build All Formats

```bash
# Build everything
./scripts/build.sh

# Or build individually to isolate issues:
./scripts/build.sh standalone
./scripts/build.sh au
./scripts/build.sh vst3
./scripts/build.sh clap
./scripts/build.sh auv3
```

- [ ] Standalone builds and launches
- [ ] AU builds (check `~/Library/Audio/Plug-Ins/Components/TinySynth.component`)
- [ ] VST3 builds (check `~/Library/Audio/Plug-Ins/VST3/TinySynth.vst3`)
- [ ] CLAP builds (check `~/Library/Audio/Plug-Ins/CLAP/TinySynth.clap`)
- [ ] AUv3 builds (check build artefacts for `.appex`)

### 3.2 Run Tests

```bash
./scripts/build.sh all test
```

- [ ] Catch2 unit tests pass
- [ ] pluginval validates AU
- [ ] pluginval validates VST3

### 3.3 Xcode Project

```bash
./scripts/generate_and_open_xcode.sh
```

- [ ] Xcode project opens without errors
- [ ] Can select and build each scheme (Standalone, AU, VST3)
- [ ] Standalone scheme runs the app

### 3.4 DAW Testing (Optional but Recommended)

- [ ] Open Logic Pro, scan for new plugins
- [ ] TinySynth appears as an AU instrument
- [ ] Can instantiate it on a software instrument track
- [ ] Plugin window opens and shows the default UI
- [ ] MIDI input triggers audio output (even if it's just the template sine wave)

### 3.5 Build TinySynth Into a Synth

Once the template builds clean, add the actual synth functionality. Use Claude Code or your preferred AI tool:

**Prompt suggestion:**
> Add a simple subtractive synth to this JUCE plugin. It should have:
> - A sawtooth oscillator that responds to MIDI note on/off
> - A low-pass filter with a cutoff frequency knob (20Hz-20kHz)
> - An ADSR envelope controlling amplitude
> - A simple UI with knobs for cutoff, attack, decay, sustain, release
> - Use juce_dsp module for the filter and oscillator
>
> Keep it minimal — this is a test of the build system, not a production synth.

After implementing:
- [ ] Standalone plays sound when pressing keys
- [ ] AU works in Logic Pro with MIDI input
- [ ] VST3 works in a DAW

---

## 4. Windows Testing

### 4.1 Get the Code on Windows

If you created a GitHub repo for TinySynth:
```powershell
git clone https://github.com/danielraffel/TinySynth.git
cd TinySynth
```

If not, SCP or copy the project folder to `win2`.

### 4.2 Install Dependencies

```powershell
# If dependencies aren't already installed on win2:
# CMake, Ninja, VS2022 Build Tools should already be there
# If not: .\scripts\dependencies.sh (or manual install)
```

### 4.3 Build

```powershell
.\scripts\build.ps1
.\scripts\build.ps1 standalone
.\scripts\build.ps1 vst3
```

- [ ] CMake configures without errors
- [ ] Standalone builds and produces `.exe`
- [ ] VST3 builds and produces `.vst3` bundle
- [ ] Standalone launches on win2 (check via Proxmox console)

### 4.4 Run Tests

```powershell
.\scripts\build.ps1 all test
```

- [ ] Catch2 tests pass
- [ ] pluginval runs (may crash on VM — note result but don't block on it)

---

## 5. iOS Testing (AUv3)

### 5.1 Open in Xcode

From the TinySynth macOS project:
```bash
./scripts/generate_and_open_xcode.sh
```

### 5.2 Build AUv3

- [ ] Select the AUv3 scheme in Xcode
- [ ] Set destination to an iOS Simulator or connected device
- [ ] Build succeeds

### 5.3 Test in Host App

- [ ] Deploy to simulator/device
- [ ] Open GarageBand or AUM
- [ ] TinySynth appears as an available AUv3 instrument
- [ ] Can instantiate and hear audio

> **Note:** AUv3 on iOS may need additional entitlements or provisioning profile setup. If it builds but doesn't appear in the host, that's a configuration issue to document, not a template bug.

---

## 6. Template Features to Verify

Beyond building, check that these template features work correctly:

### 6.1 init_plugin_project.sh

- [ ] All placeholder text replaced (no "MyCoolPlugin", "BUNDLE_ID_PLACEHOLDER", etc.)
- [ ] `.env` file populated correctly
- [ ] Git repo initialized in new project
- [ ] GitHub repo created (if selected)
- [ ] All scripts are executable

### 6.2 Version Management

```bash
python3 scripts/bump_version.py minor
cat .env | grep VERSION
```

- [ ] Version bumps correctly
- [ ] Build picks up new version

### 6.3 Dependencies Script

```bash
./scripts/dependencies.sh
```

- [ ] Detects platform correctly (macOS)
- [ ] Reports installed/missing tools accurately
- [ ] Doesn't reinstall things that are already present

### 6.4 .clang-format

- [ ] File exists in new project
- [ ] Formatting rules apply when running clang-format on Source files

### 6.5 Catch2 Tests

- [ ] `tests/` directory exists with example tests
- [ ] Tests compile and run via `./scripts/build.sh all test`
- [ ] Can add a new test file and it's auto-discovered

---

## 7. CI/CD on the New Project (If GitHub Repo Created)

If you created a GitHub repo for TinySynth:

### 7.1 Push and Check Actions

```bash
cd ../TinySynth
git push origin main
```

- [ ] GitHub Actions workflow triggers
- [ ] macOS build passes
- [ ] Windows build passes
- [ ] Linux build passes
- [ ] Artifacts are uploaded

### 7.2 Check Artifact Quality

Download the artifacts from the Actions run:
- [ ] macOS artifact contains Standalone app and plugin bundles
- [ ] Windows artifact contains `.exe` and `.vst3`
- [ ] Linux artifact contains binary and `.vst3`

---

## 8. Known Issues / Expected Behaviors

Things that are **not bugs** — just current limitations:

| Issue | Platform | Notes |
|-------|----------|-------|
| pluginval may crash | Windows VM | GPU rendering in headless VM — tracked in issue #242 |
| AUv3 needs provisioning | iOS | Apple Developer account + profile needed for device testing |
| Linux untested locally | Linux | Builds in CI, no local VM yet — deferred |
| DiagnosticKit not tested | All | Skipped for this test — it's an optional feature |

---

## 9. Results Log

Fill in as you test:

| Test | macOS | Windows | iOS | Notes |
|------|-------|---------|-----|-------|
| init_plugin_project.sh | | | N/A | |
| Standalone builds | | | N/A | |
| AU builds | | N/A | N/A | |
| VST3 builds | | | N/A | |
| CLAP builds | | | N/A | |
| AUv3 builds | | N/A | | |
| Catch2 tests pass | | | N/A | |
| pluginval passes | | | N/A | |
| Xcode project opens | | N/A | | |
| DAW loads plugin | | | | |
| CI/CD passes | | | | |
| Synth plays audio | | | | |

---

## 10. After Testing

Once you're satisfied:

1. Note any issues found in the results log above
2. Fix any blocking issues on the `integrate/cross-platform` branch
3. When ready, we'll clean up planning docs from `docs/` and merge to `main`
4. After merge, old feature branches can be deleted (they're preserved for now)
