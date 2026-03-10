#include "AppConfig.h"

juce::File AppConfig::findEnvFile()
{
    // Check next to executable (standard location on Windows/Linux)
    auto exeDir = juce::File::getSpecialLocation (juce::File::currentExecutableFile).getParentDirectory();
    auto adjacent = exeDir.getChildFile (".env");
    if (adjacent.existsAsFile())
        return adjacent;

    // Check one level up (common in build directories)
    auto parentDir = exeDir.getParentDirectory().getChildFile (".env");
    if (parentDir.existsAsFile())
        return parentDir;

    return {};
}

juce::StringPairArray AppConfig::parseEnv (const juce::String& content)
{
    juce::StringPairArray result;
    auto lines = juce::StringArray::fromLines (content);

    for (auto& line : lines)
    {
        auto trimmed = line.trim();
        if (trimmed.isEmpty() || trimmed.startsWith ("#"))
            continue;

        auto eqPos = trimmed.indexOfChar ('=');
        if (eqPos < 0)
            continue;

        auto key = trimmed.substring (0, eqPos).trim();
        auto value = trimmed.substring (eqPos + 1).trim();

        // Remove surrounding quotes
        if (value.isQuotedString())
            value = value.unquoted();

        result.set (key, value);
    }

    return result;
}

std::optional<AppConfig> AppConfig::load()
{
    auto envFile = findEnvFile();
    if (! envFile.existsAsFile())
        return std::nullopt;

    auto content = envFile.loadFileAsString();
    auto env = parseEnv (content);

    AppConfig config;

    config.appName         = env.getValue ("APP_NAME", config.appName);
    config.appIdentifier   = env.getValue ("APP_IDENTIFIER", config.appIdentifier);
    config.appVersion      = env.getValue ("APP_VERSION", config.appVersion);
    config.githubRepo      = env.getValue ("GITHUB_REPO", "");
    config.githubPAT       = env.getValue ("GITHUB_PAT", "");
    config.supportEmail    = env.getValue ("SUPPORT_EMAIL", "");
    config.productName     = env.getValue ("PRODUCT_NAME", config.productName);
    config.pluginName      = env.getValue ("PLUGIN_NAME", "");
    config.pluginBundleId  = env.getValue ("PLUGIN_BUNDLE_ID", "");
    config.pluginManufacturer = env.getValue ("PLUGIN_MANUFACTURER", "");

    config.checkAU         = env.getValue ("CHECK_AU", "true").toLowerCase() == "true";
    config.checkVST3       = env.getValue ("CHECK_VST3", "true").toLowerCase() == "true";
    config.checkCLAP       = env.getValue ("CHECK_CLAP", "false").toLowerCase() == "true";
    config.checkStandalone = env.getValue ("CHECK_STANDALONE", "true").toLowerCase() == "true";

    config.auType          = env.getValue ("AU_TYPE", config.auType);
    config.auSubtype       = env.getValue ("AU_SUBTYPE", "");
    config.auManufacturer  = env.getValue ("AU_MANUFACTURER", "");

    config.windowWidth     = env.getValue ("WINDOW_WIDTH", "420").getIntValue();
    config.windowHeight    = env.getValue ("WINDOW_HEIGHT", "420").getIntValue();
    config.allowUserFeedback = env.getValue ("ALLOW_USER_FEEDBACK", "true").toLowerCase() == "true";
    config.showPrivacyNotice = env.getValue ("SHOW_PRIVACY_NOTICE", "true").toLowerCase() == "true";

    config.diagnosticTimeout = env.getValue ("DIAGNOSTIC_TIMEOUT", "30").getIntValue();
    config.githubAPITimeout  = env.getValue ("GITHUB_API_TIMEOUT", "10").getIntValue();
    config.githubAPIRetries  = env.getValue ("GITHUB_API_RETRIES", "3").getIntValue();
    config.debugMode         = env.getValue ("DEBUG_MODE", "false").toLowerCase() == "true";

    return config;
}
