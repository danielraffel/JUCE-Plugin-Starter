#pragma once
#include <juce_core/juce_core.h>
#include <juce_audio_devices/juce_audio_devices.h>
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

    /** Collect recent crash logs for the plugin (last 7 days). Returns crash info text and populates crashFilePaths. */
    juce::String collectCrashLogs (const juce::String& pluginName, juce::StringArray* crashFilePaths = nullptr);

    /** Run plugin validation (auval on macOS, pluginval on others). Returns output or empty. */
    juce::String runPluginValidation (const AppConfig& config);

    /** Collect DAW-specific diagnostic info (scan caches, blacklists, logs). */
    juce::String collectDAWDiagnostics (const juce::String& pluginName);

    /** Get standard plugin install paths for the current platform. */
    juce::StringArray getPluginPaths (const juce::String& format);

    /** Collect Python/venv environment info (packages, scripts, binaries). */
    juce::String collectPythonEnvironment (const AppConfig& config);

    /** Collect recent session logs from the plugin's working directory. */
    juce::String collectSessionLogs (const juce::String& pluginName);

    /** Collect installer/registry info. */
    juce::String collectInstallerInfo (const AppConfig& config);

    /** Collect dependency info (DLLs, linked libraries). */
    juce::String collectDependencies (const AppConfig& config);

    /** Run a pipeline health check (test yt-dlp, ffmpeg, deno). */
    juce::String collectPipelineHealthCheck (const AppConfig& config);

    /** Collect Windows security info (SmartScreen, Defender, UAC). */
    juce::String collectSecurityInfo (const AppConfig& config);
}
