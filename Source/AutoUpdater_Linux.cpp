#include "AutoUpdater.h"

#if defined(__linux__) && ENABLE_AUTO_UPDATE

#include <atomic>
#include <mutex>

// ── Thread-safe state ─────────────────────────────────────────────────────
static std::atomic<AutoUpdater::State> s_state { AutoUpdater::State::Idle };
static std::mutex s_mutex;
static juce::String s_availableVersion;
static juce::String s_lastError;
static juce::String s_downloadURL;
static juce::Time s_lastCheckTime;

// ── AutoUpdater::Impl (Linux — custom appcast polling) ────────────────────
// No external library needed. Uses JUCE HTTP + XML to check for updates.
// Shows a JUCE AlertWindow when an update is found.
// "Download" button opens the release URL in the default browser.

struct AutoUpdater::Impl : private juce::Timer
{
    Impl() = default;

    ~Impl() override
    {
        stopTimer();
    }

    void initialize()
    {
        if (initialized)
            return;

        initialized = true;
        DBG ("[AutoUpdater] Linux appcast updater initialized");

        // Check once on startup (delayed), then every 24 hours
        startTimer (86400 * 1000); // 24 hours
        juce::Timer::callAfterDelay (3000, [this]() { checkInBackground(); });
    }

    void shutdown()
    {
        stopTimer();
        initialized = false;
    }

    void checkForUpdates()
    {
        performCheck (true);
    }

    void checkInBackground()
    {
        performCheck (false);
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
        std::lock_guard<std::mutex> lock (s_mutex);
        return s_availableVersion;
    }

    juce::String getLastError() const
    {
        std::lock_guard<std::mutex> lock (s_mutex);
        return s_lastError;
    }

    juce::Time getLastCheckTime() const
    {
        std::lock_guard<std::mutex> lock (s_mutex);
        return s_lastCheckTime;
    }

    bool isAutoCheckEnabled() const { return autoCheckEnabled; }
    void setAutoCheckEnabled (bool enabled) { autoCheckEnabled = enabled; }

    bool initialized = false;
    bool autoCheckEnabled = true;

private:
    void timerCallback() override
    {
        if (autoCheckEnabled)
            checkInBackground();
    }

    void performCheck (bool showUI)
    {
        if (! initialized)
            return;

#ifndef AUTO_UPDATE_FEED_URL
        DBG ("[AutoUpdater] No appcast URL configured (AUTO_UPDATE_FEED_URL not set)");
        if (showUI)
        {
            juce::AlertWindow::showMessageBoxAsync (
                juce::MessageBoxIconType::InfoIcon,
                "Check for Updates",
                "Auto-update is not configured for this build.",
                "OK");
        }
        return;
#else
        s_state = AutoUpdater::State::Checking;

        // Run HTTP fetch on a background thread
        auto* checker = new AppcastChecker (showUI);
        checker->startThread();
#endif
    }

#ifdef AUTO_UPDATE_FEED_URL
    // Background thread that fetches and parses the appcast
    class AppcastChecker : public juce::Thread
    {
    public:
        AppcastChecker (bool showUI_) : juce::Thread ("UpdateChecker"), showUI (showUI_) {}

        ~AppcastChecker() override
        {
            stopThread (5000);
        }

