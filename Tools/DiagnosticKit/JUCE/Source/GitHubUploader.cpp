#include "GitHubUploader.h"

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
        body = formatIssueBody (data, reportUrl, crashLogUrls);
    else
        body = formatInlineIssueBody (data);

    return createIssue (title, body, errorOut);
}

juce::String GitHubUploader::stripBase64Whitespace (const juce::String& base64)
{
    juce::String clean;
    clean.preallocateBytes ((size_t) base64.length());
    for (auto c : base64)
    {
        if (c != '\r' && c != '\n' && c != ' ')
            clean += c;
    }
    return clean;
}

juce::String GitHubUploader::uploadViaCurl (const juce::String& urlStr, const juce::File& payloadFile, juce::String& errorOut)
{
    // Write curl status to a file instead of relying on ChildProcess pipes
    auto statusFile = juce::File::getSpecialLocation (juce::File::tempDirectory)
                          .getChildFile ("diag_curl_status_" + juce::String (juce::Random::getSystemRandom().nextInt()) + ".txt");

    auto batchFile = juce::File::getSpecialLocation (juce::File::tempDirectory)
                         .getChildFile ("diag_curl_" + juce::String (juce::Random::getSystemRandom().nextInt()) + ".bat");

    juce::String batch;
    batch << "@echo off\r\n";
    batch << "curl.exe -s -w \"%%{http_code}\" -o NUL -X PUT"
          << " -H \"Authorization: Bearer " << config_.githubPAT << "\""
          << " -H \"Accept: application/vnd.github+json\""
          << " -H \"X-GitHub-Api-Version: 2022-11-28\""
          << " -H \"Content-Type: application/json\""
          << " -d @\"" << payloadFile.getFullPathName() << "\""
          << " \"" << urlStr << "\""
          << " > \"" << statusFile.getFullPathName() << "\" 2>&1\r\n";

    batchFile.replaceWithText (batch);

    juce::ChildProcess proc;
    bool finished = false;
    if (proc.start ("cmd.exe /C \"" + batchFile.getFullPathName() + "\""))
        finished = proc.waitForProcessToFinish (60000);

    if (! finished)
        proc.kill();

    batchFile.deleteFile();

    // Read the status from the file curl wrote
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

    // Base64 encode the content, strip whitespace (JUCE adds MIME line breaks)
    juce::MemoryBlock mb (content.toRawUTF8(), (size_t) content.getNumBytesAsUTF8());
    auto base64 = stripBase64Whitespace (mb.toBase64Encoding());

    // Build JSON payload — use manual escaping since base64 is already clean alphanumeric+/+=
    juce::String payload = "{\"message\":\"Add diagnostic files\",\"content\":\"" + base64 + "\",\"branch\":\"main\"}";

    // Write payload to temp file (avoids command-line length limits)
    auto tempFile = juce::File::getSpecialLocation (juce::File::tempDirectory)
                        .getChildFile ("diag_upload_" + juce::String (juce::Random::getSystemRandom().nextInt()) + ".json");
    tempFile.replaceWithText (payload);

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

    auto base64 = stripBase64Whitespace (mb.toBase64Encoding());

    juce::String payload = "{\"message\":\"Add diagnostic files\",\"content\":\"" + base64 + "\",\"branch\":\"main\"}";

    // Write payload to temp file
    auto tempFile = juce::File::getSpecialLocation (juce::File::tempDirectory)
                        .getChildFile ("diag_upload_" + juce::String (juce::Random::getSystemRandom().nextInt()) + ".json");
    tempFile.replaceWithText (payload);

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
                                               const juce::StringPairArray& crashLogUrls)
{
    juce::String body;

    // User feedback section
    body << "## User Feedback\n\n";
    if (data.userFeedback.isNotEmpty())
        body << data.userFeedback << "\n\n";
    else
        body << "_No description provided_\n\n";

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

    // Quick summary with status indicators
    body << "## Quick Summary\n\n```\n";

    // Extract key status lines from each section
    auto extractStatus = [](const juce::String& section)
    {
        juce::String result;
        auto lines = juce::StringArray::fromLines (section);
        for (auto& line : lines)
        {
            auto trimmed = line.trim();
            if (trimmed.startsWith ("**") || trimmed.contains ("\xe2\x9c\x93") // ✓
                || trimmed.contains ("\xe2\x9c\x97") // ✗
                || trimmed.contains ("\xe2\x9a\xa0")) // ⚠
            {
                result << trimmed << "\n";
            }
        }
        return result;
    };

    body << extractStatus (data.pluginStatus);
    body << extractStatus (data.dependencies);
    body << extractStatus (data.pythonEnvironment);
    body << extractStatus (data.pipelineHealth);
    body << extractStatus (data.securityInfo);
    body << "```\n\n";

    body << "---\n_Generated by " << config_.appName << " v" << config_.appVersion << "_\n";

    return body;
}

juce::String GitHubUploader::formatInlineIssueBody (const DiagnosticData& data)
{
    juce::String body;

    if (data.userFeedback.isNotEmpty())
        body << "## User Feedback\n\n" << data.userFeedback << "\n\n---\n\n";

    body << "_Note: File upload failed, including inline report (may be truncated)_\n\n";

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
