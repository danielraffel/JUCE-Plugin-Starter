# Project Configuration

## Build System

**CRITICAL**: This project uses a custom build script. DO NOT use cmake commands directly.

### Build Commands

- **Build project**: `./generate_and_open_xcode.sh`
- **Clean build**: `rm -rf build/ && ./generate_and_open_xcode.sh`

### Faster Build (Skip Regeneration)

If `CMakeLists.txt`, `.env`, or build-related config **has not changed**, Claude should **skip regeneration** to save time:

```bash
SKIP_CMAKE_REGEN=1 ./generate_and_open_xcode.sh
```

This will:

* Reuse the existing `build/` directory
* Avoid re-running CMake
* Reduce overall build time

#### Claude’s Responsibility:

Before each build, Claude must ask:

> Did I change `CMakeLists.txt`, `.env`, or add/remove source files that CMake configures?

* ✅ **If yes**, run full:

  ```bash
  ./generate_and_open_xcode.sh
  ```
* ✅ **If no**, run faster:

  ```bash
  SKIP_CMAKE_REGEN=1 ./generate_and_open_xcode.sh
  ```

If Claude skips regeneration but the build fails due to stale configuration, try again without `SKIP_CMAKE_REGEN`.
<!--  Additional build details-->
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
SKIP_CMAKE_REGEN=1 ./generate_and_open_xcode.sh
```

### Why Use the Custom Script?

The `generate_and_open_xcode.sh` script handles:
- CMake configuration with correct flags
- Xcode project generation
- Environment-specific settings
- Automatic Xcode launch with proper scheme

## Project Structure

- **Build system**: CMake with custom Xcode generation
- **IDE**: Xcode (auto-opened by build script)
- **Build directory**: `./build/`
- **JUCE directory**: `../JUCE/`

## Common Mistakes to Avoid

❌ Never use these commands:
- `cmake --build build --config Release`
- `cmake -B build`
- `xcodebuild -project ...`

✅ Always use:
- `./generate_and_open_xcode.sh`

## Additional Project Info

See @README.md for general project information.
