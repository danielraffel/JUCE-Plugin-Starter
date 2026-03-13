#include "AutoUpdater.h"

#if JUCE_MAC && ENABLE_AUTO_UPDATE && ENABLE_SPARKLE

// Avoid conflicts between JUCE and macOS types
#define Component AppleComponent
#define Point ApplePoint

#import <Sparkle/Sparkle.h>

#undef Component
#undef Point

// ── Sparkle Delegate ────────────────────────────────────────────────────────

@interface AutoUpdaterDelegate : NSObject <SPUUpdaterDelegate>
@property (nonatomic, assign) AutoUpdater::State currentState;
@property (nonatomic, strong) NSString* availableVersion;
@property (nonatomic, strong) NSString* lastError;
@property (nonatomic, assign) NSTimeInterval lastCheckTime;
@end

@implementation AutoUpdaterDelegate

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _currentState = AutoUpdater::State::Idle;
        _availableVersion = @"";
        _lastError = @"";
        _lastCheckTime = 0;
    }
    return self;
}

// Feed URL from Info.plist (set by post_build.sh from AUTO_UPDATE_FEED_URL_MACOS)
// No delegate override needed — Sparkle reads SUFeedURL from Info.plist by default.
// If SUFeedURL is empty/missing, Sparkle will report an error gracefully.

// Track when updates are found
- (void)updater:(SPUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)item
{
    self.currentState = AutoUpdater::State::UpdateAvailable;
    self.availableVersion = item.displayVersionString ?: item.versionString;
    self.lastCheckTime = [[NSDate date] timeIntervalSince1970];
    NSLog(@"AutoUpdater: Update available: %@", self.availableVersion);
}

// No update available
- (void)updaterDidNotFindUpdate:(SPUUpdater *)updater
{
    self.currentState = AutoUpdater::State::NoUpdateAvailable;
    self.availableVersion = @"";
    self.lastCheckTime = [[NSDate date] timeIntervalSince1970];
}

// Error handling
- (void)updater:(SPUUpdater *)updater didAbortWithError:(NSError *)error
{
    self.currentState = AutoUpdater::State::Error;
    self.lastError = error.localizedDescription ?: @"Unknown error";
    NSLog(@"AutoUpdater: Error: %@ (domain: %@, code: %ld)",
          error.localizedDescription, error.domain, (long)error.code);
}

// Update cycle complete
- (void)updater:(SPUUpdater *)updater
    didFinishUpdateCycleForUpdateCheck:(SPUUpdateCheck)updateCheck
                                error:(NSError *)error
{
    if (error)
    {
        self.currentState = AutoUpdater::State::Error;
        self.lastError = error.localizedDescription ?: @"Unknown error";
    }
    else if (self.currentState == AutoUpdater::State::Checking)
    {
        self.currentState = AutoUpdater::State::Idle;
    }
}

@end

// ── AutoUpdater::Impl (macOS / Sparkle) ─────────────────────────────────────

struct AutoUpdater::Impl
{
    Impl()
    {
        @autoreleasepool
        {
            delegate = [[AutoUpdaterDelegate alloc] init];
        }
    }

    ~Impl()
    {
        shutdown();
    }

    void initialize()
    {
        if (initialized)
            return;

        @autoreleasepool
        {
            // Create SPUStandardUpdaterController with startingUpdater:NO
            // We call startUpdater explicitly after the main window is shown
            updaterController = [[SPUStandardUpdaterController alloc]
                initWithStartingUpdater:NO
                        updaterDelegate:delegate
                      userDriverDelegate:nil];

            if (updaterController)
            {
                NSError* error = nil;
                [updaterController.updater startUpdater:&error];

                if (error)
                {
                    NSLog(@"AutoUpdater: Failed to start updater: %@", error.localizedDescription);
                    delegate.currentState = AutoUpdater::State::Error;
                    delegate.lastError = error.localizedDescription;
                }
                else
                {
                    NSLog(@"AutoUpdater: Sparkle updater started successfully");
                    initialized = true;
                }
            }
        }
    }

    void shutdown()
    {
        @autoreleasepool
        {
            updaterController = nil;
            initialized = false;
        }
    }

    void checkForUpdates()
    {
        if (!initialized || !updaterController)
            return;

        @autoreleasepool
        {
            delegate.currentState = AutoUpdater::State::Checking;
            [updaterController checkForUpdates:nil];
        }
    }

    void checkInBackground()
    {
        if (!initialized || !updaterController)
            return;

        @autoreleasepool
        {
            [updaterController.updater checkForUpdatesInBackground];
        }
    }

    AutoUpdater::State getState() const
    {
        return delegate.currentState;
    }

    bool isUpdateAvailable() const
    {
        return delegate.currentState == AutoUpdater::State::UpdateAvailable;
    }

    juce::String getAvailableVersion() const
    {
        @autoreleasepool
        {
            return juce::String::fromUTF8([delegate.availableVersion UTF8String]);
        }
    }

    juce::String getLastError() const
    {
        @autoreleasepool
        {
            return juce::String::fromUTF8([delegate.lastError UTF8String]);
        }
    }

    juce::Time getLastCheckTime() const
    {
        if (delegate.lastCheckTime > 0)
            return juce::Time(static_cast<juce::int64>(delegate.lastCheckTime * 1000.0));
        return {};
    }

    bool isAutoCheckEnabled() const
    {
        if (!updaterController)
            return false;

        @autoreleasepool
        {
            return updaterController.updater.automaticallyChecksForUpdates;
        }
    }

    void setAutoCheckEnabled(bool enabled)
    {
        if (!updaterController)
            return;

        @autoreleasepool
        {
            updaterController.updater.automaticallyChecksForUpdates = enabled;
        }
    }

    AutoUpdaterDelegate* delegate = nil;
    SPUStandardUpdaterController* updaterController = nil;
    bool initialized = false;
};

// ── AutoUpdater public API (macOS) ──────────────────────────────────────────

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

#endif // JUCE_MAC && ENABLE_AUTO_UPDATE && ENABLE_SPARKLE
