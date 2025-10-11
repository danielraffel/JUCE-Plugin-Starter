# DiagnosticKit

> ⚠️ **Work In Progress** - DiagnosticKit integration is currently under development.

## Overview

DiagnosticKit is a macOS application that helps your plugin users submit diagnostic reports when they encounter issues.

**Features:**
- One-click diagnostic collection
- Automatic GitHub issue creation in private repository
- System info, crash logs, and plugin status
- No Terminal commands required for users

## Current Status

DiagnosticKit is **marked as WIP** in this template. The infrastructure is in place, but the full implementation requires:

1. Swift/SwiftUI application code
2. GitHub Personal Access Token (PAT) setup
3. Private diagnostic repository configuration
4. Build scripts and entitlements

## Reference Implementation

For a complete working implementation, see:
**[PlunderTube DiagnosticKit](https://github.com/danielraffel/PlunderTube/tree/main/Tools/DiagnosticKit)**

The PlunderTube implementation includes:
- Complete Swift/SwiftUI app
- Build scripts (`Scripts/build_app.sh`)
- `.env.example` configuration template
- GitHub API integration
- Entitlements and code signing

## Setup (When Ready)

When DiagnosticKit is fully integrated into this template, setup will involve:

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
   ./scripts/build.sh diagnostics
   ```

## Integration Points

The build system already has placeholders for DiagnosticKit:

- `scripts/build.sh` - Checks for `DIAGNOSTIC_PATH` variable
- `scripts/create_installer()` - Counts diagnostics app for smart /Applications organization
- `scripts/uninstall_template.sh` - Handles diagnostics app removal
- `.env` - `ENABLE_DIAGNOSTICS` flag

## Contributing

If you'd like to help complete the DiagnosticKit integration:

1. Review the PlunderTube implementation
2. Adapt the Swift app to be project-agnostic (use template placeholders)
3. Create the `setup_diagnostic_repo.sh` script
4. Update build.sh to build the Swift app
5. Test the complete workflow
6. Submit a PR!

## Temporary Workaround

Until DiagnosticKit is fully integrated, you can:

1. Copy PlunderTube's DiagnosticKit directory structure
2. Manually replace project-specific values
3. Build manually with Xcode

Or simply wait for the full integration in a future release.
