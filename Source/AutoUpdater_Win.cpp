#include "AutoUpdater.h"

#if defined(_WIN32) && ENABLE_AUTO_UPDATE && ENABLE_WINSPARKLE

#include <winsparkle.h>
#include <atomic>
#include <mutex>
#include <string>

// ── Thread-safe state for WinSparkle callbacks ─────────────────────────────
// WinSparkle callbacks are invoked from background threads.

static std::atomic<AutoUpdater::State> s_state{AutoUpdater::State::Idle};
static std::mutex s_versionMutex;
static std::string s_availableVersion;
static std::string s_lastError;

// ── WinSparkle C callbacks ─────────────────────────────────────────────────

static void __cdecl onUpdateFound()
{
    s_state = AutoUpdater::State::UpdateAvailable;
    DBG("[AutoUpdater] Update found");
}

static void __cdecl onNoUpdateFound()
{
    s_state = AutoUpdater::State::NoUpdateAvailable;
    DBG("[AutoUpdater] No update available");
}

static void __cdecl onUpdateCancelled()
{
    s_state = AutoUpdater::State::Idle;
    DBG("[AutoUpdater] Update cancelled by user");
}

static void __cdecl onError()
{
    s_state = AutoUpdater::State::Error;
    {
        std::lock_guard<std::mutex> lock(s_versionMutex);
        s_lastError = "Update check failed";
    }
    DBG("[AutoUpdater] Error during update check");
}

static int __cdecl onCanShutdown()
{
    // Allow WinSparkle to shut down the app for update installation
    return 1;
}

static void __cdecl onShutdownRequest()
{
    DBG("[AutoUpdater] Shutdown requested for update installation");
    s_state = AutoUpdater::State::ReadyToInstall;
    // Ask JUCE to quit gracefully — normal shutdown path handles audio cleanup
    if (auto* app = juce::JUCEApplicationBase::getInstance())
        app->systemRequestedQuit();
}

// ── AutoUpdater::Impl (Windows / WinSparkle) ──────────────────────────────

struct AutoUpdater::Impl
{
    Impl() = default;

    ~Impl()
    {
        shutdown();
    }

    void initialize()
    {
        if (initialized)
            return;

        // Set app metadata (must be called before win_sparkle_init)
        juce::String appName(JucePlugin_Name);
        juce::String version(JucePlugin_VersionString);
        juce::String company(JucePlugin_Manufacturer);

        win_sparkle_set_app_details(
            company.toWideCharPointer(),
            appName.toWideCharPointer(),
            version.toWideCharPointer()
        );

        // Set build number for version comparison
        juce::String buildVersion = juce::String(JucePlugin_VersionCode);
        win_sparkle_set_app_build_version(buildVersion.toWideCharPointer());

        // Set appcast URL (compiled in from AUTO_UPDATE_FEED_URL_WINDOWS via CMake)
#ifdef AUTO_UPDATE_FEED_URL
        win_sparkle_set_appcast_url(AUTO_UPDATE_FEED_URL);
        DBG("[AutoUpdater] Appcast URL: " << AUTO_UPDATE_FEED_URL);
#else
        DBG("[AutoUpdater] Warning: No appcast URL configured (AUTO_UPDATE_FEED_URL_WINDOWS not set in .env)");
#endif

        // Set EdDSA public key for signature verification (compiled in via CMake)
#ifdef AUTO_UPDATE_EDDSA_KEY
        win_sparkle_set_eddsa_public_key(AUTO_UPDATE_EDDSA_KEY);
        DBG("[AutoUpdater] EdDSA public key configured");
#else
        DBG("[AutoUpdater] Warning: No EdDSA public key configured");
#endif

        // Configure auto-check behavior
        win_sparkle_set_automatic_check_for_updates(1);
        win_sparkle_set_update_check_interval(86400); // 24 hours

        // Register callbacks (all called from background threads)
        win_sparkle_set_did_find_update_callback(onUpdateFound);
        win_sparkle_set_did_not_find_update_callback(onNoUpdateFound);
        win_sparkle_set_update_cancelled_callback(onUpdateCancelled);
        win_sparkle_set_error_callback(onError);
        win_sparkle_set_can_shutdown_callback(onCanShutdown);
        win_sparkle_set_shutdown_request_callback(onShutdownRequest);

        // Initialize WinSparkle (starts background update thread)
        win_sparkle_init();

        initialized = true;
        DBG("[AutoUpdater] WinSparkle initialized successfully");
    }

