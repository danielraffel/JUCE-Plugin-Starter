#pragma once
#include <juce_core/juce_core.h>
#include "AppConfig.h"
#include "DiagnosticCollector.h"

class GitHubUploader
{
public:
    GitHubUploader (const AppConfig& config) : config_ (config) {}

    /** Submit diagnostic data as a GitHub issue. Returns the issue URL on success, empty on failure. */
    juce::String submit (const DiagnosticData& data, juce::String& errorOut);

private:
    juce::String formatIssueBody (const DiagnosticData& data);
    const AppConfig& config_;
};
