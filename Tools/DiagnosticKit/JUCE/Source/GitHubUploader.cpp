#include "GitHubUploader.h"

// Anonymize text content before uploading (same logic as MainComponent::anonymize)
static juce::String anonymizeContent (const juce::String& text)
{
    auto result = text;
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto homePath = home.getFullPathName();
    auto username = home.getFileName();

   #if JUCE_WINDOWS
    result = result.replace (homePath, "C:\\Users\\<user>", true);
    result = result.replace (homePath.replace ("\\", "/"), "C:/Users/<user>", true);
    result = result.replace (username, "<user>", true);
   #else
    result = result.replace (homePath, "/home/<user>", true);
    result = result.replace ("/Users/" + username, "/Users/<user>", true);
    result = result.replace ("/" + username + "/", "/<user>/", true);
   #endif

    auto hostname = juce::SystemStats::getComputerName();
    if (hostname.isNotEmpty())
        result = result.replace (hostname, "<hostname>", true);

    return result;
}

juce::String GitHubUploader::submit (const DiagnosticData& data, juce::String& errorOut)
{
    if (config_.githubRepo.isEmpty() || config_.githubPAT.isEmpty())
    {
        errorOut = "GitHub configuration is invalid. Please check your .env file.";
        return {};
    }

    // Generate timestamp folder for this submission
    auto now = juce::Time::getCurrentTime();
    auto dateString = now.formatted ("%Y%m%d_%H%M%S");
    auto folderPath = "diagnostics/" + dateString;

    // Build the full report
    auto fullReport = buildFullReport (data);

    // Try to upload the report file
    juce::String reportUrl;
    juce::String uploadError;
    reportUrl = uploadFile (folderPath + "/diagnostic_report.txt", fullReport, uploadError);

    bool uploadSucceeded = reportUrl.isNotEmpty();

    // Upload crash log files
    juce::StringPairArray crashLogUrls;
    if (uploadSucceeded && data.crashFilePaths.size() > 0)
    {
        for (int i = 0; i < juce::jmin (5, data.crashFilePaths.size()); ++i)
        {
            juce::File crashFile (data.crashFilePaths[i]);
            if (crashFile.existsAsFile())
            {
                auto fileName = crashFile.getFileName().replace (" ", "_");
                auto crashUrl = uploadBinaryFile (folderPath + "/crash_" + juce::String (i) + "_" + fileName,
                                                  crashFile, uploadError);
                if (crashUrl.isNotEmpty())
                    crashLogUrls.set (crashFile.getFileName(), crashUrl);
            }
        }
    }

    // Upload session log files
    juce::StringPairArray sessionLogUrls;
    if (uploadSucceeded && data.sessionLogFilePaths.size() > 0)
    {
        for (int i = 0; i < juce::jmin (3, data.sessionLogFilePaths.size()); ++i)
        {
            juce::File logFile (data.sessionLogFilePaths[i]);
            if (logFile.existsAsFile())
            {
                // Name from parent dir (e.g. Session-1234/session.log → session_Session-1234.log)
                auto sessionName = logFile.getParentDirectory().getFileName().replace (" ", "_");
                auto logUrl = uploadFile (folderPath + "/session_" + sessionName + ".log",
                                          anonymizeContent (logFile.loadFileAsString()), uploadError);
                if (logUrl.isNotEmpty())
                    sessionLogUrls.set (sessionName, logUrl);
            }
        }
    }

    // Upload DAW log files (e.g., Ableton Log.txt, Reaper log, Bitwig log)
    juce::StringPairArray dawLogUrls;
    if (uploadSucceeded && data.dawLogFilePaths.size() > 0)
    {
        for (int i = 0; i < juce::jmin (3, data.dawLogFilePaths.size()); ++i)
        {
            juce::File logFile (data.dawLogFilePaths[i]);
            if (logFile.existsAsFile())
            {
                // Name from DAW (e.g., "Log.txt" → "daw_Ableton_Log.txt")
                auto dawName = logFile.getParentDirectory().getParentDirectory().getFileName().replace (" ", "_");
                auto logUrl = uploadFile (folderPath + "/daw_" + dawName + "_" + logFile.getFileName().replace (" ", "_"),
                                          anonymizeContent (logFile.loadFileAsString()), uploadError);
                if (logUrl.isNotEmpty())
                    dawLogUrls.set (dawName, logUrl);
            }
        }
    }

    // Create the issue with platform tag
   #if JUCE_WINDOWS
    auto platformTag = "[Win] ";
   #elif JUCE_MAC
    auto platformTag = "[Mac] ";
   #elif JUCE_LINUX
    auto platformTag = "[Linux] ";
   #else
    auto platformTag = "";
   #endif
    auto title = platformTag + juce::String ("Diagnostic Report - ") + now.toString (true, true, false);
    juce::String body;

    if (uploadSucceeded)
        body = formatIssueBody (data, reportUrl, crashLogUrls, sessionLogUrls, dawLogUrls);
    else
        body = formatInlineIssueBody (data);

    return createIssue (title, body, errorOut);
}

