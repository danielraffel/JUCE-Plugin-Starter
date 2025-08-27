# Unified Build System Documentation

## Overview

The unified build system (`scripts/build.sh`) provides a completely project-agnostic build solution for JUCE audio plugins. It reads all configuration from the `.env` file, making it portable across any JUCE project without modification.

## Key Features

- **100% Project-Agnostic**: Reads PROJECT_NAME and all settings from .env
- **Multi-Format Support**: AU, VST3, Standalone (CLAP removed as requested)
- **Full Build Pipeline**: Local builds, testing, code signing, notarization, and distribution
- **Intelligent Configuration**: Automatically uses DEVELOPER_NAME if COMPANY_NAME not set
- **Automatic Version Management**: Auto-increments version on every build with semantic versioning support
- **GitHub Release Integration**: Full support for creating releases with installers and AI-powered release notes
- **Professional Installer Creation**: Automated PKG/DMG creation with code signing and notarization
- **AI-Enhanced Release Notes**: Automatically generates user-friendly release notes from commit history

## Usage

```bash
./scripts/build.sh [TARGET] [ACTION]
```

### Targets

- `all` - Build all formats (default)
- `au` - Build Audio Unit only
- `vst3` - Build VST3 only
- `standalone` - Build Standalone only

### Actions

- `local` - Build locally without signing (default)
- `test` - Build and run PluginVal tests
- `sign` - Build and code sign
- `notarize` - Build, sign, and notarize
- `publish` - Build, sign, notarize, and publish to GitHub with release

## Examples

```bash
# Quick local build of all formats
./scripts/build.sh

# Build only the AU plugin
./scripts/build.sh au

# Build and sign all formats
./scripts/build.sh all sign

# Test VST3 with PluginVal
./scripts/build.sh vst3 test

# Full release with GitHub publishing
./scripts/build.sh all publish
```

## Configuration

All configuration is read from `.env`:

### Required Variables
- `PROJECT_NAME` - Your plugin name
- `PROJECT_BUNDLE_ID` - Bundle identifier (e.g., com.company.plugin)

### Optional Variables
- `DEVELOPER_NAME` - Used as COMPANY_NAME if not specified
- `BUILD_DIR` - Build directory (default: build)
- `CMAKE_BUILD_TYPE` - Build type (default: Release)

### Signing & Notarization
- `APP_CERT` - Developer ID Application certificate
- `INSTALLER_CERT` - Developer ID Installer certificate
- `APPLE_ID` - Your Apple ID email
- `APP_SPECIFIC_PASSWORD` - App-specific password for notarization
- `TEAM_ID` - Your Apple Developer Team ID

### Version Information
- `VERSION_MAJOR` - Major version number
- `VERSION_MINOR` - Minor version number
- `VERSION_PATCH` - Patch version number
- `VERSION_BUILD` - Build number (auto-incremented)

### GitHub Publishing
- `GITHUB_USER` - Your GitHub username
- `GITHUB_REPO` - Repository name (defaults to PROJECT_NAME)
- `GITHUB_TOKEN` - GitHub personal access token (optional, uses gh CLI auth)
- `OPENROUTER_KEY_PRIVATE` - OpenRouter API key for AI release notes (optional)
- `OPENAI_API_KEY` - OpenAI API key for AI release notes (fallback, optional)
- `RELEASE_NOTES_MODEL` - AI model to use for release notes (default: openai/gpt-4o-mini)

## Build Process

### Local Build
1. Configures CMake with project settings from .env
2. Builds with Xcode for selected formats
3. Installs to standard plugin locations

### Test Build
1. Performs local build
2. Runs PluginVal validation on built plugins
3. Reports test results

### Sign Build
1. Performs local build
2. Code signs all built plugins with APP_CERT
3. Applies hardened runtime and timestamp

### Notarize Build
1. Performs sign build
2. Creates zip archives of plugins
3. Submits to Apple for notarization
4. Waits for completion
5. Staples notarization ticket

### Publish Build (GitHub Release)
1. Performs notarize build (sign + notarize all plugins)
2. Creates installer package (.pkg) with all built formats
3. Signs installer with INSTALLER_CERT
4. Notarizes installer package
5. Creates DMG containing the installer
6. Creates ZIP of DMG for easier distribution
7. Generates AI-powered release notes using git history
8. Creates GitHub release with version tag
9. Uploads PKG, DMG, and ZIP files as release assets

