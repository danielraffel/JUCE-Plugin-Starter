#pragma once
#include <juce_core/juce_core.h>
#include "AppConfig.h"
#include "DiagnosticCollector.h"

class GitHubUploader
{
public:
    GitHubUploader (const AppConfig& config) : config_ (config) {}

    /** Submit diagnostic data as a GitHub issue with file uploads. Returns the issue URL on success, empty on failure. */
    juce::String submit (const DiagnosticData& data, juce::String& errorOut);

private:
    /** Upload a text file to the diagnostics repo. Returns the raw URL on success, empty on failure. */
    juce::String uploadFile (const juce::String& path, const juce::String& content, juce::String& errorOut);

    /** Upload a binary file to the diagnostics repo. Returns the raw URL on success, empty on failure. */
    juce::String uploadBinaryFile (const juce::String& path, const juce::File& file, juce::String& errorOut);

    /** Upload using curl.exe (Windows 10+ built-in). Returns "OK" on success. */
    juce::String uploadViaCurl (const juce::String& urlStr, const juce::File& payloadFile, juce::String& errorOut);

    /** Build the full diagnostic report text (for file upload). */
    juce::String buildFullReport (const DiagnosticData& data);

    /** Build the issue body with links to uploaded files. */
    juce::String formatIssueBody (const DiagnosticData& data,
                                  const juce::String& reportUrl,
                                  const juce::StringPairArray& crashLogUrls,
                                  const juce::StringPairArray& sessionLogUrls,
                                  const juce::StringPairArray& dawLogUrls);

    /** Build a fallback inline issue body (when uploads fail). */
    juce::String formatInlineIssueBody (const DiagnosticData& data);

    /** Create a GitHub issue. Returns the issue HTML URL on success, empty on failure. */
    juce::String createIssue (const juce::String& title, const juce::String& body, juce::String& errorOut);

    const AppConfig& config_;
};
