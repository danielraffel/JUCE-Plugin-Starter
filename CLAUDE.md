# Project Configuration

<!--  Start new build plans-->

### ⚡ Faster Build (Skip Regeneration)

If `CMakeLists.txt`, `.env`, or build-related config **has not changed**, Claude should **skip regeneration** to save time:

```bash
# Skip both CMake regeneration AND version bump
SKIP_CMAKE_REGEN=1 SKIP_VERSION_BUMP=1 ./scripts/generate_and_open_xcode.sh
```

This will:

* Reuse the existing `build/` directory
* Avoid re-running CMake
* Avoid version bumping (which invalidates CMake cache)
* Reduce overall build time

#### Claude's Responsibility:

Before each build, Claude must ask:

> Did I change `CMakeLists.txt`, `.env`, or add/remove source files that CMake configures?

* ✅ **If yes**, run full:

  ```bash
  ./scripts/generate_and_open_xcode.sh
  ```
* ✅ **If no**, run faster:

  ```bash
  SKIP_CMAKE_REGEN=1 SKIP_VERSION_BUMP=1 ./scripts/generate_and_open_xcode.sh
  ```

If Claude skips regeneration but the build fails due to stale configuration, try again without `SKIP_CMAKE_REGEN`.

### 🧠 When to Regenerate the Build Directory

Claude must run the **full**:

```bash
./scripts/generate_and_open_xcode.sh
```

If any of the following are true:

* `CMakeLists.txt` or `.cmake` files changed
* `.env` feature flags changed
* Source/header files were **added or removed**
* External dependencies (JUCE, Visage) were updated
* Build errors may be related to stale configuration

Otherwise, Claude may run the **faster**:

```bash
SKIP_CMAKE_REGEN=1 SKIP_VERSION_BUMP=1 ./scripts/generate_and_open_xcode.sh
```

### 📱 After Generating Xcode Project

**IMPORTANT**: After running either generate command, Claude should then:

```bash
./scripts/build.sh standalone
```

This will:
- Build the standalone app
- Automatically launch it so user can see the changes
- Handle version bumping appropriately (only when needed)

<!--  END new build plans-->

### Primary Build Commands

How to use `scripts/build.sh` for builds:

```bash
# Quick build (all formats)
./scripts/build.sh

# Build specific format
./scripts/build.sh au          # Audio Unit only
./scripts/build.sh vst3        # VST3 only
./scripts/build.sh standalone  # Standalone app only

# Build with testing
./scripts/build.sh all test    # Build and run PluginVal tests

# Production builds
./scripts/build.sh all sign     # Build and codesign
./scripts/build.sh all notarize # Build, sign, and notarize
./scripts/build.sh all publish  # Full release with installer
```

### Version Management

Every build automatically increments the version:
- Patch version increases: 0.0.1 → 0.0.2 → 0.0.3
- Build number always increments
- Versions stored in `.env` file

Manual version control:
```bash
python3 scripts/bump_version.py minor  # 0.0.3 → 0.1.0
python3 scripts/bump_version.py major  # 0.0.3 → 1.0.0
```

### Testing Workflow

When running tests with `./scripts/build.sh [target] test`:
1. Builds the plugin
2. Runs PluginVal validation
3. For standalone builds, automatically:
   - Checks if app is already running
   - Kills existing instance if found
   - Launches the newly built app

### Why Use scripts/build.sh?

The `scripts/build.sh` script provides:
- Automatic version bumping
- Project-agnostic configuration (reads from .env)
- Multi-format support (AU, VST3, Standalone)
- **Multi-plugin support** (automatically discovers and builds all plugins in project)
- Integrated testing with PluginVal
- Code signing and notarization
- Installer creation for distribution

> **Note**: The build system automatically handles both single-plugin and multi-plugin projects. If your project has multiple plugins (e.g., PluginFX_AU and PluginKS_AU), all will be discovered and built automatically—no configuration needed.

## Project Structure

- **Build system**: CMake with custom Xcode generation
- **IDE**: Xcode (auto-opened by build script)
- **Build directory**: `./build/`
- **JUCE directory**: `../JUCE/`

