import Foundation

struct DiagnosticData {
    let systemInfo: String
    let pluginStatus: String
    let crashLogs: String
    let auValidation: String
    let userFeedback: String
}

class DiagnosticCollector {
    private let config: AppConfig

    init(config: AppConfig) {
        self.config = config
    }

    func collectDiagnostics(userFeedback: String = "") async -> DiagnosticData {
        async let systemInfo = collectSystemInfo()
        async let pluginStatus = collectPluginStatus()
        async let crashLogs = collectCrashLogs()
        async let auValidation = runAUValidation()

        return await DiagnosticData(
            systemInfo: systemInfo,
            pluginStatus: pluginStatus,
            crashLogs: crashLogs,
            auValidation: auValidation,
            userFeedback: userFeedback
        )
    }

    // MARK: - System Information

    private func collectSystemInfo() async -> String {
        var info = "# System Information\n\n"

        // macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        info += "**macOS Version:** \(osVersion)\n"

        // Architecture
        #if arch(arm64)
        info += "**Architecture:** Apple Silicon (arm64)\n"
        #else
        info += "**Architecture:** Intel (x86_64)\n"
        #endif

        // Hardware
        if let modelName = getSystemProfilerInfo("SPHardwareDataType", key: "Model Name") {
            info += "**Model:** \(modelName)\n"
        }

        if let chipType = getSystemProfilerInfo("SPHardwareDataType", key: "Chip") {
            info += "**Chip:** \(chipType)\n"
        } else if let processorName = getSystemProfilerInfo("SPHardwareDataType", key: "Processor Name") {
            info += "**Processor:** \(processorName)\n"
        }

        if let memory = getSystemProfilerInfo("SPHardwareDataType", key: "Memory") {
            info += "**Memory:** \(memory)\n"
        }

        // Audio devices
        info += "\n## Audio Devices\n\n"
        if let audioDevices = listAudioDevices() {
            info += audioDevices
        } else {
            info += "_Could not retrieve audio device list_\n"
        }

        // Detected DAWs
        info += "\n## Detected DAWs\n\n"
        info += detectInstalledDAWs()

        return info
    }

    // MARK: - Plugin Status

    private func collectPluginStatus() async -> String {
        var status = "# Plugin Status\n\n"

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Check Audio Unit — both system-level and user-level paths
        if config.checkAU {
            let userAUPath = "\(homeDir)/Library/Audio/Plug-Ins/Components/\(config.pluginName).component"
            let systemAUPath = "/Library/Audio/Plug-Ins/Components/\(config.pluginName).component"

            let userAUExists = FileManager.default.fileExists(atPath: userAUPath)
            let systemAUExists = FileManager.default.fileExists(atPath: systemAUPath)

            if userAUExists {
                status += "**Audio Unit:** ✅ Installed (user)\n"
                if let auInfo = getFileInfo(userAUPath) { status += auInfo }
                status += codeSignatureInfo(userAUPath)
            } else if systemAUExists {
                status += "**Audio Unit:** ✅ Installed (system)\n"
                if let auInfo = getFileInfo(systemAUPath) { status += auInfo }
                status += codeSignatureInfo(systemAUPath)
            } else {
                status += "**Audio Unit:** ❌ Not Found\n"
                status += "  - Checked: `~/Library/Audio/Plug-Ins/Components/`\n"
                status += "  - Checked: `/Library/Audio/Plug-Ins/Components/`\n"
            }
            status += "\n"
        }

        // Check VST3 — both system-level and user-level paths
        if config.checkVST3 {
            let userVST3Path = "\(homeDir)/Library/Audio/Plug-Ins/VST3/\(config.pluginName).vst3"
            let systemVST3Path = "/Library/Audio/Plug-Ins/VST3/\(config.pluginName).vst3"

            let userVST3Exists = FileManager.default.fileExists(atPath: userVST3Path)
            let systemVST3Exists = FileManager.default.fileExists(atPath: systemVST3Path)

            if userVST3Exists {
                status += "**VST3:** ✅ Installed (user)\n"
                if let vst3Info = getFileInfo(userVST3Path) { status += vst3Info }
            } else if systemVST3Exists {
                status += "**VST3:** ✅ Installed (system)\n"
                if let vst3Info = getFileInfo(systemVST3Path) { status += vst3Info }
            } else {
                status += "**VST3:** ❌ Not Found\n"
            }
            status += "\n"
        }

        // Check Standalone — both /Applications/ and ~/Applications/
        if config.checkStandalone {
            let searchPaths = [
                "/Applications/\(config.pluginName).app",
                "/Applications/\(config.pluginName)/\(config.pluginName).app",
                "\(homeDir)/Applications/\(config.pluginName).app",
                "\(homeDir)/Applications/\(config.pluginName)/\(config.pluginName).app"
            ]

            var foundPath: String? = nil
            for path in searchPaths {
                if FileManager.default.fileExists(atPath: path) {
                    foundPath = path
                    break
                }
            }

            if let path = foundPath {
                status += "**Standalone App:** ✅ Installed\n"
                status += "  - Path: `\(path)`\n"
                if let appInfo = getFileInfo(path) { status += appInfo }
                status += codeSignatureInfo(path)
            } else {
                status += "**Standalone App:** ❌ Not Found\n"
            }
            status += "\n"
        }

        return status
    }

