#pragma once

#include <JuceHeader.h>
#include <functional>

/**
 * AutoUpdater — Cross-platform auto-update interface for Standalone app.
 *
 * macOS: Sparkle 2.x (AutoUpdater_Mac.mm)
 * Windows: WinSparkle (AutoUpdater_Win.cpp)
 * Other/disabled: no-op stub (below)
 *
 * The updater UI lives in the Standalone app only. The update payload is a
 * full product installer (PKG on macOS, Inno Setup on Windows) that replaces
 * all plugin formats (AU, VST3, CLAP, Standalone).
 */
class AutoUpdater
{
public:
    enum class State
    {
        Idle,
        Checking,
        UpdateAvailable,
        Downloading,
        ReadyToInstall,
        NoUpdateAvailable,
        Error
    };

    static AutoUpdater& getInstance();

    // Lifecycle — call initialize() after main window is shown, not during static init
    void initialize();
    void shutdown();

    // Manual checks
    void checkForUpdates();       // Shows UI (progress, result)
    void checkInBackground();     // Silent, no UI unless update found

    // State
    State getState() const;
    bool isUpdateAvailable() const;
    juce::String getAvailableVersion() const;
    juce::String getLastError() const;
    juce::Time getLastCheckTime() const;

    // Preferences
    bool isAutoCheckEnabled() const;
    void setAutoCheckEnabled (bool enabled);

    // Callbacks for UI integration
    std::function<void (State)> onStateChanged;

    // For non-Standalone targets: register a callback so plugins can request
    // an update check without linking against Sparkle/WinSparkle
    static std::function<void()>& getCheckCallback();

private:
    AutoUpdater();
    ~AutoUpdater();

    struct Impl;
    std::unique_ptr<Impl> impl;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AutoUpdater)
};

// ── Platform stub when auto-update is disabled ──────────────────────────────
// When ENABLE_AUTO_UPDATE is not defined, all methods are no-ops.
// The actual implementations live in AutoUpdater_Mac.mm and AutoUpdater_Win.cpp,
// which are only compiled when the respective platform and framework are available.

#if ! ENABLE_AUTO_UPDATE

inline AutoUpdater& AutoUpdater::getInstance()
{
    static AutoUpdater instance;
    return instance;
}

inline AutoUpdater::AutoUpdater() = default;
inline AutoUpdater::~AutoUpdater() = default;

inline void AutoUpdater::initialize() {}
inline void AutoUpdater::shutdown() {}
inline void AutoUpdater::checkForUpdates() {}
inline void AutoUpdater::checkInBackground() {}

inline AutoUpdater::State AutoUpdater::getState() const { return State::Idle; }
inline bool AutoUpdater::isUpdateAvailable() const { return false; }
inline juce::String AutoUpdater::getAvailableVersion() const { return {}; }
inline juce::String AutoUpdater::getLastError() const { return {}; }
inline juce::Time AutoUpdater::getLastCheckTime() const { return {}; }

inline bool AutoUpdater::isAutoCheckEnabled() const { return false; }
inline void AutoUpdater::setAutoCheckEnabled (bool) {}

inline std::function<void()>& AutoUpdater::getCheckCallback()
{
    static std::function<void()> cb;
    return cb;
}

#endif
