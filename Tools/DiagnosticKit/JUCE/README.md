# DiagnosticKit — JUCE C++ (Windows & Linux)

Cross-platform diagnostic collection and reporting app built with JUCE. This is the **Windows and Linux** counterpart to the native Swift/SwiftUI DiagnosticKit used on macOS.

> **Status**: Tested on Windows 10/11. Linux support is implemented but not yet validated on hardware.

## Overview

This JUCE C++ app collects system diagnostics, plugin status, DAW logs, crash reports, and user feedback, then uploads everything as a GitHub issue to a private diagnostics repository. It runs as a standalone GUI application alongside your plugin.

**Key differences from the macOS Swift version:**
- Built with JUCE (C++17) instead of SwiftUI
- Uses GitHub REST API via JUCE HTTP or PowerShell/curl fallbacks
- Platform-specific diagnostics for Windows (registry, DXGI, WASAPI) and Linux (ALSA, PipeWire, package managers)
- Automatically skipped on macOS builds (CMakeLists.txt returns early)

## What's Collected

### System Information
- OS version, architecture, CPU, memory
- GPU info including DXGI adapter details (Windows) or `lspci` (Linux)
- Audio devices (WASAPI/ASIO on Windows, ALSA/PipeWire on Linux)

### Plugin Status
- Installation paths and file sizes for VST3, CLAP, Standalone
- AU/AUv3 on macOS only (not applicable here)

### DAW Diagnostics
- **Ableton Live**: Log.txt, PluginScanDb.txt, crash recovery sessions
- **Bitwig Studio**: log files
- **Reaper**: reaper.log, plugin scan logs
- **Studio One**: logs and crash data
- Relevant log lines extracted with plugin-name-first priority

### DAW Log File Uploads
- Ableton Log.txt, Bitwig logs, and Reaper logs uploaded as file attachments
- All uploaded content is automatically anonymized (username, hostname, paths)

### Additional Checks
- Python environment and virtual environment status
- Plugin dependencies (pip packages, bundled tools)
- Installer artifacts
- Pipeline health checks
- Security info (permissions, signatures)

## Privacy & Anonymization

All diagnostic data is anonymized before upload:
- Windows usernames replaced with `<user>`
- Home directory paths (`C:\Users\you`) replaced with `C:\Users\<user>`
- Computer hostnames replaced with `<hostname>`
- Anonymization applies to **all** collected data including uploaded file attachments

Users review everything collected before anything is sent.

## Building

### Development-Only Build Guard

DiagnosticKit defaults to **OFF** in CMake. You must explicitly opt in:

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_DIAGNOSTICS=ON
```

Without `-DBUILD_DIAGNOSTICS=ON`, CMake prints a skip message and returns early. This prevents accidental inclusion in production installers — even if someone adds DiagnosticKit as a subdirectory to the main project's CMake.

### Prerequisites
- CMake 3.22+
- Ninja (recommended) or MSBuild
- **Windows**: Visual Studio 2022 Build Tools with C++ workload
- **Linux**: Clang or GCC, plus JUCE dependencies (`libasound2-dev`, `libcurl4-openssl-dev`, etc.)

### Windows Build
```powershell
# Load VS developer environment
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

cd Tools/DiagnosticKit/JUCE
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_DIAGNOSTICS=ON
ninja -C build
```

### Linux Build
```bash
cd Tools/DiagnosticKit/JUCE
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_DIAGNOSTICS=ON
ninja -C build
```

The executable is output to `build/DiagnosticKit_artefacts/Release/Standalone/`.

### macOS
On macOS, `CMakeLists.txt` exits early — use the native Swift DiagnosticKit instead.

## Configuration

The app reads from `Tools/DiagnosticKit/.env` (copied next to the executable at build time):

```env
APP_NAME="YourPlugin Diagnostics"
APP_IDENTIFIER="com.yourcompany.yourplugin.diagnostics"
PRODUCT_NAME="YourPlugin"
PLUGIN_NAME="YourPlugin"
GITHUB_REPO="yourorg/yourplugin-diagnostics"
GITHUB_TOKEN="github_pat_..."
```

See `Tools/DiagnosticKit/.env.example` for all available settings.

## Architecture

```
JUCE/
├── CMakeLists.txt              # Build config (auto-skips macOS)
└── Source/
    ├── Main.cpp                # JUCE app entry point
    ├── MainComponent.cpp/h     # UI: idle → collecting → preview → uploading → success
    ├── AppConfig.cpp/h         # Loads .env configuration
    ├── DiagnosticCollector.cpp/h  # Orchestrates all diagnostic collection
    ├── GitHubUploader.cpp/h    # GitHub API: file upload + issue creation
    ├── PlatformDiagnostics.h   # Cross-platform interface
    ├── PlatformDiagnostics_Win.cpp   # Windows-specific collection
    └── PlatformDiagnostics_Linux.cpp # Linux-specific collection
```

### UI Flow
1. **Idle** — Optional email + description fields, trust/privacy info
2. **Collecting** — Progress bar while diagnostics run
3. **Preview** — Full report shown for user review before upload
4. **Uploading** — Progress during GitHub API calls
5. **Success** — Issue URL with copy button

## Development Notes

- **Development-only tool**: DiagnosticKit is intended for development and testing workflows. It should not be exposed as a user-facing CLI in production releases.
- **GitHub token**: Embedded in `.env` which is copied next to the executable. For production distribution, consider a more secure token delivery mechanism.
- **File uploads**: Large files (crash logs, DAW logs) are uploaded as individual files to the diagnostics repo, then linked in the GitHub issue body.
- **PowerShell fallback** (Windows): When JUCE HTTP PUT doesn't work reliably, the uploader falls back to PowerShell `Invoke-RestMethod`.

## Tested Platforms

| Platform | Status |
|----------|--------|
| Windows 10 (x64, MSVC 2022) | Tested, working |
| Windows 11 (x64) | Expected to work |
| Linux (Ubuntu 22.04+, Clang) | Implemented, not yet validated |