        void run() override
        {
            juce::String feedURL (AUTO_UPDATE_FEED_URL);
            DBG ("[AutoUpdater] Checking appcast: " << feedURL);

            auto xml = juce::URL (feedURL).readEntireTextStream (false);
            if (xml.isEmpty())
            {
                handleError ("Could not reach update server.");
                return;
            }

            auto doc = juce::parseXML (xml);
            if (doc == nullptr)
            {
                handleError ("Invalid update feed.");
                return;
            }

            // Parse Sparkle-style appcast: <rss> → <channel> → <item> → <enclosure>
            juce::String latestVersion;
            juce::String downloadLink;

            auto* channel = doc->getChildByName ("channel");
            if (channel == nullptr)
                channel = doc.get(); // fallback: items directly under root

            for (auto* item : channel->getChildWithTagNameIterator ("item"))
            {
                auto* enclosure = item->getChildByName ("enclosure");
                if (enclosure != nullptr)
                {
                    auto ver = enclosure->getStringAttribute ("sparkle:version");
                    if (ver.isEmpty())
                        ver = enclosure->getStringAttribute ("sparkle:shortVersionString");
                    auto url = enclosure->getStringAttribute ("url");

                    // Also check for linux-specific enclosure
                    auto os = enclosure->getStringAttribute ("sparkle:os");
                    if (os.isNotEmpty() && os != "linux")
                        continue;

                    if (ver.isNotEmpty() && url.isNotEmpty())
                    {
                        latestVersion = ver;
                        downloadLink = url;
                        break; // first matching item is latest
                    }
                }

                // Fallback: check <sparkle:version> directly on <item>
                if (latestVersion.isEmpty())
                {
                    auto ver = item->getStringAttribute ("sparkle:version");
                    auto link = item->getChildElementAllSubText ("link", "");
                    if (ver.isNotEmpty() && link.isNotEmpty())
                    {
                        latestVersion = ver;
                        downloadLink = link;
                    }
                }
            }

            {
                std::lock_guard<std::mutex> lock (s_mutex);
                s_lastCheckTime = juce::Time::getCurrentTime();
            }

            if (latestVersion.isEmpty())
            {
                handleError ("No version information found in update feed.");
                return;
            }

            juce::String currentVersion (JucePlugin_VersionString);
            DBG ("[AutoUpdater] Current: " << currentVersion << "  Latest: " << latestVersion);

            if (isNewerVersion (currentVersion, latestVersion))
            {
                {
                    std::lock_guard<std::mutex> lock (s_mutex);
                    s_availableVersion = latestVersion;
                    s_downloadURL = downloadLink;
                }
                s_state = AutoUpdater::State::UpdateAvailable;
                showUpdateDialog (latestVersion, downloadLink);
            }
            else
            {
                s_state = AutoUpdater::State::NoUpdateAvailable;
                if (showUI)
                {
                    juce::MessageManager::callAsync ([]()
                    {
                        juce::AlertWindow::showMessageBoxAsync (
                            juce::MessageBoxIconType::InfoIcon,
                            "Check for Updates",
                            "You're running the latest version.",
                            "OK");
                    });
                }
            }

            // Self-destruct (prevent leak)
            juce::MessageManager::callAsync ([this]() { delete this; });
        }

    private:
        bool showUI;

        void handleError (const juce::String& msg)
        {
            {
                std::lock_guard<std::mutex> lock (s_mutex);
                s_lastError = msg;
            }
            s_state = AutoUpdater::State::Error;
            DBG ("[AutoUpdater] Error: " << msg);

            if (showUI)
            {
                juce::MessageManager::callAsync ([msg]()
                {
                    juce::AlertWindow::showMessageBoxAsync (
                        juce::MessageBoxIconType::WarningIcon,
                        "Update Check Failed",
                        msg,
                        "OK");
                });
            }

            juce::MessageManager::callAsync ([this]() { delete this; });
        }

        void showUpdateDialog (const juce::String& version, const juce::String& url)
        {
            juce::MessageManager::callAsync ([version, url]()
            {
                auto options = juce::MessageBoxOptions()
                    .withIconType (juce::MessageBoxIconType::InfoIcon)
                    .withTitle ("Update Available")
                    .withMessage (juce::String (JucePlugin_Name) + " version " + version
                        + " is available.\n\nWould you like to download it?")
                    .withButton ("Download")
                    .withButton ("Later");

                juce::AlertWindow::showAsync (options, [url] (int result)
                {
                    if (result == 1) // "Download" button
                        juce::URL (url).launchInDefaultBrowser();
                });
            });
        }

        // Compare semantic versions: returns true if latest > current
        static bool isNewerVersion (const juce::String& current, const juce::String& latest)
        {
            auto currentParts = juce::StringArray::fromTokens (current, ".", "");
            auto latestParts = juce::StringArray::fromTokens (latest, ".", "");

            int maxParts = juce::jmax (currentParts.size(), latestParts.size());
            for (int i = 0; i < maxParts; ++i)
            {
                int c = (i < currentParts.size()) ? currentParts[i].getIntValue() : 0;
                int l = (i < latestParts.size()) ? latestParts[i].getIntValue() : 0;
                if (l > c) return true;
                if (l < c) return false;
            }
            return false;
        }
    };
#endif // AUTO_UPDATE_FEED_URL
};

// ── AutoUpdater public API (Linux) ────────────────────────────────────────

AutoUpdater::AutoUpdater() = default;
AutoUpdater::~AutoUpdater() = default;

AutoUpdater& AutoUpdater::getInstance()
{
    static AutoUpdater instance;
    return instance;
}

void AutoUpdater::initialize()
{
    if (! impl)
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
            onStateChanged (getState());
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

void AutoUpdater::setAutoCheckEnabled (bool enabled)
{
    if (impl)
        impl->setAutoCheckEnabled (enabled);
}

std::function<void()>& AutoUpdater::getCheckCallback()
{
    static std::function<void()> cb = []()
    {
        AutoUpdater::getInstance().checkForUpdates();
    };
    return cb;
}

#endif // defined(__linux__) && ENABLE_AUTO_UPDATE