juce::String GitHubUploader::uploadViaCurl (const juce::String& urlStr, const juce::File& payloadFile, juce::String& errorOut)
{
    auto statusFile = juce::File::getSpecialLocation (juce::File::tempDirectory)
                          .getChildFile ("diag_curl_status.txt");

    auto batchFile = juce::File::getSpecialLocation (juce::File::tempDirectory)
                         .getChildFile ("diag_curl_upload.bat");

    juce::String batch;
    batch << "@echo off\n";
    batch << "curl.exe -s -w \"%%{http_code}\" -o NUL -X PUT"
          << " -H \"Authorization: Bearer " << config_.githubPAT << "\""
          << " -H \"Accept: application/vnd.github+json\""
          << " -H \"X-GitHub-Api-Version: 2022-11-28\""
          << " -H \"Content-Type: application/json\""
          << " -d @\"" << payloadFile.getFullPathName() << "\""
          << " \"" << urlStr << "\""
          << " > \"" << statusFile.getFullPathName() << "\" 2>&1\n";

    batchFile.replaceWithText (batch);

    juce::ChildProcess proc;
    bool finished = false;
    if (proc.start ("cmd.exe /C \"" + batchFile.getFullPathName() + "\""))
        finished = proc.waitForProcessToFinish (60000);

    if (! finished)
        proc.kill();

    batchFile.deleteFile();

    auto result = statusFile.loadFileAsString().trim();
    statusFile.deleteFile();

    if (result.endsWith ("200") || result.endsWith ("201"))
        return "OK";

    errorOut = "curl: " + result.substring (0, 300);
    return {};
}