The publish action now fully integrates with GitHub releases, automatically:
- Creating signed and notarized installers
- Generating release notes (AI-enhanced if API keys are configured)
- Publishing to the configured GitHub repository
- Uploading all distribution artifacts

## Plugin Installation Locations

- **AU**: `~/Library/Audio/Plug-Ins/Components/[PROJECT_NAME].component`
- **VST3**: `~/Library/Audio/Plug-Ins/VST3/[PROJECT_NAME].vst3`
- **Standalone**: `build/[PROJECT_NAME]_artefacts/Release/Standalone/[PROJECT_NAME].app`

## Comparison with Previous Scripts

This unified script consolidates and improves upon:
- `build_v2.sh` - Complex project-specific build logic
- `sign_and_package_plugin.sh` - Separate signing/packaging (logic now integrated)
- `sign_and_package_plugin_v2.sh` - Advanced installer creation (features extracted and integrated)
- `quick_build.sh` - Quick build functionality
- `generate_and_open_xcode.sh` - Still used for initial CMake generation

### Key Improvements
1. **Single Source of Truth**: All config in .env
2. **No Hardcoded Names**: PROJECT_NAME read from environment
3. **Simplified Interface**: Clear target/action structure
4. **Better Error Handling**: Validates required variables
5. **Cleaner Output**: Color-coded status messages
6. **Integrated Installer Creation**: PKG/DMG creation built into publish workflow
7. **GitHub Release Automation**: Direct publishing to GitHub with artifacts
8. **AI Release Notes**: Intelligent release note generation from commits

## Troubleshooting

### Build Fails
- Ensure `.env` has required variables
- Check Xcode installation
- Verify CMake is installed

### Signing Fails
- Verify certificates in Keychain
- Check APP_CERT matches certificate name exactly
- Ensure certificates are valid and not expired

### Notarization Fails
- Verify APPLE_ID and APP_SPECIFIC_PASSWORD
- Check TEAM_ID is correct
- Ensure Apple Developer account is active

### GitHub Publishing Fails
- Ensure GitHub CLI is installed and authenticated (`gh auth login`)
- Verify GITHUB_USER matches your GitHub username
- Check repository exists and you have push access
- Verify release artifacts exist on Desktop before publishing

## Integration with CI/CD

The script is designed for easy CI/CD integration:

```bash
# CI build and test
./scripts/build.sh all test

# Release pipeline
./scripts/build.sh all publish
```

Environment variables can be set by CI system instead of .env file.

## Version Management

The build system includes automatic version management through `scripts/bump_version.py`. This script is automatically called on every build to increment the version.

### Manual Version Control

You can also run the version script manually:

```bash
# Bump patch version (0.0.X)
python3 scripts/bump_version.py

# Bump minor version (0.X.0)
python3 scripts/bump_version.py minor

# Bump major version (X.0.0)
python3 scripts/bump_version.py major

# Only increment build number
python3 scripts/bump_version.py build

# Preview changes without modifying files
python3 scripts/bump_version.py --dry-run

# Export current version as shell variables
python3 scripts/bump_version.py --export-only
```

### Version Behavior

- **Automatic**: Every build increments patch version and build number by default
- **Semantic**: Follows semantic versioning (MAJOR.MINOR.PATCH)
- **Build Number**: Always increments on every version change
- **File Updates**: Automatically updates both `.env` and `CMakeLists.txt`

### Version Reset Rules

- **Major bump**: Resets minor and patch to 0
- **Minor bump**: Resets patch to 0
- **Patch bump**: Only increments patch
- **Build number**: Always increments, never resets

### Version Display

Versions are displayed as:
- **Standard**: `1.2.3` (major.minor.patch)
- **With Build**: `1.2.3.45` (includes build number)
- **AU Integer**: Calculated as `(major << 16) | (minor << 8) | patch`

The version is automatically included in:
- Plugin metadata
- Info.plist files
- Installer packages
- DMG volumes
- GitHub releases

## Complete Publishing Workflow

The `publish` action provides a complete end-to-end release pipeline:

### What Gets Published

When you run `./scripts/build.sh all publish`, the following artifacts are created and uploaded:

1. **Installer Package (.pkg)**
   - Contains all built plugin formats (AU, VST3)
   - Includes standalone app if built
   - Signed with your Developer ID Installer certificate
   - Notarized by Apple for Gatekeeper approval

2. **Disk Image (.dmg)**
   - Professional installer experience
   - Contains the .pkg installer
   - Signed and ready for distribution
   - Volume name includes version number

3. **ZIP Archive (.zip)**
   - Compressed version of the DMG
   - Optimized for download size
   - Easier distribution via web/email

### Publishing Requirements

To use the publish action, ensure you have:

1. **Apple Developer Certificates**
   - Developer ID Application certificate
   - Developer ID Installer certificate
   - Both installed in your Keychain

2. **GitHub CLI Authentication**
   ```bash
   gh auth login
   ```

3. **Environment Variables Set**
   - All signing/notarization credentials in .env
   - GitHub username and repository configured
   - Optional: API keys for AI release notes

### Publishing Process Flow

```
Build → Sign → Notarize → Package → Create Installer → Generate Notes → Create Release → Upload
```

Each step validates before proceeding, ensuring a reliable release process.

## AI-Powered Release Notes

The build system can automatically generate release notes using AI when publishing to GitHub:

### API Configuration

The system supports multiple AI providers in priority order:
1. **OpenRouter** - Set `OPENROUTER_KEY_PRIVATE` in .env
2. **OpenAI** - Set `OPENAI_API_KEY` in .env  
3. **Git Fallback** - Uses git log if no API keys available

### Release Notes Generation

When using the `publish` action, the system:
- Analyzes git commits since the last release
- Generates structured release notes with AI assistance
- Falls back to git log summary if AI APIs unavailable
- Includes version information and commit highlights

The release notes are generated by `scripts/generate_release_notes.py`, which can also be used standalone:

```bash
# Generate standard release notes
python3 scripts/generate_release_notes.py --version 1.0.0

# Generate AI-enhanced release notes (requires API keys)
python3 scripts/generate_release_notes.py --version 1.0.0 --ai

# Generate HTML format for Sparkle updater
python3 scripts/generate_release_notes.py --version 1.0.0 --format sparkle
```

### Example AI Release Notes

```markdown
## What's New in v1.2.3

### ✨ New Features
- Enhanced XY modulation system with improved parameter mapping
- Added new LFO modulation matrix for advanced sound design

### 🐛 Bug Fixes  
- Fixed MIDI velocity handling in standalone mode
- Resolved plugin state restoration issues

### 🔧 Improvements
- Optimized DSP performance for better real-time processing
- Updated UI responsiveness and visual feedback
```

## Supporting Scripts and Tools

The build system leverages several supporting scripts:

### Version Management (`scripts/bump_version.py`)
- Handles semantic versioning
- Updates both .env and CMakeLists.txt
- Enforces Audio Unit version limits (0-255 per component)
- Supports major, minor, patch, and build increments

### Release Notes Generator (`scripts/generate_release_notes.py`)
- Analyzes git commit history
- Categorizes changes (features, fixes, improvements)
- Integrates with OpenRouter and OpenAI APIs
- Supports multiple output formats (Markdown, HTML/Sparkle)
- Falls back to standard git log if AI unavailable

### Build System Features

#### Smart Variable Handling
- Backward compatibility (supports both APP_SPECIFIC_PASSWORD and APP_PASSWORD)
- Automatic fallbacks for missing optional variables
- Environment variable validation before operations

#### Cross-Format Support
- Automatically detects which formats are built
- Includes all available formats in installers
- Handles missing formats gracefully

#### Error Recovery
- Validates certificates before signing
- Checks for GitHub CLI authentication
- Provides clear error messages with solutions

## Best Practices

1. **Before Publishing**
   - Commit all changes
   - Test your plugin thoroughly
   - Ensure version numbers are appropriate
   - Verify certificates are valid

2. **Version Strategy**
   - Use semantic versioning consistently
   - Let the build system auto-increment for development
   - Manually bump major/minor for releases

3. **Release Notes**
   - Write descriptive commit messages
   - Use conventional commit format when possible
   - Configure AI API keys for best results

4. **Security**
   - Never commit .env file
   - Store API keys securely
   - Rotate app-specific passwords regularly
   - Keep certificates in login keychain only