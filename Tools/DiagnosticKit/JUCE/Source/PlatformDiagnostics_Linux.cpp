#include "PlatformDiagnostics.h"

#if JUCE_LINUX

namespace PlatformDiagnostics
{

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

    // Kernel version
    juce::ChildProcess proc;
    if (proc.start ("uname -r"))
    {
        auto kernel = proc.readAllProcessOutput().trim();
        info << "**Kernel:** " << kernel << "\n";
    }

    // Distribution info
    auto osRelease = juce::File ("/etc/os-release");
    if (osRelease.existsAsFile())
    {
        auto content = osRelease.loadFileAsString();
        // Extract PRETTY_NAME
        for (auto& line : juce::StringArray::fromLines (content))
        {
            if (line.startsWith ("PRETTY_NAME="))
            {
                auto name = line.fromFirstOccurrenceOf ("=", false, false).unquoted();
                info << "**Distribution:** " << name << "\n";
                break;
            }
        }
    }

    return info;
}

juce::String collectAudioDevices()
{
    juce::String info;
    info << "\n## Audio Devices\n\n";

    // ALSA devices
    juce::ChildProcess proc;
    if (proc.start ("aplay -l"))
    {
        auto output = proc.readAllProcessOutput();
        if (output.isNotEmpty())
        {
            info << "### ALSA Playback Devices\n```\n";
            info << output.substring (0, 500);
            info << "\n```\n\n";
        }
    }

    // Check for JACK
    juce::ChildProcess jackProc;
    if (jackProc.start ("jack_lsp"))
    {
        if (jackProc.waitForProcessToFinish (2000))
        {
            auto output = jackProc.readAllProcessOutput();
            if (output.isNotEmpty())
            {
                info << "### JACK Ports\n```\n";
                info << output.substring (0, 500);
                info << "\n```\n\n";
            }
        }
    }

    // Check for PipeWire
    auto pipewireSocket = juce::File ("/run/user/" + juce::String (getuid()) + "/pipewire-0");
    if (pipewireSocket.exists())
        info << "**PipeWire:** Active\n";

    return info;
}

PluginInstallInfo checkPluginInstalled (const juce::String& pluginName, const juce::String& format)
{
    PluginInstallInfo result;
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    juce::File pluginFile;

    if (format == "VST3")
    {
        pluginFile = home.getChildFile (".vst3/" + pluginName + ".vst3");
        if (! pluginFile.exists())
            pluginFile = juce::File ("/usr/lib/vst3/" + pluginName + ".vst3");
        if (! pluginFile.exists())
            pluginFile = juce::File ("/usr/local/lib/vst3/" + pluginName + ".vst3");
    }
    else if (format == "CLAP")
    {
        pluginFile = home.getChildFile (".clap/" + pluginName + ".clap");
        if (! pluginFile.exists())
            pluginFile = juce::File ("/usr/lib/clap/" + pluginName + ".clap");
    }
    else if (format == "Standalone")
    {
        // Check common binary locations
        pluginFile = juce::File ("/usr/local/bin/" + pluginName);
        if (! pluginFile.exists())
            pluginFile = juce::File ("/usr/bin/" + pluginName);
        if (! pluginFile.exists())
            pluginFile = home.getChildFile (".local/bin/" + pluginName);
    }

    result.installed = pluginFile.exists();
    result.path = pluginFile.getFullPathName();

    if (result.installed)
    {
        if (pluginFile.isDirectory())
            result.sizeBytes = getDirectorySize (pluginFile);
        else
            result.sizeBytes = pluginFile.getSize();
        result.modifiedTime = pluginFile.getLastModificationTime();
    }

    return result;
}