juce::String GitHubUploader::uploadFile (const juce::String& path, const juce::String& content, juce::String& errorOut)
{
    auto urlStr = "https://api.github.com/repos/" + config_.githubRepo + "/contents/" + path;

    // Base64 encode using juce::Base64 (standard RFC 4648 alphabet)
    // NOTE: Do NOT use MemoryBlock::toBase64Encoding() — it uses a non-standard JUCE alphabet
    juce::MemoryOutputStream base64Stream;
    juce::Base64::convertToBase64 (base64Stream, content.toRawUTF8(), (size_t) content.getNumBytesAsUTF8());
    auto base64 = base64Stream.toString();

    // Build JSON payload — use manual escaping since base64 is already clean alphanumeric+/+=
    juce::String payload = "{\"message\":\"Add diagnostic files\",\"content\":\"" + base64 + "\",\"branch\":\"main\"}";

    // Write payload using raw bytes to avoid JUCE line-ending conversion
    auto tempFile = juce::File::getSpecialLocation (juce::File::tempDirectory)
                        .getChildFile ("diag_upload.json");
    {
        auto utf8 = payload.toUTF8();
        tempFile.replaceWithData (utf8.getAddress(), utf8.sizeInBytes() - 1); // -1 to exclude null terminator
    }

    // Try curl.exe first (most reliable on Windows 10+)
    auto curlResult = uploadViaCurl (urlStr, tempFile, errorOut);
    if (curlResult == "OK")
    {
        tempFile.deleteFile();
        return "https://github.com/" + config_.githubRepo + "/raw/main/" + path;
    }

    // Try JUCE HTTP as fallback
    juce::URL url (urlStr);
    url = url.withPOSTData (payload);

    int statusCode = 0;
    auto options = juce::URL::InputStreamOptions (juce::URL::ParameterHandling::inPostData)
                       .withExtraHeaders ("Accept: application/vnd.github+json\r\n"
                                          "Authorization: Bearer " + config_.githubPAT + "\r\n"
                                          "X-GitHub-Api-Version: 2022-11-28\r\n"
                                          "Content-Type: application/json\r\n")
                       .withHttpRequestCmd ("PUT")
                       .withConnectionTimeoutMs (30000)
                       .withStatusCode (&statusCode);

    auto stream = url.createInputStream (options);

    tempFile.deleteFile();

    if (stream != nullptr && (statusCode == 200 || statusCode == 201))
        return "https://github.com/" + config_.githubRepo + "/raw/main/" + path;

    errorOut = "File upload failed (curl: " + errorOut + ", JUCE HTTP " + juce::String (statusCode) + ")";
    return {};
}

juce::String GitHubUploader::uploadBinaryFile (const juce::String& path, const juce::File& file, juce::String& errorOut)
{
    auto urlStr = "https://api.github.com/repos/" + config_.githubRepo + "/contents/" + path;

    juce::MemoryBlock mb;
    if (! file.loadFileAsData (mb))
    {
        errorOut = "Could not read file: " + file.getFileName();
        return {};
    }

    // Use juce::Base64 for standard RFC 4648 encoding (NOT MemoryBlock::toBase64Encoding)
    juce::MemoryOutputStream base64Stream;
    juce::Base64::convertToBase64 (base64Stream, mb.getData(), mb.getSize());
    auto base64 = base64Stream.toString();

    juce::String payload = "{\"message\":\"Add diagnostic files\",\"content\":\"" + base64 + "\",\"branch\":\"main\"}";

    // Write payload using raw bytes to avoid line-ending conversion
    auto tempFile = juce::File::getSpecialLocation (juce::File::tempDirectory)
                        .getChildFile ("diag_upload_bin.json");
    {
        auto utf8 = payload.toUTF8();
        tempFile.replaceWithData (utf8.getAddress(), utf8.sizeInBytes() - 1);
    }

    // Try curl.exe first
    auto curlResult = uploadViaCurl (urlStr, tempFile, errorOut);
    if (curlResult == "OK")
    {
        tempFile.deleteFile();
        return "https://github.com/" + config_.githubRepo + "/raw/main/" + path;
    }

    // Fallback to JUCE HTTP
    juce::URL url (urlStr);
    url = url.withPOSTData (payload);

    int statusCode = 0;
    auto options = juce::URL::InputStreamOptions (juce::URL::ParameterHandling::inPostData)
                       .withExtraHeaders ("Accept: application/vnd.github+json\r\n"
                                          "Authorization: Bearer " + config_.githubPAT + "\r\n"
                                          "X-GitHub-Api-Version: 2022-11-28\r\n"
                                          "Content-Type: application/json\r\n")
                       .withHttpRequestCmd ("PUT")
                       .withConnectionTimeoutMs (30000)
                       .withStatusCode (&statusCode);

    auto stream = url.createInputStream (options);

    tempFile.deleteFile();

    if (stream != nullptr && (statusCode == 200 || statusCode == 201))
        return "https://github.com/" + config_.githubRepo + "/raw/main/" + path;

    errorOut = "Binary upload failed (curl: " + errorOut + ", JUCE HTTP " + juce::String (statusCode) + ")";
    return {};
}

