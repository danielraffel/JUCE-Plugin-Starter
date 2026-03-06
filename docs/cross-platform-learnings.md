# Cross-Platform Learnings

Development learnings, gotchas, and insights discovered during cross-platform expansion. Check this before starting work - it may save you time.

## Format

Each entry:
- **Date**: When discovered
- **Problem**: What went wrong or was non-obvious
- **Solution**: What fixed it
- **Insight**: Key takeaway
- **Files**: Relevant file references

---

## CLAP Integration via clap-juce-extensions

- **Date**: 2026-03-06
- **Problem**: CLAP format is not natively supported by JUCE's `juce_add_plugin()` FORMATS list. It must be added separately.
- **Solution**: Use `FetchContent_Declare` for `clap-juce-extensions` from `https://github.com/free-audio/clap-juce-extensions.git`, then call `clap_juce_extensions_plugin(TARGET ...)` after `target_link_libraries`. The CLAP target is created automatically as `${PROJECT_NAME}_CLAP`.
- **Insight**: CLAP is added as a separate step after the main JUCE plugin target, not via the FORMATS parameter. The extension creates its own CMake target. PluginVal does not support CLAP validation directly.
- **Files**: `CMakeLists.txt`, `scripts/build.sh`

## Template .env sourcing with spaces

- **Date**: 2026-03-06
- **Problem**: The template's `source .env` approach breaks when values contain unquoted spaces (e.g., `PROJECT_NAME=My Plugin 2.0`).
- **Solution**: Pre-existing issue - not fixed in this iteration. Values with spaces must be quoted in .env files.
- **Insight**: When testing template changes, use explicit env vars (`PROJECT_NAME="TestPlugin" cmake ...`) rather than relying on the local .env which may have project-specific quirks.
- **Files**: `scripts/build.sh` (line 24), `.env`
