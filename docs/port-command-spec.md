# `/juce-dev:port` Command Spec

Port an existing macOS JUCE plugin project to Windows and/or Linux.

## Usage

```
/juce-dev:port <platform> [options]
```

### Platforms

| Platform | What it does |
|----------|-------------|
| `windows` | Audit and port for Windows (MSVC + Ninja) |
| `linux` | Audit and port for Linux (Clang + Ninja) |
| `all` | Audit and port for both |

### Options

| Option | Description |
|--------|-------------|
| `--audit-only` | Just scan and report, don't make changes |
| `--test-local` | After porting, guide through local VM testing |
| `--test-ci` | After porting, trigger GitHub Actions CI |
| `--vm <alias>` | SSH alias for the target platform VM (e.g., `--vm win`) |

### Examples

```
/juce-dev:port windows                    # Audit + port + ask how to test
/juce-dev:port windows --audit-only       # Just scan, show report
/juce-dev:port windows --vm win           # Port and test on VM via ssh win
/juce-dev:port linux --test-ci            # Port and verify via GitHub Actions
/juce-dev:port all --vm win --vm linux    # Port both, test each on its VM
```

---

## Stages

### Stage 0: Detect Project

- Verify we're in a JUCE-Plugin-Starter project (check for CMakeLists.txt, .env, scripts/)
- Read .env for project name, features enabled
- Check git status — warn if uncommitted changes

### Stage 1: Audit

Scan the project for platform-specific dependencies. Output a structured report.

#### What to scan

**Source files (*.cpp, *.h, *.mm):**
- macOS-only APIs: `NSView`, `NSWindow`, `NSApplication`, `NSEvent`, `NSColor`,
  `NSWorkspace`, `NSPasteboard`, `CoreAudio`, `AudioToolbox`, `CoreMIDI`,
  `IOKit`, `Security`, `#import <Cocoa/`, `#import <AppKit/`
- Objective-C++ files (.mm) — need `#if JUCE_MAC` guards or platform alternatives
- `#if JUCE_MAC` / `#if JUCE_WINDOWS` / `#if JUCE_LINUX` — already handled
- Hardcoded macOS paths: `~/Library/`, `/usr/local/`, `.app/Contents/`

**CMakeLists.txt:**
- Generator assumptions (Xcode-only vs Ninja support)
- Platform-conditional blocks: `if(APPLE)` / `elseif(MSVC)` / `elseif(UNIX)`
- macOS-specific: `CMAKE_OSX_DEPLOYMENT_TARGET`, `MACOSX_BUNDLE`, signing
- Missing: Ninja support, MSVC flags, Linux dependencies
- FORMATS list: AU/AUv3 are macOS-only

**Build scripts:**
- `build.sh` — already has Linux support, check for macOS-only paths
- `build.ps1` — exists? If not, needs creation for Windows
- `generate_and_open_xcode.sh` — macOS-only, need Ninja equivalent

**External dependencies:**
- Visage: FULLY CROSS-PLATFORM (Metal/D3D11/Vulkan/WebGL via bgfx). Do NOT skip on non-macOS. JuceVisageBridge may need platform windowing adaptation.
- DiagnosticKit: macOS-only Swift app, will be skipped (JUCE-based cross-platform version planned)
- FetchContent deps: generally cross-platform, but verify

**Configuration:**
- `.env` — any platform-specific values
- `.github/workflows/` — CI for target platform exists?

#### Audit Report Format

```
## Port Audit: PlunderTubeSampler -> Windows

### Platform-Specific Code Found

| File | Line | Issue | Severity |
|------|------|-------|----------|
| Source/PluginEditor.mm | 45 | Objective-C++ file, needs #if JUCE_MAC guard | HIGH |
| Source/Synth/Oscillator.cpp | 12 | #import <Accelerate/Accelerate.h> — use vDSP alternative | MEDIUM |
| CMakeLists.txt | - | No MSVC/Ninja support | HIGH |
| scripts/ | - | No build.ps1 | HIGH |

### Already Cross-Platform

- Source/PluginProcessor.cpp — no platform-specific code
- Source/DSP/*.cpp — pure C++, portable

### Action Items

1. [HIGH] Add Windows platform block to CMakeLists.txt
2. [HIGH] Create scripts/build.ps1
3. [HIGH] Wrap PluginEditor.mm in platform guards
4. [MEDIUM] Replace vDSP with cross-platform alternative
5. [LOW] Add .github/workflows/build.yml Windows matrix entry

### Estimated Effort: MEDIUM
- 3 files need changes
- 1 new file needed (build.ps1)
- No architectural changes required
```