juce::String GitHubUploader::buildFullReport (const DiagnosticData& data)
{
    juce::String report;

    if (data.userFeedback.isNotEmpty())
        report << "USER FEEDBACK\n=============\n\n" << data.userFeedback << "\n\n";

    report << data.systemInfo << "\n\n";
    report << data.pluginStatus << "\n\n";
    report << data.dependencies << "\n\n";
    report << data.pythonEnvironment << "\n\n";
    report << data.pipelineHealth << "\n\n";
    report << data.sessionLogs << "\n\n";
    report << data.crashLogs << "\n\n";
    report << data.pluginValidation << "\n\n";
    report << data.dawDiagnostics << "\n\n";
    report << data.installerInfo << "\n\n";
    report << data.securityInfo << "\n\n";

    report << "---\nReport generated by " << config_.appName << " v" << config_.appVersion << "\n";

    return report;
}

juce::String GitHubUploader::formatIssueBody (const DiagnosticData& data,
                                               const juce::String& reportUrl,
                                               const juce::StringPairArray& crashLogUrls,
                                               const juce::StringPairArray& sessionLogUrls,
                                               const juce::StringPairArray& dawLogUrls)
{
    juce::String body;

    // User feedback section
    body << "## User Feedback\n\n";
    if (data.userFeedback.isNotEmpty())
        body << data.userFeedback << "\n\n";
    else
        body << "_No description provided_\n\n";

    if (data.userEmail.isNotEmpty())
        body << "**Contact email:** " << data.userEmail << "\n\n";

    // Links to uploaded files
    body << "## \xF0\x9F\x93\x81 Full Diagnostic Data\n\n";
    body << "### \xF0\x9F\x93\x8B [Full Diagnostic Report](" << reportUrl << ")\n\n";

    if (crashLogUrls.size() > 0)
    {
        body << "### \xF0\x9F\x92\xA5 Crash Logs\n\n";
        for (int i = 0; i < crashLogUrls.size(); ++i)
        {
            auto key = crashLogUrls.getAllKeys()[i];
            auto val = crashLogUrls.getAllValues()[i];
            body << "- [" << key << "](" << val << ")\n";
        }
        body << "\n";
    }

    if (sessionLogUrls.size() > 0)
    {
        body << "### \xF0\x9F\x93\x9D Session Logs\n\n";
        for (int i = 0; i < sessionLogUrls.size(); ++i)
        {
            auto key = sessionLogUrls.getAllKeys()[i];
            auto val = sessionLogUrls.getAllValues()[i];
            body << "- [" << key << "](" << val << ")\n";
        }
        body << "\n";
    }

    if (dawLogUrls.size() > 0)
    {
        body << "### \xF0\x9F\x8E\xB9 DAW Logs\n\n";
        for (int i = 0; i < dawLogUrls.size(); ++i)
        {
            auto key = dawLogUrls.getAllKeys()[i];
            auto val = dawLogUrls.getAllValues()[i];
            body << "- [" << key << "](" << val << ")\n";
        }
        body << "\n";
    }

    // Quick summary: extract key check results into a table
    // Each entry: pair of (status char, description)
    struct CheckItem { juce::String status; juce::String label; };
    juce::Array<CheckItem> checks;

    auto addCheck = [&checks](const juce::String& status, const juce::String& label)
    {
        checks.add ({ status, label });
    };

    // Plugin installation
    auto checkInstalled = [](const juce::String& section, const juce::String& format) -> bool
    {
        return section.contains ("**" + format + ":** Installed");
    };

    if (data.pluginStatus.contains ("**VST3:**"))
        addCheck (checkInstalled (data.pluginStatus, "VST3") ? "pass" : "fail", "VST3 plugin");
   #if JUCE_MAC
    if (data.pluginStatus.contains ("**Audio Unit:**"))
        addCheck (checkInstalled (data.pluginStatus, "Audio Unit") ? "pass" : "fail", "Audio Unit");
   #endif
    if (data.pluginStatus.contains ("**Standalone:**"))
        addCheck (checkInstalled (data.pluginStatus, "Standalone") ? "pass" : "fail", "Standalone app");

    // Key dependencies
    if (data.dependencies.contains ("WinSparkle") || data.dependencies.contains ("Sparkle"))
        addCheck (data.dependencies.contains ("\xe2\x9c\x93") ? "pass" : "fail", "Auto-updater");
    if (data.dependencies.contains ("C++ Runtime") || data.dependencies.contains ("library dependencies"))
        addCheck (data.dependencies.contains ("\xe2\x9c\x93") ? "pass" : "fail", "Runtime dependencies");

    // Python environment
    if (data.pythonEnvironment.contains ("Python venv"))
        addCheck (data.pythonEnvironment.contains ("\xe2\x9c\x93 Python venv") ? "pass" : "fail", "Python environment");
    if (data.pythonEnvironment.contains ("yt-dlp") || data.pythonEnvironment.contains ("yt_dlp"))
        addCheck (data.pythonEnvironment.contains ("\xe2\x9c\x93 yt-dlp") || data.pythonEnvironment.contains ("\xe2\x9c\x93 yt_dlp") ? "pass" : "fail", "yt-dlp (downloader)");
    if (data.pythonEnvironment.contains ("pydub"))
        addCheck (data.pythonEnvironment.contains ("\xe2\x9c\x93 pydub") ? "pass" : "fail", "pydub (audio processing)");
    if (data.pythonEnvironment.contains ("ffmpeg"))
        addCheck (data.pythonEnvironment.contains ("\xe2\x9c\x93 ffmpeg") ? "pass" : "fail", "ffmpeg");
    if (data.pythonEnvironment.contains ("Deno") || data.pythonEnvironment.contains ("deno"))
        addCheck (data.pythonEnvironment.contains ("\xe2\x9c\x93 Deno") ? "pass" : "fail", "Deno");
    if (data.pythonEnvironment.contains ("words.txt"))
        addCheck (data.pythonEnvironment.contains ("\xe2\x9c\x93 words.txt") ? "pass" : "fail", "Word list (AI search)");

    // Pipeline health
    if (data.pipelineHealth.contains ("End-to-end"))
    {
        bool dlOk = data.pipelineHealth.contains ("download: \xe2\x9c\x93");
        bool procOk = data.pipelineHealth.contains ("processing: \xe2\x9c\x93");
        if (dlOk && procOk)
            addCheck ("pass", "End-to-end download + processing");
        else if (dlOk)
            addCheck ("warn", "Download OK, processing failed");
        else
            addCheck ("fail", "End-to-end pipeline test");
    }

    // DAW crashes
    if (data.dawDiagnostics.contains ("crash recovery") || data.dawDiagnostics.contains ("crash report")
        || data.dawDiagnostics.contains ("crash dump") || data.dawDiagnostics.contains ("crash log"))
    {
        addCheck ("warn", "Recent DAW crash data detected (see DAW Diagnostics)");
    }

    // Security
    if (data.securityInfo.contains ("Code Signature"))
    {
        if (data.securityInfo.contains ("Valid"))
            addCheck ("pass", "Code signature");
        else if (data.securityInfo.contains ("Not signed"))
            addCheck ("warn", "Not code-signed (expected for dev builds)");
        else
            addCheck ("warn", "Code signature issue");
    }

    body << "## Quick Summary\n\n";
    body << "| Status | Check |\n";
    body << "|---|---|\n";

    int pass = 0, fail = 0;
    for (auto& c : checks)
    {
        juce::String icon;
        if (c.status == "pass") { icon = ":white_check_mark:"; ++pass; }
        else if (c.status == "fail") { icon = ":x:"; ++fail; }
        else { icon = ":warning:"; }

        body << "| " << icon << " | " << c.label << " |\n";
    }

    body << "\n";

    body << "---\n_Generated by " << config_.appName << " v" << config_.appVersion << "_\n";

    return body;
}