## Common Mistakes to Avoid

❌ Never use these commands directly:
- `cmake --build build --config Release`
- `cmake -B build`
- `xcodebuild -project ...`

✅ Always use:
- `./scripts/generate_and_open_xcode.sh` only when CMake regeneration is needed otherise use `SKIP_CMAKE_REGEN=1 ./scripts/generate_and_open_xcode.sh` only when `CMakeLists.txt`, `.env`, or build-related config **has not changed**, Claude can **skip regeneration** to save time:
- `./scripts/build.sh standalone` for building and then open the app once it's built

## Generating Release Notes

When the user runs `./scripts/build.sh publish` with `RELEASE_NOTES_METHOD=claude` in their `.env`, Claude Code should automatically generate user-friendly release notes.

### How Release Notes Work

The build system checks `RELEASE_NOTES_METHOD` in `.env`:
- `claude` = Claude Code generates notes interactively
- `openrouter` = OpenRouter API (requires key)
- `openai` = OpenAI API (requires key)
- `auto` = Try APIs if keys exist, else Python
- `none` = Python categorization only

### When `RELEASE_NOTES_METHOD=claude`

**What happens during publish:**

1. The build script displays recent commits
2. Shows a prompt asking Claude to generate release notes
3. **Claude Code (you) should respond** with the notes in the correct format
4. The script captures your response and uses it for the release

**How Claude should respond:**

When you see the release notes prompt during `./scripts/build.sh publish`, immediately generate notes in this exact format:

```markdown
## Version X.X.X

### ✨ New Features
- [User-friendly description of new features]

### 🔧 Improvements
- [User-friendly description of improvements]

### 🐛 Bug Fixes
- [User-friendly description of bug fixes]
```

### Guidelines for Claude

- Focus on what users (musicians, producers, audio engineers) will notice
- Write in plain language (avoid technical jargon like "refactor", "CMake", etc.)
- Keep it concise (1 sentence per bullet point)
- Skip empty sections

### Example Format

```markdown
## Version 1.2.0

### ✨ New Features
- Added MIDI learn functionality for easy controller mapping
- New preset browser with search and favorites

### 🔧 Improvements
- Reduced CPU usage by 30% for better performance
- Improved audio quality at high sample rates

### 🐛 Bug Fixes
- Fixed crash when loading AU presets in Logic Pro
- Resolved audio glitches during buffer size changes
```

### Bad vs Good Examples

❌ **Bad** (too technical):
- Refactor PluginProcessor to use shared_ptr
- Update CMakeLists.txt build configuration
- Fix memory leak in DSP engine

✅ **Good** (user-focused):
- Improved plugin stability and memory usage
- Fixed rare crash when changing plugin settings
- Better audio quality with reduced distortion

## Tracking Remaining Work

When completing a large feature on JUCE-Plugin-Starter or juce-dev where some work items are intentionally deferred, offer to create GitHub issues on **this repo** (danielraffel/JUCE-Plugin-Starter). Issues for juce-dev plugin work also go here since the two projects are tightly coupled and most implementation lives in this repo.

**Issue conventions:**
- **Naming**: Prefix with the feature area in brackets, e.g. `[Auto-Updates] Phase B — Private distribution mode`. Be specific enough that the title alone tells you what the work is.
- **Labels**: Create a label for the feature area (e.g. `auto-updates`) and apply it to all related issues so they can be filtered together.
- **Series linking**: Add a "Series" section at the bottom of every related issue showing the full ordered list with dependency notes and a "YOU ARE HERE" marker. This makes it obvious which issues to do first and what blocks what.
- **Cross-repo references**: When work spans both JUCE-Plugin-Starter and generous-corp-marketplace (juce-dev plugin), note both repos in a "Repos impacted" section in each issue.

**Never include** API keys, tokens, passwords, private URLs, or any credentials in issue descriptions — these are public issues on public repos.

This prevents losing track of deferred work that lives in proposal docs or progress files that get stale.

## Additional Project Info
See @README.md for general project information.