#pragma once
#include <juce_core/juce_core.h>
#include "AppConfig.h"

struct DiagnosticData
{
    juce::String systemInfo;
    juce::String pluginStatus;
    juce::String crashLogs;
    juce::String pluginValidation;
    juce::String dawDiagnostics;
    juce::String pythonEnvironment;
    juce::String sessionLogs;
    juce::String installerInfo;
    juce::String dependencies;
    juce::String pipelineHealth;
    juce::String securityInfo;
    juce::String userFeedback;

    /** Paths to crash dump files for upload. */
    juce::StringArray crashFilePaths;
};

class DiagnosticCollector
{
public:
    DiagnosticCollector (const AppConfig& config) : config_ (config) {}

    DiagnosticData collectAll (const juce::String& userFeedback = {});

private:
    juce::String collectPluginStatus();
    const AppConfig& config_;
};
