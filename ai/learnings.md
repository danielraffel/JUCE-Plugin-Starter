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

## A1.8–A1.10 — EdDSA Signing & Appcast Generation
- sign_update tool is at external/bin/sign_update (downloaded by setup_sparkle.sh)
- sign_update reads EdDSA private key from macOS Keychain; for CI use EDDSA_PRIVATE_KEY env var
- sign_update output format: sparkle:edSignature="<sig>" length="<len>"
- Appcast XML must be generated from template — Sparkle's generate_appcast tool does NOT support PKG-based updates
- Publish pipeline order: build → sign → notarize → PKG → EdDSA-sign → GitHub Release → appcast LAST
- Appcast file lives in repo root as appcast-macos.xml, committed and pushed as final publish step
- generate_release_notes.py --format sparkle already produces HTML suitable for appcast <description>

## Phase A2 — Windows / WinSparkle
- WinSparkle 0.9.2 ZIP from vslavik/winsparkle (NOT nicehash fork — that repo doesn't exist)
- ZIP has nested structure: x64/Release/, ARM64/Release/, Release/ (x86)
- PlunderTube bundled WinSparkle already flattened to x64/ — setup_winsparkle.sh must flatten during extraction
- ZIP also includes bin/ dir with winsparkle-tool.exe (key gen + signing + verification)
- WinSparkle init sequence: set_app_details → set_build_version → set_appcast_url → set_eddsa_public_key → callbacks → init()
- IMPORTANT: win_sparkle_set_dsa_pub_pem() is DEPRECATED — use win_sparkle_set_eddsa_public_key() instead
- WinSparkle has no Info.plist — feed URL and EdDSA key must be compiled in via CMake definitions
- CMake passes AUTO_UPDATE_FEED_URL and AUTO_UPDATE_EDDSA_KEY as compile definitions on Windows
- WinSparkle callbacks are called from background threads — need thread-safe state (std::atomic, std::mutex)
- onCanShutdown returns 1 to allow shutdown; onShutdownRequest calls systemRequestedQuit() for graceful exit
- WinSparkle.dll must be copied next to the standalone .exe (CMake post-build handles this)
- Inno Setup picks up WinSparkle.dll from artifacts/Standalone/ with skipifsourcedoesntexist flag
- Inno Setup handles elevation automatically for {commoncf} (Common Files) paths
- Inno Setup CloseApplications=yes handles locked plugin files in DAW
- Windows appcast uses sparkle:os="windows" attribute in enclosure
- EdDSA signing on Windows: winsparkle-tool.exe sign -f KEYFILE FILENAME
- EdDSA key gen on Windows: winsparkle-tool.exe generate-key -f KEYFILE
- Key file is a local file (unlike macOS Keychain); must be passed via EDDSA_KEY_FILE env var or stored in project root

## A1.11 — Shutdown Callbacks
- Sparkle handles quit-and-relaunch for PKG installs internally
- SPUUpdaterDelegate updater:willInstallUpdate: callback fires before install begins
- Normal JUCE shutdown path handles audio cleanup — no special handling needed
- WinSparkle (Phase A2) will need explicit win_sparkle_set_shutdown_request_callback
