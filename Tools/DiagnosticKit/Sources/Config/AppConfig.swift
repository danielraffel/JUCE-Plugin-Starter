import Foundation

struct AppConfig {
    // App Info
    let appName: String
    let appIdentifier: String
    let appVersion: String

    // GitHub
    let githubRepo: String
    let githubPAT: String

    // Support
    let supportEmail: String
    let productName: String
    let productWebsite: String

    // Plugin Info
    let pluginName: String
    let pluginBundleId: String
    let pluginManufacturer: String

    // Plugin Formats
    let checkAU: Bool
    let checkVST3: Bool
    let checkStandalone: Bool

    // Audio Unit specifics
    let auType: String
    let auSubtype: String
    let auManufacturer: String

    // UI Configuration
    let windowWidth: Int
    let windowHeight: Int
    let showTechnicalDetails: Bool
    let allowUserFeedback: Bool
    let showPrivacyNotice: Bool
    let autoSendOnSuccess: Bool

    // Privacy
    let excludeUserPaths: Bool
    let excludeSerialNumbers: Bool
    let anonymizeUsernames: Bool
    let maxLogSizeMB: Int
    let compressLogs: Bool

    // Timeouts
    let diagnosticTimeout: Int
    let githubAPITimeout: Int
    let githubAPIRetries: Int

    // Debug
    let debugMode: Bool

    static func load() -> AppConfig? {
        guard let envPath = Bundle.main.path(forResource: ".env", ofType: nil) else {
            print("Error: .env file not found in bundle")
            return nil
        }

        do {
            let envContent = try String(contentsOfFile: envPath, encoding: .utf8)
            let env = parseEnv(envContent)

            return AppConfig(
                appName: env["APP_NAME"] ?? "Diagnostics",
                appIdentifier: env["APP_IDENTIFIER"] ?? "com.unknown.diagnostics",
                appVersion: env["APP_VERSION"] ?? "1.0.0",
                githubRepo: env["GITHUB_REPO"] ?? "",
                githubPAT: env["GITHUB_PAT"] ?? "",
                supportEmail: env["SUPPORT_EMAIL"] ?? "",
                productName: env["PRODUCT_NAME"] ?? "Plugin",
                productWebsite: env["PRODUCT_WEBSITE"] ?? "",
                pluginName: env["PLUGIN_NAME"] ?? "",
                pluginBundleId: env["PLUGIN_BUNDLE_ID"] ?? "",
                pluginManufacturer: env["PLUGIN_MANUFACTURER"] ?? "",
                checkAU: env["CHECK_AU"]?.lowercased() == "true",
                checkVST3: env["CHECK_VST3"]?.lowercased() == "true",
                checkStandalone: env["CHECK_STANDALONE"]?.lowercased() == "true",
                auType: env["AU_TYPE"] ?? "aufx",
                auSubtype: env["AU_SUBTYPE"] ?? "",
                auManufacturer: env["AU_MANUFACTURER"] ?? "",
                windowWidth: Int(env["WINDOW_WIDTH"] ?? "380") ?? 380,
                windowHeight: Int(env["WINDOW_HEIGHT"] ?? "550") ?? 550,
                showTechnicalDetails: env["SHOW_TECHNICAL_DETAILS"]?.lowercased() == "true",
                allowUserFeedback: env["ALLOW_USER_FEEDBACK"]?.lowercased() != "false",
                showPrivacyNotice: env["SHOW_PRIVACY_NOTICE"]?.lowercased() != "false",
                autoSendOnSuccess: env["AUTO_SEND_ON_SUCCESS"]?.lowercased() == "true",
                excludeUserPaths: env["EXCLUDE_USER_PATHS"]?.lowercased() == "true",
                excludeSerialNumbers: env["EXCLUDE_SERIAL_NUMBERS"]?.lowercased() == "true",
                anonymizeUsernames: env["ANONYMIZE_USERNAMES"]?.lowercased() == "true",
                maxLogSizeMB: Int(env["MAX_LOG_SIZE_MB"] ?? "10") ?? 10,
                compressLogs: env["COMPRESS_LOGS"]?.lowercased() != "false",
                diagnosticTimeout: Int(env["DIAGNOSTIC_TIMEOUT"] ?? "30") ?? 30,
                githubAPITimeout: Int(env["GITHUB_API_TIMEOUT"] ?? "10") ?? 10,
                githubAPIRetries: Int(env["GITHUB_API_RETRIES"] ?? "3") ?? 3,
                debugMode: env["DEBUG_MODE"]?.lowercased() == "true"
            )
        } catch {
            print("Error loading .env: \(error)")
            return nil
        }
    }

    private static func parseEnv(_ content: String) -> [String: String] {
        var result: [String: String] = [:]

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse KEY=VALUE or KEY="VALUE"
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            // Remove quotes if present
            if value.hasPrefix("\"") && value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }

            result[key] = value
        }

        return result
    }
}
