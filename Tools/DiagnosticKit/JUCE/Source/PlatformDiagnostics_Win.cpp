#include "PlatformDiagnostics.h"

#if JUCE_WINDOWS

namespace PlatformDiagnostics
{

juce::String collectSystemInfo()
{
    juce::String info;
    info << "# System Information\n\n";

    // Windows version
    info << "**OS:** " << juce::SystemStats::getOperatingSystemName() << "\n";
    info << "**CPU:** " << juce::SystemStats::getCpuModel() << "\n";
    info << "**CPU Cores:** " << juce::SystemStats::getNumCpus() << "\n";
    info << "**Memory:** " << (juce::SystemStats::getMemorySizeInMegabytes() / 1024) << " GB\n";
    info << "**Architecture:** "
        #if defined(_M_ARM64)
         << "ARM64"
        #elif defined(_M_X64)
         << "x64"
        #else
         << "x86"
        #endif
         << "\n";

    return info;
}

juce::String collectAudioDevices()
{
    juce::String info;
    info << "\n## Audio Devices\n\n";

    // Use JUCE's audio device manager to enumerate
    juce::AudioDeviceManager manager;
    auto types = manager.getAvailableDeviceTypes();

    for (auto* type : types)
    {
        type->scanForDevices();
        info << "**" << type->getTypeName() << ":**\n";

        auto inputDevices = type->getDeviceNames (true);
        if (inputDevices.size() > 0)
        {
            info << "  Inputs: " << inputDevices.joinIntoString (", ") << "\n";
        }

        auto outputDevices = type->getDeviceNames (false);
        if (outputDevices.size() > 0)
        {
            info << "  Outputs: " << outputDevices.joinIntoString (", ") << "\n";
        }
    }

    if (info == "\n## Audio Devices\n\n")
        info << "_No audio devices found_\n";

    return info;
}

PluginInstallInfo checkPluginInstalled (const juce::String& pluginName, const juce::String& format)
{
    PluginInstallInfo result;
    juce::File pluginFile;

    if (format == "VST3")
    {
        pluginFile = juce::File ("C:\\Program Files\\Common Files\\VST3\\" + pluginName + ".vst3");
    }
    else if (format == "CLAP")
    {
        pluginFile = juce::File ("C:\\Program Files\\Common Files\\CLAP\\" + pluginName + ".clap");
    }
    else if (format == "Standalone")
    {
        // Check Program Files and Desktop
        pluginFile = juce::File ("C:\\Program Files\\" + pluginName + "\\" + pluginName + ".exe");
        if (! pluginFile.exists())
        {
            auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
            pluginFile = home.getChildFile ("Desktop\\" + pluginName + ".exe");
        }
    }

    result.installed = pluginFile.exists();
    result.path = pluginFile.getFullPathName();

    if (result.installed)
    {
        result.sizeBytes = pluginFile.getSize();
        result.modifiedTime = pluginFile.getLastModificationTime();
    }

    return result;
}

juce::String collectCrashLogs (const juce::String& pluginName)
{
    juce::String logs;
    logs << "# Recent Crash Logs\n\n";

    auto weekAgo = juce::Time::getCurrentTime() - juce::RelativeTime::days (7);

    // Check Windows Error Reporting
    auto localAppData = juce::File::getSpecialLocation (juce::File::windowsLocalAppData);
    auto werDir = localAppData.getChildFile ("CrashDumps");

    juce::Array<juce::File> matchingFiles;

    if (werDir.isDirectory())
    {
        for (auto& file : juce::RangedDirectoryIterator (werDir, false, "*.dmp"))
        {
            if (file.getFile().getFileName().containsIgnoreCase (pluginName)
                && file.getFile().getLastModificationTime() > weekAgo)
            {
                matchingFiles.add (file.getFile());
            }
        }
    }

    // Also check WER ReportQueue
    auto werQueue = localAppData.getChildFile ("Microsoft\\Windows\\WER\\ReportQueue");
    if (werQueue.isDirectory())
    {
        for (auto& dir : juce::RangedDirectoryIterator (werQueue, false))
        {
            if (dir.getFile().isDirectory() && dir.getFile().getFileName().containsIgnoreCase (pluginName))
            {
                for (auto& file : juce::RangedDirectoryIterator (dir.getFile(), false, "*.wer"))
                    matchingFiles.add (file.getFile());
            }
        }
    }

    matchingFiles.sort ([](const juce::File& a, const juce::File& b)
    {
        return a.getLastModificationTime() > b.getLastModificationTime();
    });

    if (matchingFiles.isEmpty())
    {
        logs << "_No recent crash dumps found for " << pluginName << "_\n";
        return logs;
    }

    logs << "Found " << matchingFiles.size() << " crash dump(s) from the last 7 days:\n\n";

    for (int i = 0; i < juce::jmin (5, matchingFiles.size()); ++i)
    {
        auto& file = matchingFiles[i];
        auto modTime = file.getLastModificationTime().toString (true, true, false);
        auto sizeKB = file.getSize() / 1024;
        logs << "- `" << file.getFileName() << "` (" << modTime << ", " << sizeKB << " KB)\n";
    }

    return logs;
}

juce::String runPluginValidation (const AppConfig& config)
{
    // Try to find pluginval
    juce::String result;
    result << "# Plugin Validation\n\n";

    // Look for pluginval in common locations
    juce::File pluginval;
    auto programFiles = juce::File ("C:\\Program Files\\pluginval\\pluginval.exe");
    auto localBin = juce::File::getSpecialLocation (juce::File::userHomeDirectory)
                        .getChildFile ("pluginval.exe");

    if (programFiles.existsAsFile())
        pluginval = programFiles;
    else if (localBin.existsAsFile())
        pluginval = localBin;

    if (! pluginval.existsAsFile())
    {
        result << "_pluginval not found. Install from https://github.com/Tracktion/pluginval_\n";
        return result;
    }

    // Find the VST3 to validate
    auto vst3Path = juce::File ("C:\\Program Files\\Common Files\\VST3\\" + config.pluginName + ".vst3");
    if (! vst3Path.exists())
    {
        result << "_VST3 plugin not found for validation_\n";
        return result;
    }

    juce::ChildProcess proc;
    juce::String cmd = pluginval.getFullPathName() + " --validate " + vst3Path.getFullPathName() + " --strictness-level 5";

    if (proc.start (cmd))
    {
        if (proc.waitForProcessToFinish (config.diagnosticTimeout * 1000))
        {
            auto output = proc.readAllProcessOutput();
            result << "```\n" << output.getLastCharacters (1500) << "\n```\n";
        }
        else
        {
            proc.kill();
            result << "_Validation timed out after " << config.diagnosticTimeout << " seconds_\n";
        }
    }
    else
    {
        result << "_Could not run pluginval_\n";
    }

    return result;
}

juce::String collectDAWDiagnostics (const juce::String& pluginName)
{
    juce::String info;
    info << "# DAW Diagnostics\n\n";

    auto appData = juce::File::getSpecialLocation (juce::File::userApplicationDataDirectory);
    auto localAppData = juce::File::getSpecialLocation (juce::File::windowsLocalAppData);

    // Ableton Live
    auto abletonDir = appData.getChildFile ("Ableton");
    if (abletonDir.isDirectory())
    {
        info << "## Ableton Live\n\n";
        for (auto& dir : juce::RangedDirectoryIterator (abletonDir, false, "Live *"))
        {
            auto logFile = dir.getFile().getChildFile ("Preferences\\Log.txt");
            if (logFile.existsAsFile())
            {
                auto content = logFile.loadFileAsString();
                if (content.containsIgnoreCase (pluginName))
                    info << "- Plugin referenced in " << dir.getFile().getFileName() << " Log.txt\n";
            }
        }
        info << "\n";
    }

    // Cubase
    auto steinbergDir = appData.getChildFile ("Steinberg");
    if (steinbergDir.isDirectory())
    {
        for (auto& dir : juce::RangedDirectoryIterator (steinbergDir, false, "Cubase*"))
        {
            auto blacklist = dir.getFile().getChildFile ("Cubase Pro VST3 Cache\\vst3blacklist.xml");
            if (blacklist.existsAsFile())
            {
                info << "## Cubase (" << dir.getFile().getFileName() << ")\n\n";
                auto content = blacklist.loadFileAsString();
                if (content.containsIgnoreCase (pluginName))
                    info << "- **WARNING:** Plugin found in VST3 blacklist!\n";
                else
                    info << "- Plugin not in VST3 blacklist\n";
                info << "\n";
            }
        }
    }

    // Reaper
    auto reaperDir = appData.getChildFile ("REAPER");
    if (reaperDir.isDirectory())
    {
        info << "## Reaper\n\n";
        auto vstCache = reaperDir.getChildFile ("reaper-vst3plugins64.ini");
        if (vstCache.existsAsFile())
        {
            auto content = vstCache.loadFileAsString();
            if (content.containsIgnoreCase (pluginName))
                info << "- Plugin found in VST3 scan cache\n";
            else
                info << "- Plugin NOT found in VST3 scan cache\n";
        }
        info << "\n";
    }

    // FL Studio
    auto flDir = juce::File::getSpecialLocation (juce::File::userDocumentsDirectory)
                     .getChildFile ("Image-Line\\FL Studio\\Support\\Logs\\Crash");
    if (flDir.isDirectory())
    {
        info << "## FL Studio\n\n";
        auto weekAgo = juce::Time::getCurrentTime() - juce::RelativeTime::days (7);
        int recentCrashes = 0;
        for (auto& file : juce::RangedDirectoryIterator (flDir, false))
        {
            if (file.getFile().getLastModificationTime() > weekAgo)
                ++recentCrashes;
        }
        if (recentCrashes > 0)
            info << "- " << recentCrashes << " recent crash log(s)\n";
        else
            info << "- No recent crash logs\n";
        info << "\n";
    }

    // Cakewalk / Sonar
    auto cakewalkDir = appData.getChildFile ("Cakewalk\\Sonar\\MiniDumps");
    if (cakewalkDir.isDirectory())
    {
        info << "## Cakewalk/Sonar\n\n";
        auto weekAgo = juce::Time::getCurrentTime() - juce::RelativeTime::days (7);
        int recentDumps = 0;
        for (auto& file : juce::RangedDirectoryIterator (cakewalkDir, false, "*.dmp"))
        {
            if (file.getFile().getLastModificationTime() > weekAgo)
                ++recentDumps;
        }
        if (recentDumps > 0)
            info << "- " << recentDumps << " recent crash dump(s)\n";
        else
            info << "- No recent crash dumps\n";
        info << "\n";
    }

    // Studio One
    auto presonusDir = appData.getChildFile ("PreSonus");
    if (presonusDir.isDirectory())
    {
        for (auto& dir : juce::RangedDirectoryIterator (presonusDir, false, "Studio One*"))
        {
            auto blocklist = dir.getFile().getChildFile ("x64\\PluginBlacklist.settings");
            if (blocklist.existsAsFile())
            {
                info << "## Studio One (" << dir.getFile().getFileName() << ")\n\n";
                auto content = blocklist.loadFileAsString();
                if (content.containsIgnoreCase (pluginName))
                    info << "- **WARNING:** Plugin found in blocklist!\n";
                else
                    info << "- Plugin not in blocklist\n";
                info << "\n";
            }
        }
    }

    // Bitwig
    auto bitwigDir = localAppData.getChildFile ("BitwigStudio");
    if (bitwigDir.isDirectory())
    {
        info << "## Bitwig Studio\n\n";
        auto logFile = bitwigDir.getChildFile ("log\\BitwigStudio.log");
        if (logFile.existsAsFile())
        {
            auto content = logFile.loadFileAsString();
            if (content.containsIgnoreCase (pluginName))
                info << "- Plugin referenced in BitwigStudio.log\n";
            else
                info << "- Plugin not found in BitwigStudio.log\n";
        }
        info << "\n";
    }

    if (info == "# DAW Diagnostics\n\n")
        info << "_No DAW installations detected_\n";

    return info;
}

juce::StringArray getPluginPaths (const juce::String& format)
{
    juce::StringArray paths;

    if (format == "VST3")
        paths.add ("C:\\Program Files\\Common Files\\VST3");
    else if (format == "CLAP")
        paths.add ("C:\\Program Files\\Common Files\\CLAP");

    return paths;
}

} // namespace PlatformDiagnostics

#endif // JUCE_WINDOWS
