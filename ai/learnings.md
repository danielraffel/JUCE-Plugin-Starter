# Auto-Update Implementation Learnings

## PlunderTube Reference Notes
- PlunderTube downloads Sparkle 2.8.0 as xcframework (tar.xz), renames to `Sparkle/`
- The actual framework path inside is `Sparkle/macos-arm64_x86_64/Sparkle.framework`
- PlunderTube uses a two-repo model we are NOT reproducing
- PlunderTube injects PAT via configure_file() — we skip this for public mode

## A1.1 — setup_sparkle.sh
- Sparkle 2.8.0 tar.xz extracts FLAT into the target directory — NOT as xcframework
- Actual structure: external/Sparkle.framework, external/bin/ (tools), external/Symbols/
- PlunderTube's script expected Sparkle.xcframework — that was wrong for 2.8.0
- Tools (sign_update, generate_keys) are in external/bin/, NOT inside the framework

## A1.3 — AutoUpdater_Mac.mm
- Use initWithStartingUpdater:NO then explicit startUpdater: for deferred init
- PlunderTube used initWithStartingUpdater:YES — we use NO for explicit lifecycle control
- No PAT injection needed for public mode — Sparkle reads SUFeedURL from Info.plist
- No feedURLStringForUpdater: delegate override needed — rely on Info.plist SUFeedURL
- Guard file with #if JUCE_MAC && ENABLE_AUTO_UPDATE && ENABLE_SPARKLE

## A1.7 — StandaloneApp.cpp
- Must use JUCE_USE_CUSTOM_PLUGIN_STANDALONE_APP=1 to replace default standalone
- Use StandaloneFilterWindow directly — don't try to manually create PluginHolder
- On macOS, use setMacMainMenu with extra apple menu items for app name menu
- On Windows, use a "Help" menu (no file menu in standalone)
- Initialize AutoUpdater via Timer::callAfterDelay(500) — NOT during static init
- StandaloneApp.cpp is always compiled for Standalone but guards with #if ENABLE_AUTO_UPDATE

## Build Issues
- AutoUpdater_Mac.mm must #include "AutoUpdater.h" BEFORE the #if JUCE_MAC guard,
  because JUCE_MAC is defined by JuceHeader.h (included via AutoUpdater.h)
- StandaloneFilterWindow constructor in JUCE 8.x takes 4 args (title, colour, settings, takeOwnership)
- Environment vars must be exported when invoking cmake --build for post_build.sh to see them
- The shared JUCE cache (~/.juce_cache) can have stale generator state from Xcode builds —
  delete it if switching between Xcode and Ninja generators
