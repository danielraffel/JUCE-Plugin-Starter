# Project Configuration

<!--  Start new build plans-->

### ⚡ Faster Build (Skip Regeneration)

If `CMakeLists.txt`, `.env`, or build-related config **has not changed**, Claude should **skip regeneration** to save time:

```bash
# Skip both CMake regeneration AND version bump
SKIP_CMAKE_REGEN=1 SKIP_VERSION_BUMP=1 ./generate_and_open_xcode.sh
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
  ./generate_and_open_xcode.sh
  ```
* ✅ **If no**, run faster:

  ```bash
  SKIP_CMAKE_REGEN=1 SKIP_VERSION_BUMP=1 ./generate_and_open_xcode.sh
  ```

If Claude skips regeneration but the build fails due to stale configuration, try again without `SKIP_CMAKE_REGEN`.

### 🧠 When to Regenerate the Build Directory

Claude must run the **full**:

```bash
./generate_and_open_xcode.sh
```

If any of the following are true:

* `CMakeLists.txt` or `.cmake` files changed
* `.env` feature flags changed
* Source/header files were **added or removed**
* External dependencies (JUCE, Visage) were updated
* Build errors may be related to stale configuration

Otherwise, Claude may run the **faster**:

```bash
SKIP_CMAKE_REGEN=1 SKIP_VERSION_BUMP=1 ./generate_and_open_xcode.sh
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
- Integrated testing with PluginVal
- Code signing and notarization
- Installer creation for distribution

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
- `./generate_and_open_xcode.sh` only when CMake regeneration is needed otherise use `SKIP_CMAKE_REGEN=1 ./generate_and_open_xcode.sh` only when `CMakeLists.txt`, `.env`, or build-related config **has not changed**, Claude can **skip regeneration** to save time:
- `./scripts/build.sh standalone` for building and then open the app once it's built

## Additional Project Info
See @README.md for general project information.