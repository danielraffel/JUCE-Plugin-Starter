#include "DiagnosticCollector.h"
#include "PlatformDiagnostics.h"

DiagnosticData DiagnosticCollector::collectAll (const juce::String& userFeedback)
{
    DiagnosticData data;

    data.systemInfo       = PlatformDiagnostics::collectSystemInfo()
                          + PlatformDiagnostics::collectAudioDevices();
    data.pluginStatus     = collectPluginStatus();
    data.crashLogs        = PlatformDiagnostics::collectCrashLogs (config_.pluginName, &data.crashFilePaths);
    data.pluginValidation = PlatformDiagnostics::runPluginValidation (config_);
    data.dawDiagnostics   = PlatformDiagnostics::collectDAWDiagnostics (config_.pluginName, &data.dawLogFilePaths);
    data.pythonEnvironment = PlatformDiagnostics::collectPythonEnvironment (config_);
    data.sessionLogs      = PlatformDiagnostics::collectSessionLogs (config_.pluginName, &data.sessionLogFilePaths);
    data.installerInfo    = PlatformDiagnostics::collectInstallerInfo (config_);
    data.dependencies     = PlatformDiagnostics::collectDependencies (config_);
    data.pipelineHealth   = PlatformDiagnostics::collectPipelineHealthCheck (config_);
    data.securityInfo     = PlatformDiagnostics::collectSecurityInfo (config_);
    data.userFeedback     = userFeedback;

    return data;
}

juce::String DiagnosticCollector::collectPluginStatus()
{
    juce::String status;
    status << "# Plugin Status\n\n";

   #if JUCE_MAC
    if (config_.checkAU)
    {
        auto info = PlatformDiagnostics::checkPluginInstalled (config_.pluginName, "AU");
        status << "**Audio Unit:** " << (info.installed ? "Installed" : "Not Found") << "\n";
        if (info.installed)
        {
            status << "  - Path: " << info.path << "\n";
            status << "  - Size: " << (info.sizeBytes / 1024) << " KB\n";
            status << "  - Modified: " << info.modifiedTime.toString (true, true, false) << "\n";
        }
        status << "\n";
    }
   #endif

    if (config_.checkVST3)
    {
        auto info = PlatformDiagnostics::checkPluginInstalled (config_.pluginName, "VST3");
        status << "**VST3:** " << (info.installed ? "Installed" : "Not Found") << "\n";
        if (info.installed)
        {
            status << "  - Path: " << info.path << "\n";
            status << "  - Size: " << (info.sizeBytes / 1024) << " KB\n";
            status << "  - Modified: " << info.modifiedTime.toString (true, true, false) << "\n";
        }
        status << "\n";
    }

    if (config_.checkCLAP)
    {
        auto info = PlatformDiagnostics::checkPluginInstalled (config_.pluginName, "CLAP");
        status << "**CLAP:** " << (info.installed ? "Installed" : "Not Found") << "\n";
        if (info.installed)
        {
            status << "  - Path: " << info.path << "\n";
            status << "  - Size: " << (info.sizeBytes / 1024) << " KB\n";
            status << "  - Modified: " << info.modifiedTime.toString (true, true, false) << "\n";
        }
        status << "\n";
    }

    if (config_.checkStandalone)
    {
        auto info = PlatformDiagnostics::checkPluginInstalled (config_.pluginName, "Standalone");
        status << "**Standalone:** " << (info.installed ? "Installed" : "Not Found") << "\n";
        if (info.installed)
        {
            status << "  - Path: " << info.path << "\n";
            status << "  - Size: " << (info.sizeBytes / 1024 / 1024) << " MB\n";
            status << "  - Modified: " << info.modifiedTime.toString (true, true, false) << "\n";
        }
        status << "\n";
    }

    return status;
}