juce::String collectCrashLogs (const juce::String& pluginName, juce::StringArray* /*crashFilePaths*/)
{
    juce::String logs;
    logs << "# Recent Crash Logs\n\n";

    // Check systemd-coredump
    juce::ChildProcess proc;
    if (proc.start ("coredumpctl list --no-pager"))
    {
        if (proc.waitForProcessToFinish (5000))
        {
            auto output = proc.readAllProcessOutput();
            juce::StringArray lines = juce::StringArray::fromLines (output);

            int matchCount = 0;
            juce::String matches;
            for (auto& line : lines)
            {
                if (line.containsIgnoreCase (pluginName))
                {
                    matches << "- " << line.trim() << "\n";
                    ++matchCount;
                }
            }

            if (matchCount > 0)
            {
                logs << "Found " << matchCount << " core dump(s) matching '" << pluginName << "':\n\n";
                logs << matches;
            }
            else
            {
                logs << "_No core dumps found for " << pluginName << "_\n";
            }
        }
        else
        {
            logs << "_coredumpctl timed out_\n";
        }
    }
    else
    {
        logs << "_coredumpctl not available (systemd-coredump may not be installed)_\n";
    }

    return logs;
}

/** Find pluginval. Checks PATH and common locations.
    Does NOT auto-download — pluginval should be installed via the package or bundled by installer. */
static juce::File findPluginVal()
{
    // Check if in PATH
    juce::ChildProcess which;
    if (which.start ("which pluginval"))
    {
        auto path = which.readAllProcessOutput().trim();
        if (path.isNotEmpty())
        {
            juce::File found (path);
            if (found.existsAsFile())
                return found;
        }
    }

    // Check common locations
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto localBin = home.getChildFile (".local/bin/pluginval");
    if (localBin.existsAsFile())
        return localBin;

    // Check next to the diagnostic executable (if bundled by installer)
    auto exeDir = juce::File::getSpecialLocation (juce::File::currentExecutableFile).getParentDirectory();
    auto bundled = exeDir.getChildFile ("pluginval");
    if (bundled.existsAsFile())
        return bundled;

    return {};
}

juce::String runPluginValidation (const AppConfig& config)
{
    juce::String result;
    result << "# Plugin Validation\n\n";

    auto pluginval = findPluginVal();

    if (! pluginval.existsAsFile())
    {
        result << "_Could not find or download pluginval. "
               << "Manual install: https://github.com/Tracktion/pluginval/releases_\n";
        return result;
    }

    result << "Using pluginval: " << pluginval.getFullPathName() << "\n\n";

    // Find VST3 to validate
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto vst3Path = home.getChildFile (".vst3/" + config.pluginName + ".vst3");
    if (! vst3Path.exists())
        vst3Path = juce::File ("/usr/lib/vst3/" + config.pluginName + ".vst3");

    if (! vst3Path.exists())
    {
        result << "_VST3 plugin not found for validation_\n";
        return result;
    }

    result << "Running pluginval on " << config.pluginName << ".vst3...\n\n";

    juce::ChildProcess proc;
    juce::String cmd = pluginval.getFullPathName() + " --validate --validate-in-process --skip-gui-tests --strictness-level 5 "
                     + vst3Path.getFullPathName();

    if (proc.start (cmd))
    {
        int timeoutMs = juce::jmax (120000, config.diagnosticTimeout * 1000);
        if (proc.waitForProcessToFinish (timeoutMs))
        {
            auto output = proc.readAllProcessOutput();
            auto exitCode = proc.getExitCode();

            if (exitCode == 0)
                result << "**Result: PASS**\n\n";
            else
                result << "**Result: FAIL** (exit code " << exitCode << ")\n\n";

            result << "```\n" << output.getLastCharacters (3000) << "\n```\n";
        }
        else
        {
            proc.kill();
            result << "_Validation timed out after " << (timeoutMs / 1000) << " seconds_\n";
        }
    }
    else
    {
        result << "_Could not run pluginval_\n";
    }

    return result;
}

