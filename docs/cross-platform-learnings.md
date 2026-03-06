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

## AUv3 Format in JUCE

- **Date**: 2026-03-06
- **Problem**: AUv3 (Audio Unit v3) is an app extension format (.appex), different from AU/AUv2 (.component). Users may confuse the two since JUCE uses "AU" for v2 internally.
- **Solution**: Added AUv3 to FORMATS in CMakeLists.txt. Clarified naming in build.sh to say "Audio Unit v2 (AU)" and "Audio Unit v3 (AUv3)". AUv3 on macOS is built as a separate target but typically needs to be bundled inside a host app for distribution.
- **Insight**: JUCE's `COPY_PLUGIN_AFTER_BUILD` for AUv3 places the .appex in the build artefacts directory, not in a system plugin folder like AU/VST3. PluginVal cannot validate AUv3 directly. AUv3 is most useful for iOS (AUM, GarageBand, Cubasis) but also works on macOS.
- **Files**: `CMakeLists.txt`, `scripts/build.sh`

## Catch2 v3 Integration with JUCE

- **Date**: 2026-03-06
- **Problem**: Catch2 needs a custom main() when used with JUCE because tests that touch PluginProcessor or PluginEditor require JUCE's MessageManager to be initialized.
- **Solution**: Custom `Catch2Main.cpp` that creates a `juce::ScopedJuceInitialiser_GUI` before running Catch2 sessions. This avoids the need for per-test initialization.
- **Insight**: Link the Tests target against the plugin target itself (not just SharedCode) since we use `${PROJECT_NAME}` directly. Catch2 v3 uses `Catch2::Catch2` (without Main) when providing a custom main. The `catch_discover_tests` integration with CTest is optional but nice for IDE test runners.
- **Files**: `CMakeLists.txt`, `tests/Catch2Main.cpp`

## Template .env sourcing with spaces

- **Date**: 2026-03-06
- **Problem**: The template's `source .env` approach breaks when values contain unquoted spaces (e.g., `PROJECT_NAME=My Plugin 2.0`).
- **Solution**: Pre-existing issue - not fixed in this iteration. Values with spaces must be quoted in .env files.
- **Insight**: When testing template changes, use explicit env vars (`PROJECT_NAME="TestPlugin" cmake ...`) rather than relying on the local .env which may have project-specific quirks.
- **Files**: `scripts/build.sh` (line 24), `.env`

## FETCHCONTENT_BASE_DIR backslash escape on Windows (CMake 4.2+)

- **Date**: 2026-03-06
- **Problem**: `set(FETCHCONTENT_BASE_DIR "$ENV{HOME}/.juce_cache")` expands to `C:\Users\daniel/.juce_cache` on Windows. CMake 4.2's `FetchContent.cmake` interprets the backslash in `C:\Users` as an escape sequence (`\U`), causing `Invalid character escape '\U'` errors during configure.
- **Solution**: Use `file(TO_CMAKE_PATH ...)` to convert the path to forward slashes. Also use `$ENV{USERPROFILE}` as fallback since `$ENV{HOME}` may not be set on Windows.
- **Insight**: Always convert user-provided or environment paths to CMake paths (forward slashes) before using them in CMake variables. This is critical for cross-platform builds. The shared JUCE cache also needs the generator to match — if `~/.juce_cache` was previously configured with a different generator (e.g., Visual Studio), you must delete it before switching to Ninja.
- **Files**: `CMakeLists.txt`

## Windows build validation results (ARM64 UTM VM)

- **Date**: 2026-03-06
- **Problem**: First real test of the Windows build pipeline on an ARM64 Windows 11 VM via UTM.
- **Solution**: Installed Git, CMake, Ninja via winget. VS2022 Community with MSVC was already present. Successfully:
  1. CMake configure with Ninja generator (MSVC ARM64 compiler detected)
  2. Built VST3 plugin (installed to `C:\Program Files\Common Files\VST3\`)
  3. Built CLAP plugin
  4. Built Standalone .exe
  5. Catch2 library compiled (test source compilation failed due to template placeholders — pre-existing issue)
- **Insight**: The Windows build works end-to-end. Key findings:
  - winget is available on Windows 11 ARM64 via `C:\Users\...\AppData\Local\Microsoft\WindowsApps\winget.exe` even when not in PATH
  - VS2022 Community works; BuildTools installer failed (exit code 1) possibly due to Community already being installed
  - MSVC dev environment must be loaded via `Import-Module ...Microsoft.VisualStudio.DevShell.dll; Enter-VsDevShell`
  - `${PROJECT_NAME}_Resources` link fails when no `juce_add_binary_data()` is defined — fixed with `$<TARGET_NAME_IF_EXISTS:...>`
  - Template test files use `PluginProcessor` class name which only exists after `init_plugin_project.sh` replaces placeholders
- **Files**: `CMakeLists.txt`, `scripts/build.ps1`