    void shutdown()
    {
        if (initialized)
        {
            win_sparkle_cleanup();
            initialized = false;
            DBG("[AutoUpdater] WinSparkle cleaned up");
        }
    }

    void checkForUpdates()
    {
        if (!initialized)
            return;

        s_state = AutoUpdater::State::Checking;
        win_sparkle_check_update_with_ui();
    }

    void checkInBackground()
    {
        if (!initialized)
            return;

        win_sparkle_check_update_without_ui();
    }

    AutoUpdater::State getState() const
    {
        return s_state.load();
    }

    bool isUpdateAvailable() const
    {
        return s_state.load() == AutoUpdater::State::UpdateAvailable;
    }

    juce::String getAvailableVersion() const
    {
        std::lock_guard<std::mutex> lock(s_versionMutex);
        return juce::String(s_availableVersion);
    }

    juce::String getLastError() const
    {
        std::lock_guard<std::mutex> lock(s_versionMutex);
        return juce::String(s_lastError);
    }

    juce::Time getLastCheckTime() const
    {
        // WinSparkle doesn't expose last check time directly
        return {};
    }

    bool isAutoCheckEnabled() const
    {
        // WinSparkle doesn't have a simple getter; default is enabled
        return initialized;
    }

    void setAutoCheckEnabled(bool enabled)
    {
        if (initialized)
            win_sparkle_set_automatic_check_for_updates(enabled ? 1 : 0);
    }

    bool initialized = false;
};

// ── AutoUpdater public API (Windows) ───────────────────────────────────────

AutoUpdater::AutoUpdater()  = default;
AutoUpdater::~AutoUpdater() = default;

AutoUpdater& AutoUpdater::getInstance()
{
    static AutoUpdater instance;
    return instance;
}

void AutoUpdater::initialize()
{
    if (!impl)
        impl = std::make_unique<Impl>();
    impl->initialize();
}

void AutoUpdater::shutdown()
{
    if (impl)
        impl->shutdown();
}

void AutoUpdater::checkForUpdates()
{
    if (impl)
    {
        impl->checkForUpdates();
        if (onStateChanged)
            onStateChanged(getState());
    }
}

void AutoUpdater::checkInBackground()
{
    if (impl)
        impl->checkInBackground();
}

AutoUpdater::State AutoUpdater::getState() const
{
    return impl ? impl->getState() : State::Idle;
}

bool AutoUpdater::isUpdateAvailable() const
{
    return impl ? impl->isUpdateAvailable() : false;
}

juce::String AutoUpdater::getAvailableVersion() const
{
    return impl ? impl->getAvailableVersion() : juce::String();
}

juce::String AutoUpdater::getLastError() const
{
    return impl ? impl->getLastError() : juce::String();
}

juce::Time AutoUpdater::getLastCheckTime() const
{
    return impl ? impl->getLastCheckTime() : juce::Time();
}

bool AutoUpdater::isAutoCheckEnabled() const
{
    return impl ? impl->isAutoCheckEnabled() : false;
}

void AutoUpdater::setAutoCheckEnabled(bool enabled)
{
    if (impl)
        impl->setAutoCheckEnabled(enabled);
}

std::function<void()>& AutoUpdater::getCheckCallback()
{
    static std::function<void()> cb = []()
    {
        AutoUpdater::getInstance().checkForUpdates();
    };
    return cb;
}

#endif // defined(_WIN32) && ENABLE_AUTO_UPDATE && ENABLE_WINSPARKLE