juce::String collectDAWDiagnostics (const juce::String& pluginName, juce::StringArray* dawLogFilePaths)
{
    juce::String info;
    info << "# DAW Diagnostics\n\n";

    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);

    // Helper: extract lines mentioning the plugin from a log file
    // Prioritizes plugin-name matches; only falls back to error/crash lines if no plugin matches
    auto extractRelevantLines = [&pluginName](const juce::File& logFile, int maxLines = 5) -> juce::String
    {
        juce::String result;
        auto content = logFile.loadFileAsString();
        auto lines = juce::StringArray::fromLines (content);

        juce::StringArray pluginMatches;
        for (auto& line : lines)
        {
            if (line.containsIgnoreCase (pluginName))
                pluginMatches.add (line.trim());
        }

        juce::StringArray& matches = pluginMatches;
        juce::StringArray errorMatches;
        if (pluginMatches.isEmpty())
        {
            for (auto& line : lines)
            {
                if (line.containsIgnoreCase ("crash") || line.containsIgnoreCase ("fault")
                    || line.containsIgnoreCase ("exception") || line.containsIgnoreCase ("failed"))
                {
                    errorMatches.add (line.trim());
                }
            }
            matches = errorMatches;
        }

        int start = juce::jmax (0, matches.size() - maxLines);
        for (int i = start; i < matches.size(); ++i)
            result << "    " << matches[i] << "\n";
        return result;
    };

    // Bitwig Studio
    auto bitwigDir = home.getChildFile (".BitwigStudio");
    if (bitwigDir.isDirectory())
    {
        info << "## Bitwig Studio\n\n";
        auto logFile = bitwigDir.getChildFile ("logs/BitwigStudio.log");
        if (logFile.existsAsFile())
        {
            auto content = logFile.loadFileAsString();
            if (content.containsIgnoreCase (pluginName))
            {
                info << "- Plugin referenced in BitwigStudio.log\n";
                auto relevant = extractRelevantLines (logFile);
                if (relevant.isNotEmpty())
                    info << "  Recent relevant entries:\n" << relevant;
                if (dawLogFilePaths != nullptr)
                    dawLogFilePaths->addIfNotAlreadyThere (logFile.getFullPathName());
            }
            else
                info << "- Plugin not found in BitwigStudio.log\n";
        }

        // Check for JVM crash logs
        auto jvmCrash = bitwigDir.getChildFile ("bitwig-studio-jvm-crash.log");
        if (jvmCrash.existsAsFile())
        {
            auto weekAgo = juce::Time::getCurrentTime() - juce::RelativeTime::days (7);
            if (jvmCrash.getLastModificationTime() > weekAgo)
                info << "- **Recent JVM crash log found!**\n";
        }

        // Engine crash reports
        auto engineCrash = bitwigDir.getChildFile ("engine-crash-report");
        if (engineCrash.isDirectory())
        {
            int crashCount = 0;
            for (auto& file : juce::RangedDirectoryIterator (engineCrash, false))
                ++crashCount;
            if (crashCount > 0)
                info << "- " << crashCount << " engine crash report(s)\n";
        }
        info << "\n";
    }

    // Reaper
    auto reaperDir = home.getChildFile (".config/REAPER");
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

        auto reaperLog = reaperDir.getChildFile ("reaper.log");
        if (reaperLog.existsAsFile())
        {
            auto content = reaperLog.loadFileAsString();
            if (content.containsIgnoreCase (pluginName))
            {
                info << "- Plugin referenced in reaper.log\n";
                auto relevant = extractRelevantLines (reaperLog);
                if (relevant.isNotEmpty())
                    info << "  Recent relevant entries:\n" << relevant;
                if (dawLogFilePaths != nullptr)
                    dawLogFilePaths->addIfNotAlreadyThere (reaperLog.getFullPathName());
            }
        }
        info << "\n";
    }

    // Ardour
    for (int ver = 9; ver >= 5; --ver)
    {
        auto ardourDir = home.getChildFile (".config/ardour" + juce::String (ver));
        if (ardourDir.isDirectory())
        {
            info << "## Ardour " << ver << "\n\n";
            info << "- Config directory exists: " << ardourDir.getFullPathName() << "\n\n";
            break;
        }
    }

    // Mixbus
    for (int ver = 10; ver >= 5; --ver)
    {
        auto mixbusDir = home.getChildFile (".config/Mixbus" + juce::String (ver));
        if (mixbusDir.isDirectory())
        {
            info << "## Mixbus " << ver << "\n\n";
            info << "- Config directory exists: " << mixbusDir.getFullPathName() << "\n\n";
            break;
        }
    }

    // Qtractor
    auto qtractorConf = home.getChildFile (".config/rncbc.org/Qtractor.conf");
    if (qtractorConf.existsAsFile())
    {
        info << "## Qtractor\n\n";
        info << "- Config file exists\n\n";
    }

    if (info == "# DAW Diagnostics\n\n")
        info << "_No DAW installations detected_\n";

    return info;
}