### Stage 2: Plan

Convert audit into an actionable plan. Present to user for approval.

```
question: "Ready to port PlunderTubeSampler to Windows?"
header: "Port Plan"
options:
  - label: "Execute all changes"
    description: "Create port/windows branch, apply 5 changes, ready to test"
  - label: "Execute selectively"
    description: "Walk through each change and approve individually"
  - label: "Export plan only"
    description: "Save the plan to docs/port-windows-plan.md for manual execution"
```

### Stage 3: Execute

Create a feature branch and apply changes:

```bash
git checkout -b port/windows
```

- Add platform conditionals to CMakeLists.txt
- Wrap macOS-specific source code in `#if JUCE_MAC` guards
- Add cross-platform alternatives where possible
- Copy/adapt build.ps1 from JUCE-Plugin-Starter template
- Add CI workflow entries if missing
- Commit with descriptive message

### Stage 4: Test

Ask the user how they want to verify:

```
question: "How do you want to test the Windows port?"
header: "Testing"
options:
  - label: "Local VM"
    description: "I'll guide you through testing on your VM"
  - label: "GitHub Actions"
    description: "Push branch and trigger CI — results in ~5 min"
  - label: "Both"
    description: "CI first for quick check, then VM for thorough testing"
  - label: "Skip testing"
    description: "I'll test later"
```

---

## VM Integration

### Configuration

VM connection details are stored per-project in `.claude/juce-dev.local.md`:

```yaml
---
vms:
  windows:
    ssh: win                    # SSH alias (from ~/.ssh/config)
    project_path: C:\Users\daniel\Code\PlunderTubeSampler
    shell: powershell           # powershell or cmd
  linux:
    ssh: linux                  # SSH alias
    project_path: /home/daniel/Code/PlunderTubeSampler
    shell: bash
---
```

The SSH alias should already be configured in `~/.ssh/config`:

```
Host win
    HostName 192.168.64.4
    User daniel

Host linux
    HostName 192.168.64.5
    User daniel
```

### First-Time Setup

If no VM config exists, the port command asks:

```
question: "Do you have a Windows VM for testing?"
header: "VM Setup"
options:
  - label: "Yes, I can SSH to it"
    description: "Enter your SSH alias (e.g., 'win' if you use 'ssh win')"
  - label: "No, use GitHub Actions"
    description: "CI will test builds remotely"
  - label: "No, skip testing"
    description: "I'll set up a VM later"
```

If "Yes": collect SSH alias, verify connection, ask for project path on VM, save to `.claude/juce-dev.local.md`.

### VM Testing Workflow

When `--vm <alias>` is provided or configured:

```
1. Commit port changes locally
2. Push to remote branch
3. SSH to VM
4. Clone/pull the branch
5. Run build commands
6. Report results back
7. If failures: analyze, fix locally, push, repeat
```

The command would execute:

```bash
# Verify SSH connection
ssh win "echo connected"

# Pull latest on VM
ssh win "cd C:\Users\daniel\Code\PlunderTubeSampler && git pull"

# Run build
ssh win "cd C:\Users\daniel\Code\PlunderTubeSampler && .\scripts\build.ps1 all"
```

For interactive debugging, the command could offer:

```
question: "Build failed on Windows. What would you like to do?"
header: "Debug"
options:
  - label: "Show full error output"
    description: "Display the build log from the VM"
  - label: "SSH into VM"
    description: "Opens an SSH session so you can debug directly"
  - label: "Auto-fix and retry"
    description: "I'll analyze the error, fix locally, push, and rebuild on VM"
```

### Multi-Platform VM Testing

For `--vm win --vm linux` or when both are configured:

```bash
# Test both in parallel (if independent)
ssh win "cd ... && .\scripts\build.ps1 all" &
ssh linux "cd ... && ./scripts/build.sh all" &
wait
```

---

## What This Enables

### Scenario: Port PlunderTubeSampler to Windows

```
$ cd ~/Code/PlunderTubeSampler
$ /juce-dev:port windows --vm win

Auditing PlunderTubeSampler for Windows compatibility...

## Port Audit: PlunderTubeSampler -> Windows

Found 3 issues:
- [HIGH] Source/Visage/JuceVisageBridge.mm — Objective-C++, macOS-only
- [HIGH] No build.ps1
- [LOW] CI workflow missing Windows matrix

Visage is cross-platform (D3D11 on Windows via bgfx).
JuceVisageBridge windowing layer may need platform adaptation.

Ready to port? [Execute all changes / Export plan / Cancel]
> Execute all changes

Created branch: port/windows
Applied 3 changes, committed.
Pushing to origin...

Testing on Windows VM (ssh win)...
Pulling branch on VM...
Running build.ps1...

BUILD SUCCEEDED: VST3, Standalone
BUILD SKIPPED: AU (macOS-only)

Port complete! Your plugin builds on Windows.
Next: Load the VST3 in a Windows DAW to verify it works.
```

### Scenario: No VM, Use CI

```
$ /juce-dev:port windows --test-ci

[same audit + execute steps]

Pushing port/windows branch...
Triggering GitHub Actions build...

Waiting for CI... (check: gh run watch)
Windows build: PASSED
Linux build: PASSED (bonus — CI tests both)

Port verified via CI. For thorough testing, consider a local VM.
```

---

## Implementation Notes

### Third-Party Dependencies & Licensing

The audit should detect and handle third-party dependencies:

**Detection:**
- Scan `CMakeLists.txt` for `FetchContent_Declare`, `add_subdirectory`, `find_package`
- Scan `external/` directory for vendored libraries
- Look for `LICENSE`, `COPYING`, `NOTICE` files referencing third-party code
- Check for Visage (fully cross-platform: Metal/D3D11/Vulkan/WebGL via bgfx — JuceVisageBridge may need windowing adaptation per platform)
- Check for platform-specific frameworks (`CoreAudio`, `AudioToolbox`, `Accelerate`)

**License Management:**
- Detect existing license files (e.g., `LICENSE.md`, `THIRD_PARTY_LICENSES.md`)
- Parse referenced third-party libraries and their licenses
- Generate platform-specific license files if dependencies differ:
  - `LICENSE-macOS.md` — includes macOS-specific deps (Visage Metal backend, CoreAudio)
  - `LICENSE-Windows.md` — includes Windows-specific deps (ASIO SDK if used, DirectX)
  - `LICENSE-Linux.md` — includes Linux-specific deps (ALSA, X11)
- If all deps are cross-platform, keep a single `LICENSE.md`
- Offer to create/update `THIRD_PARTY_LICENSES.md` with per-platform sections

**Visage-Specific Handling:**
- If Visage is detected, confirm it's cross-platform (D3D11/Vulkan/WebGL via bgfx)
- Check JuceVisageBridge for platform-specific windowing code (NSView, HWND, X11)
- Verify bgfx shaderc binary is compatible with target architecture (x86-64 shaderc may crash on ARM64 Windows)
- Check if Windows SDK is installed (needed for D3D11 shader compilation)

### This should be a new juce-dev command, not a skill

- Commands have access to Bash, file tools, AskUserQuestion
- Skills are reference material — this needs to execute actions
- Could reference the `juce-visage` skill when Visage bridge gaps are found

### Relationship to existing commands

- `/juce-dev:build` — port command may invoke build on the VM
- `/juce-dev:create` — new projects get cross-platform from the start; port is for existing projects
- The audit stage is unique to port — it's a codebase analysis tool

### Platform-specific knowledge

The command needs to know:
- Which APIs are macOS-only vs cross-platform (could be a reference file)
- What the JUCE equivalents are for platform-specific code
- Common pitfalls per platform (from cross-platform-learnings.md)

This knowledge could live in a companion skill (`juce-porting`) that the command references.
