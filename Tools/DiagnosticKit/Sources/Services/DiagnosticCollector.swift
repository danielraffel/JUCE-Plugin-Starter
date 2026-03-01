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

    private func collectSystemInfo() async -> String {
        var info = "# System Information\n\n"

        // macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        info += "**macOS Version:** \(osVersion)\n"

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

        return info
    }

    private func collectPluginStatus() async -> String {
        var status = "# Plugin Status\n\n"

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Check Audio Unit
        if config.checkAU {
            let auPath = "\(homeDir)/Library/Audio/Plug-Ins/Components/\(config.pluginName).component"
            let auExists = FileManager.default.fileExists(atPath: auPath)
            status += "**Audio Unit:** \(auExists ? "✅ Installed" : "❌ Not Found")\n"
            if auExists, let auInfo = getFileInfo(auPath) {
                status += auInfo
            }
            status += "\n"
        }

        // Check VST3
        if config.checkVST3 {
            let vst3Path = "\(homeDir)/Library/Audio/Plug-Ins/VST3/\(config.pluginName).vst3"
            let vst3Exists = FileManager.default.fileExists(atPath: vst3Path)
            status += "**VST3:** \(vst3Exists ? "✅ Installed" : "❌ Not Found")\n"
            if vst3Exists, let vst3Info = getFileInfo(vst3Path) {
                status += vst3Info
            }
            status += "\n"
        }

        // Check Standalone
        if config.checkStandalone {
            let standalonePath = "/Applications/\(config.pluginName).app"
            let standaloneFolderPath = "/Applications/\(config.pluginName)/\(config.pluginName).app"

            var standaloneExists = FileManager.default.fileExists(atPath: standalonePath)
            var actualPath = standalonePath

            if !standaloneExists {
                standaloneExists = FileManager.default.fileExists(atPath: standaloneFolderPath)
                actualPath = standaloneFolderPath
            }

            status += "**Standalone App:** \(standaloneExists ? "✅ Installed" : "❌ Not Found")\n"
            if standaloneExists, let appInfo = getFileInfo(actualPath) {
                status += appInfo
            }
            status += "\n"
        }

        return status
    }

    private func collectCrashLogs() async -> String {
        var logs = "# Recent Crash Logs\n\n"

        let crashReportsPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/Logs/DiagnosticReports"

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: crashReportsPath) else {
            return logs + "_No crash logs found_\n"
        }

        // Filter crash logs for our plugin (last 7 days)
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let relevantLogs = files.filter { filename in
            filename.contains(config.pluginName) && filename.hasSuffix(".crash")
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
            logs += "_No recent crash logs found for \(config.pluginName)_\n"
        } else {
            logs += "Found \(relevantLogs.count) crash log(s) from the last 7 days:\n\n"
            for (filename, date) in relevantLogs.prefix(5) {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                logs += "- `\(filename)` (\(formatter.string(from: date)))\n"
            }

            // Include content of most recent crash
            if let mostRecent = relevantLogs.first {
                let fullPath = "\(crashReportsPath)/\(mostRecent.0)"
                if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                    logs += "\n## Most Recent Crash\n\n"
                    logs += "```\n"
                    logs += String(content.prefix(2000)) // Limit size
                    if content.count > 2000 {
                        logs += "\n... (truncated)\n"
                    }
                    logs += "```\n"
                }
            }
        }

        return logs
    }

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
                return String(output.prefix(500)) // Limit size
            }
        } catch {
            return nil
        }

        return nil
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