juce::StringArray getPluginPaths (const juce::String& format)
{
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    juce::StringArray paths;

    if (format == "VST3")
    {
        paths.add (home.getChildFile (".vst3").getFullPathName());
        paths.add ("/usr/lib/vst3");
        paths.add ("/usr/local/lib/vst3");
    }
    else if (format == "CLAP")
    {
        paths.add (home.getChildFile (".clap").getFullPathName());
        paths.add ("/usr/lib/clap");
    }

    return paths;
}

static juce::String runCmd (const juce::String& cmd, int timeoutMs = 10000)
{
    juce::ChildProcess proc;
    if (proc.start (cmd))
    {
        if (proc.waitForProcessToFinish (timeoutMs))
            return proc.readAllProcessOutput().trim();
        proc.kill();
    }
    return {};
}

juce::String collectPythonEnvironment (const AppConfig& config)
{
    juce::String info;
    info << "# Python Environment\n\n";

    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto appDataDir = home.getChildFile (".local/share/" + config.pluginName);
    auto venvDir = appDataDir.getChildFile (config.pluginName + ".venv");

    if (! venvDir.isDirectory())
    {
        info << "_Python venv not found at " << venvDir.getFullPathName() << "_\n";
        return info;
    }

    auto pythonExe = venvDir.getChildFile ("bin/python");
    if (! pythonExe.existsAsFile())
        pythonExe = venvDir.getChildFile ("bin/python3");

    info << "\xe2\x9c\x93 Python venv found: " << venvDir.getFullPathName() << "\n";

    if (pythonExe.existsAsFile())
    {
        auto pyVer = runCmd ("\"" + pythonExe.getFullPathName() + "\" --version");
        if (pyVer.isNotEmpty())
            info << "  Python version: " << pyVer << "\n";
    }

    // Check installed scripts
    auto scriptsDir = venvDir.getChildFile ("scripts");
    if (! scriptsDir.isDirectory())
        scriptsDir = appDataDir.getChildFile ("scripts");

    info << "\n**Installed scripts:**\n";
    for (auto& name : { "words.txt" })
    {
        auto f = scriptsDir.getChildFile (name);
        if (f.existsAsFile())
            info << "  \xe2\x9c\x93 " << name << "\n";
        else
            info << "  \xe2\x9c\x97 " << name << " not found\n";
    }

    // words.txt integrity check
    auto wordsFile = scriptsDir.getChildFile ("words.txt");
    if (wordsFile.existsAsFile())
    {
        auto sizeKB = wordsFile.getSize() / 1024;
        info << "  \xe2\x9c\x93 words.txt (" << sizeKB << " KB)";
        if (sizeKB > 400)
            info << " \xe2\x9a\xa0 unusually large (legacy version?)";
        else if (sizeKB < 1)
            info << " \xe2\x9a\xa0 suspiciously small";

        // Check for NULL bytes (corruption indicator)
        juce::MemoryBlock mb;
        if (wordsFile.loadFileAsData (mb))
        {
            auto* data = static_cast<const char*> (mb.getData());
            bool hasNulls = false;
            for (size_t i = 0; i < mb.getSize(); ++i)
            {
                if (data[i] == '\0') { hasNulls = true; break; }
            }
            if (hasNulls)
                info << " \xe2\x9c\x97 CORRUPTED (contains NULL bytes)";
        }
        info << "\n";
    }
    else
    {
        info << "  \xe2\x9c\x97 words.txt not found\n";
    }

    // Critical packages
    if (pythonExe.existsAsFile())
    {
        info << "\n**CRITICAL packages (required for downloads):**\n";
        for (auto& pkg : { "yt_dlp", "pydub" })
        {
            auto result = runCmd ("\"" + pythonExe.getFullPathName() + "\" -c \"import " + juce::String (pkg) + "; print('OK')\"");
            if (result.contains ("OK"))
                info << "  \xe2\x9c\x93 " << pkg << "\n";
            else
                info << "  \xe2\x9c\x97 " << pkg << " not installed\n";
        }

        info << "\n**Optional packages:**\n";
        for (auto& pkg : { "requests", "numpy" })
        {
            auto result = runCmd ("\"" + pythonExe.getFullPathName() + "\" -c \"import " + juce::String (pkg) + "; print('OK')\"", 15000);
            if (result.contains ("OK"))
                info << "  \xe2\x9c\x93 " << pkg << "\n";
            else
                info << "  - " << pkg << " not installed\n";
        }
    }

    // Binary dependencies
    info << "\n**Binary dependencies:**\n";
    auto ffmpegExe = venvDir.getChildFile ("bin/ffmpeg");
    if (ffmpegExe.existsAsFile())
    {
        auto ver = runCmd ("\"" + ffmpegExe.getFullPathName() + "\" -version 2>&1");
        auto firstLine = ver.upToFirstOccurrenceOf ("\n", false, false);
        info << "  \xe2\x9c\x93 ffmpeg found: " << ffmpegExe.getFullPathName() << "\n";
        info << "    Version: " << firstLine << "\n";
    }
    else
    {
        // Check system ffmpeg
        auto sysVer = runCmd ("ffmpeg -version 2>&1");
        if (sysVer.containsIgnoreCase ("ffmpeg version"))
            info << "  \xe2\x9c\x93 ffmpeg found (system): " << sysVer.upToFirstOccurrenceOf ("\n", false, false) << "\n";
        else
            info << "  \xe2\x9c\x97 ffmpeg not found\n";
    }

    auto denoExe = venvDir.getChildFile ("bin/deno");
    if (! denoExe.existsAsFile())
        denoExe = home.getChildFile (".deno/bin/deno");
    if (denoExe.existsAsFile())
    {
        auto ver = runCmd ("\"" + denoExe.getFullPathName() + "\" --version");
        info << "  \xe2\x9c\x93 Deno found: " << denoExe.getFullPathName() << "\n";
        info << "    Version: " << ver.upToFirstOccurrenceOf ("\n", false, false) << "\n";
    }
    else
    {
        auto sysVer = runCmd ("deno --version");
        if (sysVer.containsIgnoreCase ("deno"))
            info << "  \xe2\x9c\x93 Deno found (system)\n";
        else
            info << "  \xe2\x9c\x97 Deno not found\n";
    }

    return info;
}

