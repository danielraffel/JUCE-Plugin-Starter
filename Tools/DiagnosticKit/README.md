# DiagnosticKit

> **Work In Progress** - DiagnosticKit integration is currently under development.

## Overview

DiagnosticKit helps your plugin users submit diagnostic reports when they encounter issues. It collects system info, plugin status, crash logs, and DAW diagnostics, then uploads everything as a GitHub issue to a private repository.

**Two implementations:**

| Platform | Implementation | Status |
|----------|---------------|--------|
| **macOS** | Swift/SwiftUI native app | WIP in this template ([reference implementation](https://github.com/danielraffel/PlunderTube/tree/main/Tools/DiagnosticKit)) |
| **Windows & Linux** | JUCE C++ cross-platform app | Tested on Windows, Linux not yet validated |

**Features:**
- One-click diagnostic collection
- Automatic GitHub issue creation in private repository
- System info, crash logs, DAW logs, and plugin status
- Privacy-focused: usernames, paths, and hostnames automatically anonymized
- No Terminal commands required for users
- User reviews all collected data before upload

## Platform-Specific Details

### macOS (Swift/SwiftUI)

See the [PlunderTube DiagnosticKit](https://github.com/danielraffel/PlunderTube/tree/main/Tools/DiagnosticKit) for the complete macOS implementation including:
- SwiftUI app with multiple views
- macOS Keychain token storage
- Build scripts and entitlements
- Code signing and notarization

### Windows & Linux (JUCE C++)

See [`JUCE/README.md`](JUCE/README.md) for the cross-platform JUCE implementation including:
- Windows-specific diagnostics (registry, DXGI, WASAPI)
- Linux-specific diagnostics (ALSA, PipeWire, package managers)
- DAW log file uploads (Ableton, Bitwig, Reaper, Studio One)
- Automatic data anonymization
- PowerShell fallback for GitHub API on Windows

> **Note**: The JUCE C++ version has been tested on Windows 10/11. Linux builds compile but have not yet been validated on hardware. We'll update this when Linux testing is complete.

## Development Note

DiagnosticKit is intended as a **development and testing tool**. The CLI diagnostic surface should not be included in production release artifacts. The GUI app can be distributed to end users, but the underlying diagnostic collection should be treated as a development-time capability.

## Setup

1. **Enable in project creation**:
   ```bash
   # During ./scripts/init_plugin_project.sh
   # Answer "yes" to "Enable DiagnosticKit?"
   ```

2. **Run setup script**:
   ```bash
   ./scripts/setup_diagnostic_repo.sh
   ```

3. **Configure GitHub PAT**:
   - Create fine-grained PAT at github.com/settings/tokens
   - Grant "Issues: Read and Write" permission
   - Scope to diagnostic repository only

4. **Build diagnostics app**:
   ```bash
   # macOS (Swift)
   ./scripts/build.sh diagnostics

   # Windows (JUCE C++ — from Tools/DiagnosticKit/JUCE/)
   cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && ninja -C build

   # Linux (JUCE C++ — from Tools/DiagnosticKit/JUCE/)
   cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && ninja -C build
   ```

## Integration Points

The build system already has placeholders for DiagnosticKit:

- `scripts/build.sh` - Checks for `DIAGNOSTIC_PATH` variable
- `scripts/create_installer()` - Counts diagnostics app for smart /Applications organization
- `scripts/uninstall_template.sh` - Handles diagnostics app removal
- `.env` - `ENABLE_DIAGNOSTICS` flag

## Reference Implementation

For the most complete working implementation, see:
**[PlunderTube DiagnosticKit](https://github.com/danielraffel/PlunderTube/tree/main/Tools/DiagnosticKit)**