    // MARK: - Crash Logs

    private func collectCrashLogs() async -> String {
        var logs = "# Recent Crash Logs\n\n"

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        // 1. Standard macOS crash reports (.crash and .ips files)
        let crashReportsPath = "\(homeDir)/Library/Logs/DiagnosticReports"

        if let files = try? FileManager.default.contentsOfDirectory(atPath: crashReportsPath) {
            let relevantLogs = files.filter { filename in
                let matchesPlugin = filename.contains(config.pluginName)
                let isCrashFile = filename.hasSuffix(".crash") || filename.hasSuffix(".ips")
                return matchesPlugin && isCrashFile
            }.compactMap { filename -> (String, Date)? in
                let fullPath = "\(crashReportsPath)/\(filename)"
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date,
                      modDate > weekAgo else {
                    return nil
                }
                return (filename, modDate)
            }.sorted { $0.1 > $1.1 }

            if relevantLogs.isEmpty {
                logs += "_No recent macOS crash logs found for \(config.pluginName)_\n\n"
            } else {
                logs += "## macOS Crash Reports\n\n"
                logs += "Found \(relevantLogs.count) crash log(s) from the last 7 days:\n\n"
                for (filename, date) in relevantLogs.prefix(5) {
                    logs += "- `\(filename)` (\(dateFormatter.string(from: date)))\n"
                }

                // Include content of most recent crash
                if let mostRecent = relevantLogs.first {
                    let fullPath = "\(crashReportsPath)/\(mostRecent.0)"
                    if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                        logs += "\n### Most Recent Crash\n\n"
                        logs += "```\n"
                        logs += String(content.prefix(3000))
                        if content.count > 3000 {
                            logs += "\n... (truncated)\n"
                        }
                        logs += "```\n"
                    }
                }
                logs += "\n"
            }
        } else {
            logs += "_Could not access ~/Library/Logs/DiagnosticReports_\n\n"
        }

        // 2. Ableton Live crash reports
        let abletonReportsPath = "\(homeDir)/Library/Application Support/Ableton/Live Reports"

