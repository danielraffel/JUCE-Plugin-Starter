#pragma once
#include <juce_core/juce_core.h>
#include "AppConfig.h"

/**
    Platform-specific diagnostic collection.
    Each platform implements these functions in its own .cpp/.mm file.
*/
namespace PlatformDiagnostics
{
    /** Collect OS version, hardware model, CPU, RAM. */
    juce::String collectSystemInfo();

    /** List audio devices (input/output). */
    juce::String collectAudioDevices();

    /** Check if a plugin is installed at the platform's standard path. */
    struct PluginInstallInfo
    {
        bool installed = false;
        juce::String path;
        juce::int64 sizeBytes = 0;
        juce::Time modifiedTime;
    };

    PluginInstallInfo checkPluginInstalled (const juce::String& pluginName, const juce::String& format);

    /** Collect recent crash logs for the plugin (last 7 days). */
    juce::String collectCrashLogs (const juce::String& pluginName);

    /** Run plugin validation (auval on macOS, pluginval on others). Returns output or empty. */
    juce::String runPluginValidation (const AppConfig& config);

    /** Collect DAW-specific diagnostic info (scan caches, blacklists, logs). */
    juce::String collectDAWDiagnostics (const juce::String& pluginName);

    /** Get standard plugin install paths for the current platform. */
    juce::StringArray getPluginPaths (const juce::String& format);
}