juce::String collectSessionLogs (const juce::String& pluginName, juce::StringArray* sessionLogFilePaths)
{
    juce::String info;
    info << "# Recent Session Logs\n\n";

    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto samplesDir = juce::File::getSpecialLocation (juce::File::userMusicDirectory)
                          .getChildFile (pluginName + "Samples");

    if (! samplesDir.isDirectory())
    {
        info << "_No sample directory found_\n";
        return info;
    }

    auto instancesDir = samplesDir.getChildFile ("instances");
    if (! instancesDir.isDirectory())
    {
        info << "_No session instances found_\n";
        return info;
    }

    juce::Array<juce::File> sessionDirs;
    for (auto& dir : juce::RangedDirectoryIterator (instancesDir, false, "Session-*"))
    {
        if (dir.getFile().isDirectory())
            sessionDirs.add (dir.getFile());
    }

    std::sort (sessionDirs.begin(), sessionDirs.end(),
        [](const juce::File& a, const juce::File& b)
        { return a.getLastModificationTime() > b.getLastModificationTime(); });

    if (sessionDirs.isEmpty())
    {
        info << "_No session logs found_\n";
        return info;
    }

    info << "Found " << sessionDirs.size() << " session(s). Showing latest:\n\n";

    for (int i = 0; i < juce::jmin (3, sessionDirs.size()); ++i)
    {
        auto& dir = sessionDirs[i];
        info << "**" << dir.getFileName() << "** (" << dir.getLastModificationTime().toString (true, true, false) << ")\n";

        int sampleCount = 0;
        for (auto& file : juce::RangedDirectoryIterator (dir, false, "*.wav"))
            ++sampleCount;
        info << "  Samples: " << sampleCount << "\n";

        auto logFile = dir.getChildFile ("session.log");
        if (logFile.existsAsFile())
        {
            if (sessionLogFilePaths != nullptr)
                sessionLogFilePaths->add (logFile.getFullPathName());

            auto content = logFile.loadFileAsString();
            auto lines = juce::StringArray::fromLines (content);
            info << "  Log entries: " << lines.size() << " lines";
            if (sessionLogFilePaths != nullptr)
                info << " (full log will be attached)";
            info << "\n  Recent log entries:\n";
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

    // Check desktop entry
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto desktopEntry = home.getChildFile (".local/share/applications/" + config.pluginName + ".desktop");
    if (desktopEntry.existsAsFile())
        info << "\xe2\x9c\x93 Desktop entry: " << desktopEntry.getFullPathName() << "\n";
    else
        info << "- No desktop entry found\n";

    // Check for install directory
    auto installDir = juce::File ("/opt/" + config.pluginName);
    if (! installDir.isDirectory())
        installDir = home.getChildFile (".local/share/" + config.pluginName);

    if (installDir.isDirectory())
    {
        info << "\n**Installed files in " << installDir.getFullPathName() << ":**\n";
        for (auto& entry : juce::RangedDirectoryIterator (installDir, false))
        {
            auto& f = entry.getFile();
            if (f.existsAsFile())
                info << "  " << f.getFileName() << " (" << (f.getSize() / 1024) << " KB)\n";
        }
    }

    return info;
}

juce::String collectDependencies (const AppConfig& config)
{
    juce::String info;
    info << "# Dependencies\n\n";

    // Check for standalone binary and its dynamic library deps
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto standalone = juce::File ("/usr/local/bin/" + config.pluginName);
    if (! standalone.existsAsFile())
        standalone = home.getChildFile (".local/bin/" + config.pluginName);

    if (standalone.existsAsFile())
    {
        info << "**Standalone executable:** " << (standalone.getSize() / 1024 / 1024) << " MB\n\n";

        // Check linked libraries
        auto lddOutput = runCmd ("ldd \"" + standalone.getFullPathName() + "\" 2>&1");
        if (lddOutput.isNotEmpty())
        {
            bool missingLibs = false;
            for (auto& line : juce::StringArray::fromLines (lddOutput))
            {
                if (line.contains ("not found"))
                {
                    info << "  \xe2\x9c\x97 " << line.trim() << "\n";
                    missingLibs = true;
                }
            }
            if (! missingLibs)
                info << "\xe2\x9c\x93 All shared library dependencies satisfied\n";
        }
    }
    else
    {
        info << "_Standalone binary not found_\n";
    }

    // Check VST3 deps
    auto vst3 = home.getChildFile (".vst3/" + config.pluginName + ".vst3");
    if (vst3.isDirectory())
    {
        auto vst3Bin = vst3.getChildFile ("Contents/x86_64-linux/" + config.pluginName + ".so");
        if (! vst3Bin.existsAsFile())
            vst3Bin = vst3.getChildFile ("Contents/aarch64-linux/" + config.pluginName + ".so");
        if (vst3Bin.existsAsFile())
        {
            info << "\n**VST3 size:** " << (vst3Bin.getSize() / 1024) << " KB\n";
            auto lddVst = runCmd ("ldd \"" + vst3Bin.getFullPathName() + "\" 2>&1");
            bool missingLibs = false;
            for (auto& line : juce::StringArray::fromLines (lddVst))
            {
                if (line.contains ("not found"))
                {
                    info << "  \xe2\x9c\x97 " << line.trim() << "\n";
                    missingLibs = true;
                }
            }
            if (! missingLibs)
                info << "\xe2\x9c\x93 VST3 library dependencies satisfied\n";
        }
    }

    return info;
}

juce::String collectPipelineHealthCheck (const AppConfig& config)
{
    juce::String info;
    info << "# Pipeline Health Check\n\n";

    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto appDataDir = home.getChildFile (".local/share/" + config.pluginName);
    auto venvDir = appDataDir.getChildFile (config.pluginName + ".venv");
    auto pythonExe = venvDir.getChildFile ("bin/python");
    if (! pythonExe.existsAsFile())
        pythonExe = venvDir.getChildFile ("bin/python3");

    if (! pythonExe.existsAsFile())
    {
        info << "\xe2\x9c\x97 Cannot run health check \xe2\x80\x94 Python not found\n";
        return info;
    }

    // yt-dlp
    info << "**yt-dlp test:**\n";
    auto ytdlpVer = runCmd ("\"" + pythonExe.getFullPathName() + "\" -m yt_dlp --version");
    if (ytdlpVer.isNotEmpty() && ! ytdlpVer.containsIgnoreCase ("error"))
        info << "  \xe2\x9c\x93 yt-dlp responds (version " << ytdlpVer.trim() << ")\n";
    else
        info << "  \xe2\x9c\x97 yt-dlp failed to respond\n";

    // pydub
    info << "**pydub test:**\n";
    auto pydubTest = runCmd ("\"" + pythonExe.getFullPathName() + "\" -c \"import pydub; print('OK')\"");
    if (pydubTest.contains ("OK"))
        info << "  \xe2\x9c\x93 pydub imports successfully\n";
    else
        info << "  \xe2\x9c\x97 pydub import failed: " << pydubTest.substring (0, 200) << "\n";

    // ffmpeg
    info << "**ffmpeg test:**\n";
    auto ffmpegExe = venvDir.getChildFile ("bin/ffmpeg");
    if (! ffmpegExe.existsAsFile())
    {
        auto sysPath = runCmd ("which ffmpeg");
        if (sysPath.isNotEmpty())
            ffmpegExe = juce::File (sysPath);
    }
    if (ffmpegExe.existsAsFile())
    {
        auto ffmpegTest = runCmd ("\"" + ffmpegExe.getFullPathName() + "\" -version 2>&1", 5000);
        if (ffmpegTest.containsIgnoreCase ("ffmpeg version"))
            info << "  \xe2\x9c\x93 ffmpeg executes successfully\n";
        else
            info << "  \xe2\x9c\x97 ffmpeg failed to execute\n";
    }
    else
    {
        info << "  \xe2\x9c\x97 ffmpeg not found\n";
    }

    // Deno
    info << "**Deno test:**\n";
    auto denoExe = venvDir.getChildFile ("bin/deno");
    if (! denoExe.existsAsFile())
        denoExe = home.getChildFile (".deno/bin/deno");
    if (! denoExe.existsAsFile())
    {
        auto sysPath = runCmd ("which deno");
        if (sysPath.isNotEmpty())
            denoExe = juce::File (sysPath);
    }
    if (denoExe.existsAsFile())
    {
        auto denoTest = runCmd ("\"" + denoExe.getFullPathName() + "\" --version", 5000);
        if (denoTest.containsIgnoreCase ("deno"))
            info << "  \xe2\x9c\x93 Deno executes successfully\n";
        else
            info << "  \xe2\x9c\x97 Deno failed to execute\n";
    }
    else
    {
        info << "  \xe2\x9c\x97 Deno not found\n";
    }

    // End-to-end pipeline test
    info << "\n**End-to-end pipeline test:**\n";
    info << "  Test: Rick Astley - Never Gonna Give You Up (first 5 seconds)\n";

    auto tempDir = juce::File::getSpecialLocation (juce::File::tempDirectory)
                       .getChildFile ("diag_pipeline_test");
    tempDir.createDirectory();

    info << "  1. yt-dlp download: ";
    auto dlResult = runCmd ("\"" + pythonExe.getFullPathName() + "\" -m yt_dlp --extract-audio --audio-format wav"
        " --download-sections '*0-5' -o '" + tempDir.getFullPathName() + "/test.%(ext)s'"
        " --no-playlist --quiet --no-warnings"
        " https://www.youtube.com/watch?v=dQw4w9WgXcQ 2>&1", 30000);

    auto testWav = tempDir.getChildFile ("test.wav");
    bool downloadOk = testWav.existsAsFile();
    if (downloadOk)
        info << "\xe2\x9c\x93 downloaded (" << (testWav.getSize() / 1024) << " KB)\n";
    else
    {
        info << "\xe2\x9c\x97 failed";
        if (dlResult.isNotEmpty())
            info << " (" << dlResult.substring (0, 150) << ")";
        info << "\n";
    }

    if (downloadOk)
    {
        info << "  2. pydub processing: ";
        auto pyResult = runCmd ("\"" + pythonExe.getFullPathName() + "\" -c \""
            "from pydub import AudioSegment; "
            "audio = AudioSegment.from_wav('" + testWav.getFullPathName() + "'); "
            "normalized = audio.normalize(); "
            "normalized.export('" + tempDir.getChildFile ("processed.wav").getFullPathName() + "', format='wav'); "
            "print('OK')\"", 10000);
        if (pyResult.contains ("OK"))
            info << "\xe2\x9c\x93 audio processed successfully\n";
        else
            info << "\xe2\x9c\x97 processing failed (" << pyResult.substring (0, 150) << ")\n";
    }

    tempDir.deleteRecursively();

    return info;
}

juce::String collectSecurityInfo (const AppConfig& config)
{
    juce::String info;
    info << "# Security Info\n\n";

    // Build type detection
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto standalone = juce::File ("/usr/local/bin/" + config.pluginName);
    if (! standalone.existsAsFile())
        standalone = home.getChildFile (".local/bin/" + config.pluginName);

    if (standalone.existsAsFile())
    {
        // Check if binary is stripped (release) or has debug symbols
        auto fileOutput = runCmd ("file \"" + standalone.getFullPathName() + "\"");
        if (fileOutput.contains ("not stripped"))
            info << "**Build type:** Debug (not stripped)\n";
        else if (fileOutput.contains ("stripped"))
            info << "**Build type:** Release (stripped)\n";
        else
            info << "**Build type:** Unknown\n";
    }

    // AppArmor / SELinux status
    auto aaStatus = runCmd ("aa-status --json 2>/dev/null");
    if (aaStatus.isNotEmpty())
        info << "**AppArmor:** Active\n";
    else
    {
        auto seStatus = runCmd ("getenforce 2>/dev/null");
        if (seStatus.isNotEmpty())
            info << "**SELinux:** " << seStatus << "\n";
        else
            info << "**MAC:** No AppArmor or SELinux detected\n";
    }

    // File permissions on plugin
    auto vst3 = home.getChildFile (".vst3/" + config.pluginName + ".vst3");
    if (vst3.exists())
    {
        auto perms = runCmd ("ls -la \"" + vst3.getFullPathName() + "\"");
        info << "**VST3 permissions:** " << perms.upToFirstOccurrenceOf ("\n", false, false) << "\n";
    }

    return info;
}

} // namespace PlatformDiagnostics

#endif // JUCE_LINUX
