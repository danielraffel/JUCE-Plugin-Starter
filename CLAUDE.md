# Project Configuration

## Build System

**CRITICAL**: This project uses a custom build script. DO NOT use cmake commands directly.

### Build Commands

- **Build project**: `./generate_and_open_xcode.sh`
- **Clean build**: `rm -rf build/ && ./generate_and_open_xcode.sh`

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