        if FileManager.default.fileExists(atPath: abletonReportsPath) {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: abletonReportsPath) {
                let abletonCrashes = files.filter { filename in
                    filename.hasSuffix(".zip")
                }.compactMap { filename -> (String, Date)? in
                    let fullPath = "\(abletonReportsPath)/\(filename)"
                    guard let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                          let modDate = attrs[.modificationDate] as? Date,
                          modDate > weekAgo else {
                        return nil
                    }
                    return (filename, modDate)
                }.sorted { $0.1 > $1.1 }

                if !abletonCrashes.isEmpty {
                    logs += "## Ableton Live Crash Reports\n\n"
                    logs += "Found \(abletonCrashes.count) Ableton crash report(s) from the last 7 days:\n\n"
                    for (filename, date) in abletonCrashes.prefix(3) {
                        logs += "- `\(filename)` (\(dateFormatter.string(from: date)))\n"
                    }
                    logs += "\n_Note: Ableton crash reports are .zip files containing detailed logs._\n"
                    logs += "_Location: `~/Library/Application Support/Ableton/Live Reports/`_\n\n"
                }
            }
        }

        // 3. Logic Pro crash reports (stored as standard .ips files but from AudioComponentRegistrar)
        if let files = try? FileManager.default.contentsOfDirectory(atPath: crashReportsPath) {
            let logicCrashes = files.filter { filename in
                (filename.contains("AudioComponentRegistrar") || filename.contains("Logic Pro")) &&
                (filename.hasSuffix(".crash") || filename.hasSuffix(".ips"))
            }.compactMap { filename -> (String, Date)? in
                let fullPath = "\(crashReportsPath)/\(filename)"
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date,
                      modDate > weekAgo else {
                    return nil
                }
                return (filename, modDate)
            }.sorted { $0.1 > $1.1 }

            if !logicCrashes.isEmpty {
                logs += "## Logic Pro / AU Host Crash Reports\n\n"
                logs += "Found \(logicCrashes.count) AU host crash report(s) from the last 7 days:\n\n"
                for (filename, date) in logicCrashes.prefix(3) {
                    logs += "- `\(filename)` (\(dateFormatter.string(from: date)))\n"
                }
                logs += "\n"
            }
        }

        return logs
    }

    // MARK: - AU Validation

    private func runAUValidation() async -> String {
        guard config.checkAU else {
            return "# AU Validation\n\n_Skipped (AU validation not enabled)_\n"
        }

        var validation = "# AU Validation\n\n"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/auval")
        process.arguments = [
            "-v",
            config.auType,
            config.auSubtype,
            config.auManufacturer
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()

            // Wait with timeout (thread-safe single-resume via lock)
            let timeoutSeconds = config.diagnosticTimeout
            let output: String? = await withCheckedContinuation { continuation in
                var hasResumed = false
                let lock = NSLock()

                func resumeOnce(with value: String?) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: value)
                }

                DispatchQueue.global().async {
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    resumeOnce(with: String(data: data, encoding: .utf8))
                }

                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeoutSeconds)) {
                    if process.isRunning { process.terminate() }
                    resumeOnce(with: nil)
                }
            }

            if let output = output {
                validation += "```\n"
                validation += String(output.suffix(1500)) // Last 1500 chars
                validation += "\n```\n"
            } else {
                validation += "_AU Validation timed out after \(timeoutSeconds) seconds_\n"
            }
        } catch {
            validation += "_Could not run auval: \(error.localizedDescription)_\n"
        }

        return validation
    }

    // MARK: - Helper Functions

    private func getSystemProfilerInfo(_ dataType: String, key: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = [dataType, "-json"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json[dataType] as? [[String: Any]],
                  let firstItem = items.first,
                  let value = firstItem[key] as? String else {
                return nil
            }

            return value
        } catch {
            return nil
        }
    }

    private func listAudioDevices() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPAudioDataType"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return String(output.prefix(500))
            }
        } catch {
            return nil
        }

        return nil
    }

    private func detectInstalledDAWs() -> String {
        var daws = ""

        let dawPaths: [(String, [String])] = [
            ("Logic Pro", [
                "/Applications/Logic Pro.app",
                "/Applications/Logic Pro X.app"
            ]),
            ("Ableton Live", [
                "/Applications/Ableton Live 12 Suite.app",
                "/Applications/Ableton Live 12 Standard.app",
                "/Applications/Ableton Live 12 Intro.app",
                "/Applications/Ableton Live 11 Suite.app",
                "/Applications/Ableton Live 11 Standard.app",
                "/Applications/Ableton Live 11 Intro.app"
            ]),
            ("Pro Tools", [
                "/Applications/Pro Tools.app"
            ]),
            ("GarageBand", [
                "/Applications/GarageBand.app"
            ]),
            ("Studio One", [
                "/Applications/Studio One 6.app",
                "/Applications/Studio One 5.app"
            ]),
            ("FL Studio", [
                "/Applications/FL Studio 24.app",
                "/Applications/FL Studio.app"
            ]),
            ("REAPER", [
                "/Applications/REAPER.app",
                "/Applications/REAPER64.app"
            ]),
            ("Cubase", [
                "/Applications/Cubase 14.app",
                "/Applications/Cubase 13.app",
                "/Applications/Cubase 12.app"
            ]),
            ("Bitwig Studio", [
                "/Applications/Bitwig Studio.app"
            ])
        ]

        var foundAny = false
        for (name, paths) in dawPaths {
            for path in paths {
                if FileManager.default.fileExists(atPath: path) {
                    daws += "- ✅ \(name) (`\(path)`)\n"
                    foundAny = true
                    break
                }
            }
        }

        if !foundAny {
            daws += "_No common DAWs detected in /Applications/_\n"
        }

        return daws
    }

    private func codeSignatureInfo(_ path: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dvv", path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var sigInfo = ""

                // Extract key signing details
                for line in output.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("Authority=") {
                        let authority = String(trimmed.dropFirst("Authority=".count))
                        sigInfo += "  - Signed by: \(authority)\n"
                        break
                    }
                }

                if process.terminationStatus != 0 {
                    sigInfo += "  - Code signature: ⚠️ Invalid or unsigned\n"
                } else if sigInfo.isEmpty {
                    sigInfo += "  - Code signature: ✅ Valid\n"
                }

                return sigInfo
            }
        } catch {
            return "  - Code signature: _Could not check_\n"
        }

        return ""
    }

    private func getFileInfo(_ path: String) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }

        var info = ""

        if let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB]
            formatter.countStyle = .file
            info += "  - Size: \(formatter.string(fromByteCount: size))\n"
        }

        if let modDate = attrs[.modificationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            info += "  - Modified: \(formatter.string(from: modDate))\n"
        }

        return info
    }
}
