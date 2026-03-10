#pragma once
#include <juce_core/juce_core.h>

struct AppConfig
{
    // App Info
    juce::String appName = "Diagnostics";
    juce::String appIdentifier = "com.unknown.diagnostics";
    juce::String appVersion = "1.0.0";

    // GitHub
    juce::String githubRepo;
    juce::String githubPAT;

    // Support
    juce::String supportEmail;
    juce::String productName = "Plugin";

    // Plugin Info
    juce::String pluginName;
    juce::String pluginBundleId;
    juce::String pluginManufacturer;

    // Plugin Formats
    bool checkAU = true;
    bool checkVST3 = true;
    bool checkCLAP = false;
    bool checkStandalone = true;

    // Audio Unit specifics (macOS only)
    juce::String auType = "aufx";
    juce::String auSubtype;
    juce::String auManufacturer;

    // UI Configuration
    int windowWidth = 420;
    int windowHeight = 420;
    bool allowUserFeedback = true;
    bool showPrivacyNotice = true;

    // Timeouts
    int diagnosticTimeout = 30;
    int githubAPITimeout = 10;
    int githubAPIRetries = 3;

    bool debugMode = false;

    /** Load config from .env file. Returns nullopt if file not found. */
    static std::optional<AppConfig> load();

    /** Find the .env file path (bundled or adjacent to executable). */
    static juce::File findEnvFile();

private:
    static juce::StringPairArray parseEnv (const juce::String& content);
};
