#include "PlatformDiagnostics.h"

#if JUCE_LINUX

namespace PlatformDiagnostics
{

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
        result.sizeBytes = pluginFile.getSize();
        result.modifiedTime = pluginFile.getLastModificationTime();
    }

    return result;
}

juce::String collectCrashLogs (const juce::String& pluginName)
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

juce::String runPluginValidation (const AppConfig& config)
{
    juce::String result;
    result << "# Plugin Validation\n\n";

    // Look for pluginval
    juce::File pluginval;
    juce::ChildProcess which;
    if (which.start ("which pluginval"))
    {
        auto path = which.readAllProcessOutput().trim();
        if (path.isNotEmpty())
            pluginval = juce::File (path);
    }

    if (! pluginval.existsAsFile())
    {
        result << "_pluginval not found. Install from https://github.com/Tracktion/pluginval_\n";
        return result;
    }

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

    return result;
}

juce::String collectDAWDiagnostics (const juce::String& pluginName)
{
    juce::String info;
    info << "# DAW Diagnostics\n\n";

    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);

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
                info << "- Plugin referenced in BitwigStudio.log\n";
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

} // namespace PlatformDiagnostics

#endif // JUCE_LINUX