juce::String GitHubUploader::formatInlineIssueBody (const DiagnosticData& data)
{
    juce::String body;

    if (data.userFeedback.isNotEmpty())
        body << "## User Feedback\n\n" << data.userFeedback << "\n\n";

    if (data.userEmail.isNotEmpty())
        body << "**Contact email:** " << data.userEmail << "\n\n";

    body << "---\n\n_Note: File upload failed, including inline report (may be truncated)_\n\n";

    body << data.systemInfo << "\n\n---\n\n";
    body << data.pluginStatus << "\n\n---\n\n";
    body << data.dependencies << "\n\n---\n\n";
    body << data.pythonEnvironment << "\n\n---\n\n";
    body << data.pipelineHealth << "\n\n---\n\n";
    body << data.sessionLogs << "\n\n---\n\n";
    body << data.crashLogs << "\n\n---\n\n";
    body << data.pluginValidation << "\n\n---\n\n";
    body << data.dawDiagnostics << "\n\n---\n\n";
    body << data.installerInfo << "\n\n---\n\n";
    body << data.securityInfo << "\n\n---\n\n";

    body << "_Report generated by " << config_.appName << " v" << config_.appVersion << "_\n";

    return body;
}

juce::String GitHubUploader::createIssue (const juce::String& title, const juce::String& body, juce::String& errorOut)
{
    auto url = juce::URL ("https://api.github.com/repos/" + config_.githubRepo + "/issues")
                   .withPOSTData ("{\"title\":" + juce::JSON::toString (title)
                                  + ",\"body\":" + juce::JSON::toString (body)
                                  + ",\"labels\":[\"diagnostic-report\",\"automated\","
                                 #if JUCE_WINDOWS
                                  "\"windows\""
                                 #elif JUCE_MAC
                                  "\"macos\""
                                 #elif JUCE_LINUX
                                  "\"linux\""
                                 #endif
                                  "]}");

    int statusCode = 0;

    for (int attempt = 0; attempt < config_.githubAPIRetries; ++attempt)
    {
        auto options = juce::URL::InputStreamOptions (juce::URL::ParameterHandling::inPostData)
                           .withExtraHeaders ("Accept: application/vnd.github+json\r\n"
                                              "Authorization: Bearer " + config_.githubPAT + "\r\n"
                                              "X-GitHub-Api-Version: 2022-11-28\r\n"
                                              "Content-Type: application/json\r\n")
                           .withConnectionTimeoutMs (config_.githubAPITimeout * 1000)
                           .withStatusCode (&statusCode);

        auto stream = url.createInputStream (options);

        if (stream != nullptr)
        {
            auto responseBody = stream->readEntireStreamAsString();

            if (statusCode == 201)
            {
                auto json = juce::JSON::parse (responseBody);
                if (auto* obj = json.getDynamicObject())
                {
                    auto htmlUrl = obj->getProperty ("html_url").toString();
                    if (htmlUrl.isNotEmpty())
                        return htmlUrl;
                }
                errorOut = "Could not parse issue URL from response.";
                return {};
            }
            else if (statusCode == 401 || statusCode == 403)
            {
                errorOut = "GitHub authentication failed. Please check your Personal Access Token.";
                return {};
            }
            else if (statusCode == 429)
            {
                errorOut = "GitHub rate limit exceeded. Please try again later.";
                return {};
            }
            else
            {
                errorOut = "HTTP " + juce::String (statusCode) + ": " + responseBody.substring (0, 200);
                if (statusCode >= 500 && attempt < config_.githubAPIRetries - 1)
                {
                    juce::Thread::sleep ((attempt + 1) * 2000);
                    continue;
                }
                return {};
            }
        }
        else
        {
            errorOut = "Network error: could not connect to GitHub.";
            if (attempt < config_.githubAPIRetries - 1)
            {
                juce::Thread::sleep ((attempt + 1) * 2000);
                continue;
            }
            return {};
        }
    }

    return {};
}
