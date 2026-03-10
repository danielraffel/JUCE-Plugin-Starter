#include "PlatformDiagnostics.h"

#if JUCE_WINDOWS

namespace PlatformDiagnostics
{

// Helper: run a command and capture stdout
static juce::String runCommand (const juce::String& cmd, int timeoutMs = 10000)
{
    juce::ChildProcess proc;
    if (proc.start ("cmd.exe /C " + cmd))
    {
        if (proc.waitForProcessToFinish (timeoutMs))
            return proc.readAllProcessOutput().trim();
        proc.kill();
    }
    return {};
}

// Helper: calculate total size of a directory recursively
static juce::int64 getDirectorySize (const juce::File& dir)
{
    juce::int64 total = 0;
    for (auto& entry : juce::RangedDirectoryIterator (dir, true))
    {
        if (entry.getFile().existsAsFile())
            total += entry.getFile().getSize();
    }
    return total;
}

juce::String collectSystemInfo()
{
    juce::String info;
    info << "# System Information\n\n";

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
    info << "**Computer Name:** " << juce::SystemStats::getComputerName() << "\n";

    // GPU info via WMIC
    auto gpuInfo = runCommand ("wmic path win32_videocontroller get name /format:list");
    if (gpuInfo.isNotEmpty())
    {
        auto lines = juce::StringArray::fromLines (gpuInfo);
        for (auto& line : lines)
        {
            if (line.startsWith ("Name="))
                info << "**GPU:** " << line.fromFirstOccurrenceOf ("Name=", false, false) << "\n";
        }
    }

    // Display driver info
    auto driverInfo = runCommand ("wmic path win32_videocontroller get driverversion /format:list");
    if (driverInfo.isNotEmpty())
    {
        auto lines = juce::StringArray::fromLines (driverInfo);
        for (auto& line : lines)
        {
            if (line.startsWith ("DriverVersion="))
                info << "**GPU Driver:** " << line.fromFirstOccurrenceOf ("DriverVersion=", false, false) << "\n";
        }
    }

    return info;
}

juce::String collectAudioDevices()
{
    juce::String info;
    info << "\n## Audio Devices\n\n";

    juce::AudioDeviceManager manager;
    auto& types = manager.getAvailableDeviceTypes();

    for (auto* type : types)
    {
        type->scanForDevices();
        info << "**" << type->getTypeName() << ":**\n";

        auto inputDevices = type->getDeviceNames (true);
        if (inputDevices.size() > 0)
            info << "  Inputs: " << inputDevices.joinIntoString (", ") << "\n";

        auto outputDevices = type->getDeviceNames (false);
        if (outputDevices.size() > 0)
            info << "  Outputs: " << outputDevices.joinIntoString (", ") << "\n";
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
        // Check Program Files install location first
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
        // VST3/CLAP are directories (.vst3/.clap bundles), so use recursive size
        if (pluginFile.isDirectory())
            result.sizeBytes = getDirectorySize (pluginFile);
        else
            result.sizeBytes = pluginFile.getSize();
        result.modifiedTime = pluginFile.getLastModificationTime();
    }

    return result;
}

juce::String collectCrashLogs (const juce::String& pluginName, juce::StringArray* crashFilePaths)
{
    juce::String logs;
    logs << "# Recent Crash Logs\n\n";

    auto weekAgo = juce::Time::getCurrentTime() - juce::RelativeTime::days (7);

    juce::Array<juce::File> matchingFiles;

    // 1. Windows Error Reporting crash dumps
    auto localAppData = juce::File::getSpecialLocation (juce::File::windowsLocalAppData);
    auto werDir = localAppData.getChildFile ("CrashDumps");

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

    // 2. WER ReportQueue
    auto werQueue = localAppData.getChildFile ("Microsoft\\Windows\\WER\\ReportQueue");
    if (werQueue.isDirectory())
    {
        for (auto& dir : juce::RangedDirectoryIterator (werQueue, false))
        {
            if (dir.getFile().isDirectory() && dir.getFile().getFileName().containsIgnoreCase (pluginName))
            {
                for (auto& file : juce::RangedDirectoryIterator (dir.getFile(), false, "*.wer"))
                {
                    if (file.getFile().getLastModificationTime() > weekAgo)
                        matchingFiles.add (file.getFile());
                }
            }
        }
    }

    // 3. Windows Event Log for application crashes (query via wevtutil)
    auto eventLogOutput = runCommand (
        "wevtutil qe Application /q:\"*[System[(Level=1 or Level=2) and TimeCreated[timediff(@SystemTime) <= 604800000]]]\" /f:text /c:20 2>nul",
        15000);

    juce::String relevantEvents;
    if (eventLogOutput.isNotEmpty())
    {
        auto lines = juce::StringArray::fromLines (eventLogOutput);
        bool inRelevantEvent = false;
        juce::String currentEvent;

        for (auto& line : lines)
        {
            if (line.trim().startsWith ("Event["))
            {
                if (inRelevantEvent && currentEvent.isNotEmpty())
                    relevantEvents << currentEvent << "\n";
                currentEvent.clear();
                inRelevantEvent = false;
            }

            currentEvent << line << "\n";

            if (line.containsIgnoreCase (pluginName) || line.containsIgnoreCase ("Application Error"))
                inRelevantEvent = true;
        }

        if (inRelevantEvent && currentEvent.isNotEmpty())
            relevantEvents << currentEvent << "\n";
    }

    // Sort crash dumps by date
    std::sort (matchingFiles.begin(), matchingFiles.end(),
        [](const juce::File& a, const juce::File& b)
        {
            return a.getLastModificationTime() > b.getLastModificationTime();
        });

    if (matchingFiles.isEmpty() && relevantEvents.isEmpty())
    {
        logs << "_No recent crash dumps found for " << pluginName << "_\n";
        return logs;
    }

    if (! matchingFiles.isEmpty())
    {
        logs << "Found " << matchingFiles.size() << " crash dump(s) from the last 7 days:\n\n";

        for (int i = 0; i < juce::jmin (5, matchingFiles.size()); ++i)
        {
            auto& file = matchingFiles[i];
            auto modTime = file.getLastModificationTime().toString (true, true, false);
            auto sizeKB = file.getSize() / 1024;
            logs << "- `" << file.getFileName() << "` (" << modTime << ", " << sizeKB << " KB)\n";

            if (crashFilePaths != nullptr)
                crashFilePaths->add (file.getFullPathName());
        }
    }

    if (relevantEvents.isNotEmpty())
    {
        logs << "\n## Windows Event Log (Application Errors)\n\n";
        logs << "```\n" << relevantEvents.substring (0, 3000) << "\n```\n";
    }

    return logs;
}

juce::String runPluginValidation (const AppConfig& config)
{
    juce::String result;
    result << "# Plugin Validation\n\n";

    // Look for pluginval in common locations
    juce::File pluginval;
    auto programFiles = juce::File ("C:\\Program Files\\pluginval\\pluginval.exe");
    auto localBin = juce::File::getSpecialLocation (juce::File::userHomeDirectory)
                        .getChildFile ("pluginval.exe");
    auto pathResult = runCommand ("where pluginval.exe 2>nul");

    if (programFiles.existsAsFile())
        pluginval = programFiles;
    else if (localBin.existsAsFile())
        pluginval = localBin;
    else if (pathResult.isNotEmpty())
        pluginval = juce::File (pathResult.upToFirstOccurrenceOf ("\n", false, false).trim());

    if (! pluginval.existsAsFile())
    {
        result << "_pluginval not found. Install from https://github.com/Tracktion/pluginval/releases_\n";
        return result;
    }

    // Find the VST3 to validate
    auto vst3Path = juce::File ("C:\\Program Files\\Common Files\\VST3\\" + config.pluginName + ".vst3");
    if (! vst3Path.exists())
    {
        result << "_VST3 plugin not found for validation_\n";
        return result;
    }

    result << "Running pluginval on " << config.pluginName << ".vst3...\n\n";

    juce::ChildProcess proc;
    juce::String cmd = "\"" + pluginval.getFullPathName() + "\" --validate \""
                      + vst3Path.getFullPathName() + "\" --strictness-level 5";

    if (proc.start (cmd))
    {
        if (proc.waitForProcessToFinish (config.diagnosticTimeout * 1000))
        {
            auto output = proc.readAllProcessOutput();
            result << "```\n" << output.getLastCharacters (2000) << "\n```\n";
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
    auto programFiles = juce::File ("C:\\Program Files");

    // ===== Ableton Live =====
    auto abletonDir = appData.getChildFile ("Ableton");
    if (abletonDir.isDirectory())
    {
        info << "## Ableton Live\n\n";
        info << "✓ Ableton Live data found\n";
        for (auto& dir : juce::RangedDirectoryIterator (abletonDir, false, "Live *"))
        {
            info << "  Version: " << dir.getFile().getFileName() << "\n";
            auto logFile = dir.getFile().getChildFile ("Preferences\\Log.txt");
            if (logFile.existsAsFile())
            {
                auto content = logFile.loadFileAsString();
                if (content.containsIgnoreCase (pluginName))
                    info << "  ✓ Plugin referenced in Log.txt\n";
                else
                    info << "  Plugin not found in Log.txt\n";
            }
        }

        // Check Ableton crash reports
        auto abletonReports = appData.getChildFile ("Ableton\\Live Reports\\Usage");
        if (abletonReports.isDirectory())
        {
            auto weekAgo = juce::Time::getCurrentTime() - juce::RelativeTime::days (7);
            int recentCrashes = 0;
            for (auto& file : juce::RangedDirectoryIterator (abletonReports, false, "*.zip"))
            {
                if (file.getFile().getFileName().containsIgnoreCase ("Crash")
                    && file.getFile().getLastModificationTime() > weekAgo)
                    ++recentCrashes;
            }
            if (recentCrashes > 0)
                info << "  ⚠ " << recentCrashes << " recent Ableton crash report(s)\n";
        }
        info << "\n";
    }

    // ===== Cubase / Nuendo =====
    auto steinbergDir = appData.getChildFile ("Steinberg");
    if (steinbergDir.isDirectory())
    {
        for (auto& dir : juce::RangedDirectoryIterator (steinbergDir, false))
        {
            auto dirName = dir.getFile().getFileName();
            if (dirName.startsWithIgnoreCase ("Cubase") || dirName.startsWithIgnoreCase ("Nuendo"))
            {
                info << "## " << dirName << "\n\n";

                // Check VST3 blacklist
                auto blacklist = dir.getFile().getChildFile (dirName + " VST3 Cache\\vst3blacklist.xml");
                if (blacklist.existsAsFile())
                {
                    auto content = blacklist.loadFileAsString();
                    if (content.containsIgnoreCase (pluginName))
                        info << "  ⚠ **Plugin found in VST3 blacklist!**\n";
                    else
                        info << "  ✓ Plugin not in VST3 blacklist\n";
                }

                // Check crash dumps
                auto crashDir = dir.getFile().getChildFile ("Crash Dumps");
                if (crashDir.isDirectory())
                {
                    auto weekAgo = juce::Time::getCurrentTime() - juce::RelativeTime::days (7);
                    int recentDumps = 0;
                    for (auto& file : juce::RangedDirectoryIterator (crashDir, false, "*.dmp"))
                    {
                        if (file.getFile().getLastModificationTime() > weekAgo)
                            ++recentDumps;
                    }
                    if (recentDumps > 0)
                        info << "  ⚠ " << recentDumps << " recent crash dump(s)\n";
                    else
                        info << "  ✓ No recent crash dumps\n";
                }
                info << "\n";
            }
        }
    }

    // ===== Reaper =====
    auto reaperDir = appData.getChildFile ("REAPER");
    if (reaperDir.isDirectory())
    {
        info << "## Reaper\n\n";
        auto vstCache = reaperDir.getChildFile ("reaper-vst3plugins64.ini");
        if (vstCache.existsAsFile())
        {
            auto content = vstCache.loadFileAsString();
            if (content.containsIgnoreCase (pluginName))
                info << "  ✓ Plugin found in VST3 scan cache\n";
            else
                info << "  Plugin NOT found in VST3 scan cache\n";
        }

        // Check CLAP cache too
        auto clapCache = reaperDir.getChildFile ("reaper-clapplugins64.ini");
        if (clapCache.existsAsFile())
        {
            auto content = clapCache.loadFileAsString();
            if (content.containsIgnoreCase (pluginName))
                info << "  ✓ Plugin found in CLAP scan cache\n";
        }
        info << "\n";
    }

    // ===== FL Studio =====
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
            info << "  ⚠ " << recentCrashes << " recent crash log(s)\n";
        else
            info << "  ✓ No recent crash logs\n";

        // Also check FL Studio VST scan database
        auto flScanDb = juce::File::getSpecialLocation (juce::File::userDocumentsDirectory)
                            .getChildFile ("Image-Line\\FL Studio\\Presets\\Plugin database\\Installed");
        if (flScanDb.isDirectory())
        {
            bool found = false;
            for (auto& file : juce::RangedDirectoryIterator (flScanDb, true, "*.nfo"))
            {
                if (file.getFile().getFileName().containsIgnoreCase (pluginName))
                {
                    info << "  ✓ Plugin found in FL Studio database\n";
                    found = true;
                    break;
                }
            }
            if (! found)
                info << "  Plugin not found in FL Studio database\n";
        }
        info << "\n";
    }
    else if (juce::File::getSpecialLocation (juce::File::userDocumentsDirectory)
                 .getChildFile ("Image-Line").isDirectory())
    {
        info << "## FL Studio\n\n";
        info << "  ✓ FL Studio installation detected\n\n";
    }

    // ===== Cakewalk / Sonar / Bandlab =====
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
            info << "  ⚠ " << recentDumps << " recent crash dump(s)\n";
        else
            info << "  ✓ No recent crash dumps\n";
        info << "\n";
    }
    else if (appData.getChildFile ("BandLab Technologies").isDirectory()
             || appData.getChildFile ("Cakewalk").isDirectory())
    {
        info << "## Cakewalk\n\n  ✓ Cakewalk installation detected\n\n";
    }

    // ===== Studio One =====
    auto presonusDir = appData.getChildFile ("PreSonus");
    if (presonusDir.isDirectory())
    {
        for (auto& dir : juce::RangedDirectoryIterator (presonusDir, false, "Studio One*"))
        {
            info << "## Studio One (" << dir.getFile().getFileName() << ")\n\n";

            auto blocklist = dir.getFile().getChildFile ("x64\\PluginBlacklist.settings");
            if (blocklist.existsAsFile())
            {
                auto content = blocklist.loadFileAsString();
                if (content.containsIgnoreCase (pluginName))
                    info << "  ⚠ **Plugin found in blocklist!**\n";
                else
                    info << "  ✓ Plugin not in blocklist\n";
            }

            // Check scan cache
            auto scanCache = dir.getFile().getChildFile ("x64\\VSTPlugins.cache");
            if (scanCache.existsAsFile())
            {
                auto content = scanCache.loadFileAsString();
                if (content.containsIgnoreCase (pluginName))
                    info << "  ✓ Plugin found in VST scan cache\n";
            }
            info << "\n";
        }
    }

    // ===== Bitwig Studio =====
    auto bitwigDir = localAppData.getChildFile ("BitwigStudio");
    if (bitwigDir.isDirectory())
    {
        info << "## Bitwig Studio\n\n";
        auto logFile = bitwigDir.getChildFile ("log\\BitwigStudio.log");
        if (logFile.existsAsFile())
        {
            auto content = logFile.loadFileAsString();
            if (content.containsIgnoreCase (pluginName))
                info << "  ✓ Plugin referenced in BitwigStudio.log\n";
            else
                info << "  Plugin not found in BitwigStudio.log\n";
        }
        info << "\n";
    }

    // ===== Digital Performer =====
    auto dpDir = appData.getChildFile ("MOTU");
    if (dpDir.isDirectory() || programFiles.getChildFile ("MOTU\\Digital Performer").isDirectory())
    {
        info << "## Digital Performer\n\n";
        info << "  ✓ Digital Performer installation detected\n";

        // Check DP plugin cache
        auto dpCache = dpDir.getChildFile ("Digital Performer\\PluginCache");
        if (dpCache.isDirectory())
        {
            bool found = false;
            for (auto& file : juce::RangedDirectoryIterator (dpCache, true))
            {
                if (file.getFile().getFileName().containsIgnoreCase (pluginName))
                {
                    info << "  ✓ Plugin found in DP cache\n";
                    found = true;
                    break;
                }
            }
            if (! found)
                info << "  Plugin not found in DP cache\n";
        }
        info << "\n";
    }

    // ===== Pro Tools =====
    auto proToolsDir = programFiles.getChildFile ("Avid\\Pro Tools");
    if (proToolsDir.isDirectory())
    {
        info << "## Pro Tools\n\n";
        info << "  ✓ Pro Tools installation detected\n";

        // Check AAX plugin location
        auto aaxDir = juce::File ("C:\\Program Files\\Common Files\\Avid\\Audio\\Plug-Ins");
        if (aaxDir.isDirectory())
        {
            bool found = false;
            for (auto& file : juce::RangedDirectoryIterator (aaxDir, true))
            {
                if (file.getFile().getFileName().containsIgnoreCase (pluginName))
                {
                    info << "  ✓ AAX plugin found\n";
                    found = true;
                    break;
                }
            }
            if (! found)
                info << "  AAX plugin not found (plugin uses VST3)\n";
        }
        info << "\n";
    }

    // ===== Reason =====
    auto reasonDir = appData.getChildFile ("Reason Studios");
    if (reasonDir.isDirectory() || programFiles.getChildFile ("Reason Studios").isDirectory())
    {
        info << "## Reason\n\n";
        info << "  ✓ Reason installation detected\n\n";
    }

    // ===== Mixcraft =====
    auto mixcraftDir = programFiles.getChildFile ("Acoustica\\Mixcraft");
    if (mixcraftDir.isDirectory())
    {
        info << "## Mixcraft\n\n";
        info << "  ✓ Mixcraft installation detected\n\n";
    }

    // ===== ACID Pro =====
    auto acidDir = programFiles.getChildFile ("MAGIX\\ACID Pro");
    if (acidDir.isDirectory())
    {
        info << "## ACID Pro\n\n";
        info << "  ✓ ACID Pro installation detected\n\n";
    }

    // ===== Samplitude / Sequoia =====
    auto magixDir = programFiles.getChildFile ("MAGIX");
    if (magixDir.isDirectory())
    {
        for (auto& dir : juce::RangedDirectoryIterator (magixDir, false))
        {
            auto name = dir.getFile().getFileName();
            if (name.containsIgnoreCase ("Samplitude") || name.containsIgnoreCase ("Sequoia"))
            {
                info << "## " << name << "\n\n";
                info << "  ✓ Installation detected\n\n";
            }
        }
    }

    // ===== Waveform / Tracktion =====
    auto tracktionDir = appData.getChildFile ("Tracktion");
    if (tracktionDir.isDirectory())
    {
        info << "## Tracktion/Waveform\n\n";
        info << "  ✓ Tracktion installation detected\n\n";
    }

    if (info == "# DAW Diagnostics\n\n")
        info << "_No DAW installations detected_\n";

    return info;
}

juce::String collectPythonEnvironment (const AppConfig& config)
{
    juce::String info;
    info << "# Python Environment\n\n";

    auto appDataDir = juce::File::getSpecialLocation (juce::File::userApplicationDataDirectory)
                          .getChildFile (config.pluginName);

    // Check for plugin venv
    auto venvDir = appDataDir.getChildFile (config.pluginName + ".venv");
    if (! venvDir.isDirectory())
    {
        // Also check install directory
        auto installDir = juce::File ("C:\\Program Files\\" + config.pluginName + "\\resources");
        venvDir = installDir.getChildFile (config.pluginName + ".venv");
    }

    if (! venvDir.isDirectory())
    {
        info << "✗ Python venv not found\n";
        info << "  Expected at: " << appDataDir.getChildFile (config.pluginName + ".venv").getFullPathName() << "\n";
        return info;
    }

    info << "✓ Python venv found: " << venvDir.getFullPathName() << "\n";

    // Check Python version
    auto pythonExe = venvDir.getChildFile ("Scripts\\python.exe");
    if (pythonExe.existsAsFile())
    {
        auto version = runCommand ("\"" + pythonExe.getFullPathName() + "\" --version");
        if (version.isNotEmpty())
            info << "  Python version: " << version << "\n";
    }
    else
    {
        info << "  ✗ Python executable not found in venv\n";
    }

    // Check critical scripts
    auto resourcesDir = appDataDir;
    auto installResources = juce::File ("C:\\Program Files\\" + config.pluginName + "\\resources");
    if (installResources.isDirectory())
        resourcesDir = installResources;

    juce::StringArray scripts = { "sonicgarbage.py", "essentia_analyzer.py", "words.txt" };
    info << "\n**Installed scripts:**\n";

    for (auto& script : scripts)
    {
        auto scriptFile = resourcesDir.getChildFile (script);
        if (scriptFile.existsAsFile())
        {
            auto sizeKB = scriptFile.getSize() / 1024;
            info << "  ✓ " << script;

            if (script == "words.txt")
            {
                if (scriptFile.getSize() < 1000)
                    info << " ⚠ CORRUPTED (only " << scriptFile.getSize() << " bytes)";
                else
                    info << " (" << sizeKB << " KB)";
            }
            info << "\n";
        }
        else
        {
            info << "  ✗ " << script << " missing";
            if (script == "words.txt")
                info << " - AI SEARCH WILL FAIL!";
            info << "\n";
        }
    }

    // Check critical Python packages
    if (pythonExe.existsAsFile())
    {
        info << "\n**CRITICAL packages (required for downloads):**\n";

        // Write test script to a temp file to avoid cmd.exe quoting issues
        auto tempScript = juce::File::getSpecialLocation (juce::File::tempDirectory)
                              .getChildFile ("diag_pkg_check.py");
        tempScript.replaceWithText (
            "import sys, json\n"
            "p = {}\n"
            "try:\n"
            "    import yt_dlp\n"
            "    p['yt-dlp'] = yt_dlp.version.__version__\n"
            "except: pass\n"
            "try:\n"
            "    import pydub\n"
            "    p['pydub'] = 'installed'\n"
            "except: pass\n"
            "try:\n"
            "    import requests\n"
            "    p['requests'] = requests.__version__\n"
            "except: pass\n"
            "try:\n"
            "    import essentia\n"
            "    p['essentia'] = 'installed'\n"
            "except: pass\n"
            "try:\n"
            "    import numpy\n"
            "    p['numpy'] = numpy.__version__\n"
            "except: pass\n"
            "try:\n"
            "    import soundfile\n"
            "    p['soundfile'] = soundfile.__version__\n"
            "except: pass\n"
            "print(json.dumps(p))\n");

        auto result = runCommand ("\"" + pythonExe.getFullPathName() + "\" \"" + tempScript.getFullPathName() + "\"", 20000);
        tempScript.deleteFile();

        if (result.isNotEmpty() && result.startsWith ("{"))
        {
            auto json = juce::JSON::parse (result);
            if (auto* obj = json.getDynamicObject())
            {
                auto props = obj->getProperties();
                juce::StringArray criticalPkgs = { "yt-dlp", "pydub" };
                juce::StringArray optionalPkgs = { "requests", "essentia", "numpy", "soundfile" };

                for (auto& pkg : criticalPkgs)
                {
                    if (props.contains (juce::Identifier (pkg.replace ("-", "_"))) ||
                        props.contains (juce::Identifier (pkg)))
                    {
                        auto val = obj->getProperty (juce::Identifier (pkg));
                        if (val.isVoid())
                            val = obj->getProperty (juce::Identifier (pkg.replace ("-", "_")));
                        info << "  ✓ " << pkg << " " << val.toString() << "\n";
                    }
                    else
                    {
                        info << "  ✗ " << pkg << " MISSING - Downloads will fail!\n";
                    }
                }

                info << "\n**Optional packages:**\n";
                for (auto& pkg : optionalPkgs)
                {
                    auto key = pkg.replace ("-", "_");
                    if (props.contains (juce::Identifier (key)) || props.contains (juce::Identifier (pkg)))
                    {
                        auto val = obj->getProperty (juce::Identifier (key));
                        if (val.isVoid())
                            val = obj->getProperty (juce::Identifier (pkg));
                        info << "  ✓ " << pkg << " " << val.toString() << "\n";
                    }
                    else
                    {
                        info << "  ○ " << pkg << " not installed\n";
                    }
                }
            }
        }
        else
        {
            info << "  ⚠ Could not check packages\n";
        }
    }

    // Check ffmpeg
    info << "\n**Binary dependencies:**\n";

    auto ffmpegExe = venvDir.getChildFile ("Scripts\\ffmpeg.exe");
    if (! ffmpegExe.existsAsFile())
        ffmpegExe = resourcesDir.getChildFile ("ffmpeg.exe");

    if (ffmpegExe.existsAsFile())
    {
        info << "  ✓ ffmpeg found: " << ffmpegExe.getFullPathName() << "\n";
        auto ver = runCommand ("\"" + ffmpegExe.getFullPathName() + "\" -version 2>&1");
        if (ver.isNotEmpty())
        {
            auto firstLine = ver.upToFirstOccurrenceOf ("\n", false, false);
            info << "    Version: " << firstLine << "\n";
        }
    }
    else
    {
        info << "  ✗ ffmpeg NOT found - audio processing will fail!\n";
        // Check if ffmpeg is on system PATH
        auto systemFfmpeg = runCommand ("where ffmpeg 2>nul");
        if (systemFfmpeg.isNotEmpty())
            info << "    System ffmpeg found at: " << systemFfmpeg.upToFirstOccurrenceOf ("\n", false, false) << "\n";
    }

    // Check Deno — check venv Scripts (primary), then common install paths, then system PATH
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto denoExe = venvDir.getChildFile ("Scripts\\deno.exe");
    if (! denoExe.existsAsFile())
        denoExe = venvDir.getChildFile ("deno\\deno.exe");
    if (! denoExe.existsAsFile())
        denoExe = resourcesDir.getChildFile ("deno\\deno.exe");
    if (! denoExe.existsAsFile())
        denoExe = home.getChildFile (".deno\\bin\\deno.exe");
    if (! denoExe.existsAsFile())
        denoExe = home.getChildFile ("deno\\deno.exe");
    if (! denoExe.existsAsFile())
    {
        auto localAppData = juce::File::getSpecialLocation (juce::File::windowsLocalAppData);
        denoExe = localAppData.getChildFile ("deno\\deno.exe");
    }
    if (! denoExe.existsAsFile())
    {
        // Check system PATH
        auto systemDeno = runCommand ("where deno 2>nul");
        if (systemDeno.isNotEmpty())
            denoExe = juce::File (systemDeno.upToFirstOccurrenceOf ("\n", false, false).trim());
    }

    if (denoExe.existsAsFile())
    {
        info << "  \xe2\x9c\x93 Deno found: " << denoExe.getFullPathName() << "\n";
        auto ver = runCommand ("\"" + denoExe.getFullPathName() + "\" --version");
        if (ver.isNotEmpty())
        {
            auto firstLine = ver.upToFirstOccurrenceOf ("\n", false, false);
            info << "    Version: " << firstLine << "\n";
        }
    }
    else
    {
        info << "  \xe2\x9c\x97 Deno NOT found - YouTube downloads will fail!\n";
        info << "    Deno is required by yt-dlp 2025.11.12+ for YouTube extraction\n";
    }

    return info;
}

juce::String collectSessionLogs (const juce::String& pluginName)
{
    juce::String info;
    info << "# Recent Session Logs\n\n";

    auto samplesDir = juce::File::getSpecialLocation (juce::File::userMusicDirectory)
                          .getChildFile (pluginName + "Samples");

    if (! samplesDir.isDirectory())
    {
        info << "_No sample directory found_\n";
        return info;
    }

    // Look for instance directories with session logs
    auto instancesDir = samplesDir.getChildFile ("instances");
    if (! instancesDir.isDirectory())
    {
        info << "_No session instances found_\n";
        return info;
    }

    // Find most recent Session-* directories
    juce::Array<juce::File> sessionDirs;
    for (auto& dir : juce::RangedDirectoryIterator (instancesDir, false, "Session-*"))
    {
        if (dir.getFile().isDirectory())
            sessionDirs.add (dir.getFile());
    }

    std::sort (sessionDirs.begin(), sessionDirs.end(),
        [](const juce::File& a, const juce::File& b)
        {
            return a.getLastModificationTime() > b.getLastModificationTime();
        });

    if (sessionDirs.isEmpty())
    {
        info << "_No session logs found_\n";
        return info;
    }

    info << "Found " << sessionDirs.size() << " session(s). Showing latest:\n\n";

    // Show info from the 3 most recent sessions
    for (int i = 0; i < juce::jmin (3, sessionDirs.size()); ++i)
    {
        auto& dir = sessionDirs[i];
        auto modTime = dir.getLastModificationTime().toString (true, true, false);
        info << "**" << dir.getFileName() << "** (" << modTime << ")\n";

        // Count files
        int sampleCount = 0;
        for (auto& file : juce::RangedDirectoryIterator (dir, false, "*.wav"))
            ++sampleCount;

        info << "  Samples: " << sampleCount << "\n";

        // Check for log file
        auto logFile = dir.getChildFile ("session.log");
        if (logFile.existsAsFile())
        {
            auto content = logFile.loadFileAsString();
            auto lines = juce::StringArray::fromLines (content);
            // Show last 10 lines
            info << "  Recent log entries:\n";
            for (int j = juce::jmax (0, lines.size() - 10); j < lines.size(); ++j)
            {
                if (lines[j].trim().isNotEmpty())
                    info << "    " << lines[j] << "\n";
            }
        }
        info << "\n";
    }

    return info;
}

juce::String collectInstallerInfo (const AppConfig& config)
{
    juce::String info;
    info << "# Installation Info\n\n";

    // Check Windows registry for install info
    auto regOutput = runCommand (
        "reg query \"HKCU\\Software\\" + config.pluginManufacturer + "\\" + config.pluginName + "\" 2>nul");

    if (regOutput.isNotEmpty())
    {
        info << "**Registry keys found:**\n";
        auto lines = juce::StringArray::fromLines (regOutput);
        for (auto& line : lines)
        {
            auto trimmed = line.trim();
            if (trimmed.isNotEmpty() && ! trimmed.startsWith ("HKEY_"))
                info << "  " << trimmed << "\n";
        }
        info << "\n";
    }

    // Check Inno Setup uninstall registry
    auto uninstallOutput = runCommand (
        "reg query \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\" + config.pluginBundleId + "_is1\" 2>nul");

    if (uninstallOutput.isEmpty())
    {
        uninstallOutput = runCommand (
            "reg query \"HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\" + config.pluginBundleId + "_is1\" 2>nul");
    }

    if (uninstallOutput.isNotEmpty())
    {
        info << "**Installer registration:**\n";
        auto lines = juce::StringArray::fromLines (uninstallOutput);
        for (auto& line : lines)
        {
            auto trimmed = line.trim();
            if (trimmed.containsIgnoreCase ("DisplayVersion") ||
                trimmed.containsIgnoreCase ("InstallDate") ||
                trimmed.containsIgnoreCase ("InstallLocation") ||
                trimmed.containsIgnoreCase ("Publisher"))
            {
                info << "  " << trimmed << "\n";
            }
        }
        info << "\n";
    }
    else
    {
        info << "_No installer registration found_\n\n";
    }

    // Check WinSparkle info
    info << "**Auto-updater (WinSparkle):**\n";
    auto winSparkleOutput = runCommand (
        "reg query \"HKCU\\Software\\WinSparkle\" /s 2>nul");
    if (winSparkleOutput.isNotEmpty() && winSparkleOutput.containsIgnoreCase (config.pluginName))
    {
        auto lines = juce::StringArray::fromLines (winSparkleOutput);
        for (auto& line : lines)
        {
            auto trimmed = line.trim();
            if (trimmed.containsIgnoreCase ("LastCheck") || trimmed.containsIgnoreCase ("SkipVersion"))
                info << "  " << trimmed << "\n";
        }
    }
    else
    {
        info << "  _No WinSparkle data found_\n";
    }
    info << "\n";

    // Check installed file sizes and dates
    info << "**Installed files:**\n";
    auto installDir = juce::File ("C:\\Program Files\\" + config.pluginName);
    if (installDir.isDirectory())
    {
        for (auto& file : juce::RangedDirectoryIterator (installDir, false))
        {
            auto f = file.getFile();
            auto sizeKB = f.getSize() / 1024;
            auto modTime = f.getLastModificationTime().toString (true, true, false);
            info << "  " << f.getFileName() << " (" << sizeKB << " KB, " << modTime << ")\n";
        }
    }
    else
    {
        info << "  _Install directory not found_\n";
    }

    return info;
}

juce::String collectDependencies (const AppConfig& config)
{
    juce::String info;
    info << "# Dependencies\n\n";

    // Check if WinSparkle.dll is alongside the exe
    auto installDir = juce::File ("C:\\Program Files\\" + config.pluginName);
    auto winSparkleDll = installDir.getChildFile ("WinSparkle.dll");

    if (winSparkleDll.existsAsFile())
    {
        info << "✓ WinSparkle.dll found (" << (winSparkleDll.getSize() / 1024) << " KB)\n";
    }
    else
    {
        info << "✗ WinSparkle.dll NOT found - auto-updater will fail!\n";
    }

    // Check Visual C++ runtime
    auto vcRedist = runCommand ("reg query \"HKLM\\SOFTWARE\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\x64\" /v Version 2>nul");
    if (vcRedist.containsIgnoreCase ("Version"))
    {
        auto lines = juce::StringArray::fromLines (vcRedist);
        for (auto& line : lines)
        {
            if (line.containsIgnoreCase ("Version"))
                info << "✓ Visual C++ Runtime: " << line.fromFirstOccurrenceOf ("REG_SZ", false, false).trim() << "\n";
        }
    }
    else
    {
        info << "⚠ Visual C++ Runtime not detected (may cause DLL loading issues)\n";
    }

    // Check DLL dependencies of the standalone exe using dumpbin if available
    auto standaloneExe = installDir.getChildFile (config.pluginName + ".exe");
    if (standaloneExe.existsAsFile())
    {
        info << "\n**Standalone executable:** " << (standaloneExe.getSize() / 1024 / 1024) << " MB\n";
    }

    return info;
}

juce::String collectPipelineHealthCheck (const AppConfig& config)
{
    juce::String info;
    info << "# Pipeline Health Check\n\n";

    auto appDataDir = juce::File::getSpecialLocation (juce::File::userApplicationDataDirectory)
                          .getChildFile (config.pluginName);
    auto venvDir = appDataDir.getChildFile (config.pluginName + ".venv");
    auto installResources = juce::File ("C:\\Program Files\\" + config.pluginName + "\\resources");

    // Find python
    auto pythonExe = venvDir.getChildFile ("Scripts\\python.exe");
    if (! pythonExe.existsAsFile())
    {
        info << "✗ Cannot run health check — Python not found\n";
        return info;
    }

    // Test yt-dlp can fetch metadata (non-download test)
    info << "**yt-dlp test:**\n";
    auto ytDlpTest = runCommand (
        "\"" + pythonExe.getFullPathName() + "\" -m yt_dlp --version", 10000);
    if (ytDlpTest.isNotEmpty() && ! ytDlpTest.containsIgnoreCase ("error"))
    {
        info << "  ✓ yt-dlp responds (version " << ytDlpTest.trim() << ")\n";
    }
    else
    {
        info << "  ✗ yt-dlp failed to respond\n";
    }

    // Test pydub import (use temp file to avoid cmd.exe quoting issues)
    info << "**pydub test:**\n";
    {
        auto tempPydub = juce::File::getSpecialLocation (juce::File::tempDirectory)
                             .getChildFile ("diag_pydub_test.py");
        tempPydub.replaceWithText ("import pydub\nprint('OK')\n");
        auto pydubTest = runCommand (
            "\"" + pythonExe.getFullPathName() + "\" \"" + tempPydub.getFullPathName() + "\"", 10000);
        tempPydub.deleteFile();
        if (pydubTest.contains ("OK"))
            info << "  \xe2\x9c\x93 pydub imports successfully\n";
        else
            info << "  \xe2\x9c\x97 pydub import failed: " << pydubTest.substring (0, 200) << "\n";
    }

    // Test ffmpeg
    info << "**ffmpeg test:**\n";
    auto ffmpegExe = venvDir.getChildFile ("Scripts\\ffmpeg.exe");
    if (! ffmpegExe.existsAsFile())
        ffmpegExe = installResources.getChildFile ("ffmpeg.exe");

    if (ffmpegExe.existsAsFile())
    {
        auto ffmpegTest = runCommand ("\"" + ffmpegExe.getFullPathName() + "\" -version 2>&1", 5000);
        if (ffmpegTest.containsIgnoreCase ("ffmpeg version"))
            info << "  ✓ ffmpeg executes successfully\n";
        else
            info << "  ✗ ffmpeg failed to execute\n";
    }
    else
    {
        info << "  ✗ ffmpeg not found\n";
    }

    // Test Deno
    info << "**Deno test:**\n";
    auto userHome = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto denoExe = venvDir.getChildFile ("Scripts\\deno.exe");
    if (! denoExe.existsAsFile())
        denoExe = venvDir.getChildFile ("deno\\deno.exe");
    if (! denoExe.existsAsFile())
        denoExe = installResources.getChildFile ("deno\\deno.exe");
    if (! denoExe.existsAsFile())
        denoExe = userHome.getChildFile (".deno\\bin\\deno.exe");
    if (! denoExe.existsAsFile())
        denoExe = userHome.getChildFile ("deno\\deno.exe");
    if (! denoExe.existsAsFile())
    {
        auto localApp = juce::File::getSpecialLocation (juce::File::windowsLocalAppData);
        denoExe = localApp.getChildFile ("deno\\deno.exe");
    }
    if (! denoExe.existsAsFile())
    {
        auto systemDeno = runCommand ("where deno 2>nul");
        if (systemDeno.isNotEmpty())
            denoExe = juce::File (systemDeno.upToFirstOccurrenceOf ("\n", false, false).trim());
    }

    if (denoExe.existsAsFile())
    {
        auto denoTest = runCommand ("\"" + denoExe.getFullPathName() + "\" --version", 5000);
        if (denoTest.containsIgnoreCase ("deno"))
            info << "  ✓ Deno executes successfully\n";
        else
            info << "  ✗ Deno failed to execute\n";
    }
    else
    {
        info << "  ✗ Deno not found\n";
    }

    return info;
}

juce::String collectSecurityInfo (const AppConfig& config)
{
    juce::String info;
    info << "# Windows Security\n\n";

    // Check if Windows Defender is running
    auto defenderStatus = runCommand ("powershell -NoProfile -Command \"Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled | Format-List\" 2>nul", 10000);
    if (defenderStatus.containsIgnoreCase ("True"))
        info << "**Windows Defender:** Real-time protection enabled\n";
    else if (defenderStatus.containsIgnoreCase ("False"))
        info << "**Windows Defender:** Real-time protection disabled\n";
    else
        info << "**Windows Defender:** Status unknown\n";

    // Check if our exe is excluded from Defender
    auto exclusions = runCommand ("powershell -NoProfile -Command \"Get-MpPreference | Select-Object -ExpandProperty ExclusionPath\" 2>nul", 10000);
    if (exclusions.containsIgnoreCase (config.pluginName))
        info << "  ✓ " << config.pluginName << " directory is in Defender exclusions\n";

    // Check SmartScreen status
    auto smartScreen = runCommand ("reg query \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\" /v SmartScreenEnabled 2>nul");
    if (smartScreen.containsIgnoreCase ("Off"))
        info << "**SmartScreen:** Disabled\n";
    else if (smartScreen.containsIgnoreCase ("Warn") || smartScreen.containsIgnoreCase ("Block"))
        info << "**SmartScreen:** Enabled (unsigned apps will show warning)\n";
    else
        info << "**SmartScreen:** Status unknown (likely enabled)\n";

    // Check if the exe is digitally signed
    auto standaloneExe = juce::File ("C:\\Program Files\\" + config.pluginName + "\\" + config.pluginName + ".exe");
    if (standaloneExe.existsAsFile())
    {
        auto sigCheck = runCommand (
            "powershell -NoProfile -Command \"(Get-AuthenticodeSignature '" + standaloneExe.getFullPathName() + "').Status\" 2>nul", 10000);
        if (sigCheck.containsIgnoreCase ("Valid"))
            info << "**Code Signature:** ✓ Valid\n";
        else if (sigCheck.containsIgnoreCase ("NotSigned"))
            info << "**Code Signature:** ✗ Not signed (SmartScreen will show warning)\n";
        else
            info << "**Code Signature:** " << sigCheck.trim() << "\n";
    }

    // Check UAC level
    auto uacLevel = runCommand ("reg query \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\" /v ConsentPromptBehaviorAdmin 2>nul");
    if (uacLevel.containsIgnoreCase ("0x0"))
        info << "**UAC:** Disabled\n";
    else if (uacLevel.containsIgnoreCase ("0x5"))
        info << "**UAC:** Default (prompt for consent)\n";
    else
        info << "**UAC:** Enabled\n";

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
