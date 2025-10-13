# Generic Diagnostic Logging Implementation Prompt

**Purpose:** A reusable prompt for implementing file-based diagnostic logging with instance/session tracking and easy log access in JUCE audio plugins.

**Based on:** Production-tested patterns from professional audio applications.

---

## Prompt Template

> **Context:** I'm developing a JUCE audio plugin called [PLUGIN_NAME]. I want to implement a comprehensive diagnostic logging system that writes to disk for debugging issues in production.
>
> **Requirements:**
>
> ### 1. Dual Logging Strategy
>
> Implement TWO log files for maximum flexibility:
>
> #### **Global Log (Easy Access)**
> - **Location**: `~/Library/Application Support/[PluginName]/logs/[pluginname]_log.txt`
> - **Purpose**: Aggregates ALL log messages from ALL plugin instances/sessions
> - **Benefit**: Single file to check - no hunting through UUID folders!
> - **Access**: Can be accessed at any time with simple path
>
> #### **Session Log (Historical Debugging)**
> - **Location**: `~/Library/Application Support/[PluginName]/instances/{instanceUUID}/session-{sessionUUID}/[pluginname]_log.txt`
> - **Purpose**: Isolated logs for specific plugin instances and sessions
> - **Benefit**: Track issues across multiple instances, identify instance-specific problems
> - **Structure**:
>   ```
>   ~/Library/Application Support/[PluginName]/
>   ├── logs/
>   │   └── [pluginname]_log.txt          ← GLOBAL LOG (check here first!)
>   ├── instances/
>       ├── {instance-uuid-1}/
>       │   ├── session-{session-uuid-1}/
>       │   │   └── [pluginname]_log.txt   ← Session-specific log
>       │   └── session-{session-uuid-2}/
>       │       └── [pluginname]_log.txt
>       └── {instance-uuid-2}/
>           └── session-{session-uuid-1}/
>               └── [pluginname]_log.txt
>   ```
>
> ### 2. DiagnosticLogger Class
>
> Create a singleton logger class with these features:
>
> ```cpp
> class DiagnosticLogger
> {
> public:
>     static DiagnosticLogger& getInstance();
>
>     // Initialize with plugin instance info
>     void initialize(const juce::String& pluginName,
>                    const juce::String& instanceUUID,
>                    const juce::String& sessionUUID);
>
>     // Log levels
>     void logInfo(const juce::String& message);
>     void logWarning(const juce::String& message);
>     void logError(const juce::String& message);
>     void logDebug(const juce::String& message);  // Only in debug builds
>
>     // Convenience method
>     void log(const juce::String& message, LogLevel level = LogLevel::Info);
>
>     // Get log file paths for CLAUDE.md reference
>     juce::File getGlobalLogFile() const;
>     juce::File getSessionLogFile() const;
>     juce::String getLogStatus() const;  // For debugging logger itself
>
> private:
>     DiagnosticLogger() = default;
>
>     // Thread-safe writing
>     void writeToLogs(const juce::String& formattedMessage);
>     juce::String formatMessage(const juce::String& message, LogLevel level);
>
>     // File paths
>     juce::File globalLogFile;
>     juce::File sessionLogFile;
>
>     // Instance info
>     juce::String pluginName;
>     juce::String instanceUUID;
>     juce::String sessionUUID;
>
>     // Thread safety
>     juce::CriticalSection logMutex;
>     bool initialized = false;
> };
> ```
>
> ### 3. Log Message Format
>
> Each log entry should include:
> - **Timestamp**: ISO 8601 format (YYYY-MM-DD HH:MM:SS.mmm)
> - **Log Level**: [INFO], [WARNING], [ERROR], [DEBUG]
> - **Instance ID**: First 8 chars of instance UUID (for multi-instance debugging)
> - **Message**: The actual log content
>
> **Example format:**
> ```
> 2025-10-11 14:23:45.123 [INFO] [Instance: 1a2b3c4d] Plugin initialized
> 2025-10-11 14:23:45.456 [DEBUG] [Instance: 1a2b3c4d] MIDI Note ON: 60 velocity: 100
> 2025-10-11 14:23:46.789 [WARNING] [Instance: 1a2b3c4d] Buffer underrun detected
> 2025-10-11 14:23:47.012 [ERROR] [Instance: 1a2b3c4d] Failed to load preset: file not found
> ```
>
> ### 4. Instance and Session Management
>
> **Instance UUID:**
> - Created once per plugin instantiation (when plugin loads in DAW)
> - Persists across sessions (save/load)
> - Helps identify issues with specific plugin instances
> - Generated with: `juce::Uuid().toString()`
>
> **Session UUID:**
> - Created each time the project is opened
> - New UUID per session
> - Helps track issues across multiple project open/close cycles
> - Generated with: `juce::Uuid().toString()`
>
> **Best Practice:**
> - Create instance UUID in constructor
> - Create session UUID in `prepareToPlay()` or when first needed
> - Store both in plugin state for persistence
>
> ### 5. Initialization Pattern
>
> ```cpp
> // In AudioProcessor constructor:
> BucketpluckAudioProcessor::BucketpluckAudioProcessor()
> {
>     // Create instance UUID (persists across sessions)
>     instanceUUID = juce::Uuid().toString();
>
>     // Initialize diagnostic logger with instance info
>     // Session UUID will be created in prepareToPlay
>     DiagnosticLogger::getInstance().initialize(
>         "Bucketpluck",          // Plugin name
>         instanceUUID,           // Instance UUID
>         ""                      // Session UUID (empty for now)
>     );
>
>     DiagnosticLogger::getInstance().logInfo("Plugin instance created");
> }
>
> // In prepareToPlay:
> void BucketpluckAudioProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
> {
>     // Create new session UUID each time project is opened
>     if (sessionUUID.isEmpty())
>     {
>         sessionUUID = juce::Uuid().toString();
>
>         // Update logger with session info
>         DiagnosticLogger::getInstance().initialize(
>             "Bucketpluck",
>             instanceUUID,
>             sessionUUID
>         );
>
>         DiagnosticLogger::getInstance().logInfo("Session started - Sample rate: " +
>             juce::String(sampleRate) + " Hz, Buffer size: " + juce::String(samplesPerBlock));
>     }
> }
> ```
>
> ### 6. Thread Safety
>
> **Critical Requirements:**
> - Use `juce::CriticalSection` for all file writes
> - Wrap all `appendText()` calls in try-catch to prevent crashes
> - Never block audio thread - logs should be fast
> - Consider using a lock-free queue for high-frequency logs (optional advanced feature)
>
> **Basic Thread-Safe Pattern:**
> ```cpp
> void DiagnosticLogger::writeToLogs(const juce::String& message)
> {
>     juce::ScopedLock lock(logMutex);
>
>     try {
>         if (globalLogFile.existsAsFile() || globalLogFile.create().wasOk())
>         {
>             globalLogFile.appendText(message + "\n");
>         }
>
>         if (sessionLogFile.existsAsFile() || sessionLogFile.create().wasOk())
>         {
>             sessionLogFile.appendText(message + "\n");
>         }
>     } catch (...) {
>         // Silently fail - never crash due to logging
>     }
> }
> ```
>
> ### 7. Integration Points
>
> **Where to Add Logging:**
>
> #### **Lifecycle Events:**
> ```cpp
> // Constructor
> DiagnosticLogger::getInstance().logInfo("Plugin initialized");
>
> // prepareToPlay
> DiagnosticLogger::getInstance().logInfo("Preparing to play - SR: " +
>     juce::String(sampleRate) + " Hz");
>
> // releaseResources
> DiagnosticLogger::getInstance().logInfo("Resources released");
>
> // Destructor
> DiagnosticLogger::getInstance().logInfo("Plugin destroyed");
> ```
>
> #### **MIDI Events:**
> ```cpp
> if (message.isNoteOn())
> {
>     DiagnosticLogger::getInstance().logDebug("MIDI Note ON: " +
>         juce::String(message.getNoteNumber()) +
>         " velocity: " + juce::String(message.getVelocity()));
> }
> ```
>
> #### **Voice Management:**
> ```cpp
> void KSVoice::startNote(int midiNoteNumber, float velocity, ...)
> {
>     DiagnosticLogger::getInstance().logDebug("Voice started: note " +
>         juce::String(midiNoteNumber) + " velocity " + juce::String(velocity));
> }
> ```
>
> #### **Audio Processing Issues:**
> ```cpp
> if (buffer.getNumSamples() == 0)
> {
>     DiagnosticLogger::getInstance().logWarning("Empty buffer received");
> }
> ```
>
> #### **Parameter Changes:**
> ```cpp
> void BucketpluckAudioProcessor::setParameter(int index, float newValue)
> {
>     DiagnosticLogger::getInstance().logDebug("Parameter " +
>         juce::String(index) + " changed to " + juce::String(newValue));
> }
> ```
>
> ### 8. CLAUDE.md Integration
>
> Add this section to your CLAUDE.md so Claude knows where to find logs:
>
> ```markdown
> ## Diagnostic Logging
>
> This plugin implements dual-location diagnostic logging for easy debugging.
>
> ### Quick Log Access
>
> **Global Log (Check here first!):**
> ```
> ~/Library/Application Support/[PluginName]/logs/[pluginname]_log.txt
> ```
> This file contains ALL logs from ALL plugin instances/sessions. Most issues can be diagnosed here.
>
> **Session Logs (For specific instances):**
> ```
> ~/Library/Application Support/[PluginName]/instances/{uuid}/session-{uuid}/[pluginname]_log.txt
> ```
> Use these for debugging specific plugin instances or comparing behavior across instances.
>
> ### When User Says "Check Logs"
>
> 1. Read the global log first:
>    ```bash
>    tail -100 ~/Library/Application Support/[PluginName]/logs/[pluginname]_log.txt
>    ```
>
> 2. If needed, find the latest session log:
>    ```bash
>    find ~/Library/Application\ Support/[PluginName]/instances -name "[pluginname]_log.txt" -type f -print0 | xargs -0 ls -lt | head -1
>    ```
>
> 3. Show relevant sections based on issue:
>    - MIDI issues: `grep "MIDI" [logfile]`
>    - Voice issues: `grep "Voice" [logfile]`
>    - Parameter issues: `grep "Parameter" [logfile]`
>    - Errors only: `grep "ERROR" [logfile]`
>
> ### Log Levels
>
> - **[INFO]**: Normal operation events (lifecycle, initialization)
> - **[DEBUG]**: Detailed debugging info (MIDI events, voice starts/stops) - Debug builds only
> - **[WARNING]**: Potential issues that don't stop operation
> - **[ERROR]**: Actual errors that need attention
> ```
>
> ### 9. Debug vs Release Builds
>
> **Debug Builds:**
> - Log everything (INFO, DEBUG, WARNING, ERROR)
> - Verbose logging of MIDI events, voice allocation, parameter changes
> - Performance not critical
>
> **Release Builds:**
> - Log only INFO, WARNING, ERROR (skip DEBUG)
> - Focus on lifecycle events and actual errors
> - Minimize performance impact
>
> **Implementation:**
> ```cpp
> void DiagnosticLogger::logDebug(const juce::String& message)
> {
>     #if JUCE_DEBUG
>         log(message, LogLevel::Debug);
>     #else
>         juce::ignoreUnused(message);
>     #endif
> }
> ```
>
> ### 10. Error Handling
>
> **Never crash due to logging failures!**
>
> ```cpp
> void DiagnosticLogger::writeToLogs(const juce::String& message)
> {
>     juce::ScopedLock lock(logMutex);
>
>     try {
>         // Ensure directory exists
>         globalLogFile.getParentDirectory().createDirectory();
>
>         // Try to write to global log
>         if (globalLogFile.existsAsFile() || globalLogFile.create().wasOk())
>         {
>             globalLogFile.appendText(message + "\n");
>         }
>     } catch (const std::exception& e) {
>         // Could log to system console as fallback
>         DBG("Failed to write to log: " + juce::String(e.what()));
>     } catch (...) {
>         // Silently fail - never crash
>         DBG("Unknown error writing to log");
>     }
> }
> ```
>
> ### 11. Audio Unit Sandbox Entitlements (macOS) **[CRITICAL]**

**⚠️ IMPORTANT:** Audio Unit plugins on macOS are sandboxed and **CANNOT** write to Application Support without special entitlements!

**Problem:**
- AU plugins run in a sandbox (security feature)
- Without entitlements, file writes **silently fail** (no errors, no logs)
- VST3 and Standalone are NOT sandboxed (no entitlements needed)

**Solution:**

#### Step 1: Create Entitlements File

Create `Resources/[PluginName].entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Enable App Sandbox (required for AU plugins) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- ⚠️ CRITICAL: Allow file access to Application Support for diagnostic logging -->
    <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
    <array>
        <string>/Users/</string>
        <string>/tmp/</string>
    </array>

    <!-- Optional: Allow reading user-selected files (for preset loading) -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
```

#### Step 2: Configure in CMakeLists.txt

Add this **after** your `juce_add_plugin()` and `target_link_libraries()` for the AU target:

```cmake
# Set code signing entitlements for AU target (required for file access)
if(APPLE)
    set_target_properties(YourPlugin_AU PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_SOURCE_DIR}/Resources/YourPlugin.entitlements"
    )
endif()
```

**Example for multiple plugins:**

```cmake
# For effect plugin AU
if(APPLE)
    set_target_properties(BucketpluckFX_AU PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_SOURCE_DIR}/Resources/Bucketpluck.entitlements"
    )
endif()

# For instrument plugin AU
if(APPLE)
    set_target_properties(BucketpluckKS_AU PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_SOURCE_DIR}/Resources/Bucketpluck.entitlements"
    )
endif()
```

#### Step 3: Full Rebuild Required

**⚠️ CRITICAL:** After adding entitlements, you MUST regenerate the CMake build:

```bash
./scripts/generate_and_open_xcode.sh
```

Simply rebuilding in Xcode **will NOT apply** the new entitlements!

#### Entitlements Explained

| Entitlement | Purpose | Required? |
|-------------|---------|-----------|
| `com.apple.security.app-sandbox` | Enables sandbox (all AU plugins need this) | ✅ Yes |
| `com.apple.security.temporary-exception.files.absolute-path.read-write` | Allows writing to `/Users/` (Application Support) | ✅ Yes for logging |
| `com.apple.security.files.user-selected.read-only` | Allows reading files user opens via dialog | Optional |

**Why "temporary exception"?**
- Apple prefers more restricted entitlements
- For production, consider using `com.apple.security.files.user-selected.read-write` with user permission dialogs
- Temporary exception is fine for development and diagnostic logging

#### Verification

After rebuild with entitlements:

1. **Check entitlements are applied:**
   ```bash
   codesign -d --entitlements - ~/Library/Audio/Plug-Ins/Components/YourPlugin.component
   ```

2. **Test file writing:**
   - Load AU in your DAW
   - Check log file exists:
     ```bash
     ls -la ~/Library/Application\ Support/YourPlugin/logs/
     tail -f ~/Library/Application\ Support/YourPlugin/logs/yourplugin_log.txt
     ```

3. **If logs still don't appear:**
   - ❌ Did you regenerate CMake? (not just rebuild)
   - ❌ Is entitlements file path correct in CMakeLists.txt?
   - ❌ Is the file in `Resources/` folder at project root?
   - ✅ Try `SKIP_CMAKE_REGEN=0 ./scripts/generate_and_open_xcode.sh`

#### Common Pitfalls

| Issue | Symptom | Solution |
|-------|---------|----------|
| No entitlements | AU logs don't write (silent failure) | Add entitlements + regenerate CMake |
| Wrong file path | Build succeeds but no logs | Check `Resources/YourPlugin.entitlements` exists |
| Forgot CMake regen | Old build without permissions | Run `./scripts/generate_and_open_xcode.sh` |
| VST3 not logging | VST3 doesn't need entitlements | Check VST3 code has DiagnosticLogger calls |

---

## ⚠️ CRITICAL: JUCE Path Behavior on macOS

### The Problem
**`juce::File::userApplicationDataDirectory` returns `~/Library`, NOT `~/Library/Application Support`**

This is a common gotcha that causes logs to be written to the wrong location!

### Symptoms
- Logs appear in `/Users/username/Library/YourPlugin/logs/` (wrong!)
- Logs missing from expected location `~/Library/Application Support/YourPlugin/logs/`
- "File not found" errors when checking standard app support location

### The Fix
Build the Application Support path manually:

```cpp
// ❌ WRONG - Returns ~/Library (system/cache location)
auto appSupportDir = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);

// ✅ CORRECT - Builds ~/Library/Application Support (standard macOS app data location)
auto homeDir = juce::File::getSpecialLocation(juce::File::userHomeDirectory);
auto appSupportDir = homeDir.getChildFile("Library").getChildFile("Application Support");
auto pluginDir = appSupportDir.getChildFile("YourPlugin");
auto logsDir = pluginDir.getChildFile("logs");
```

### Why This Matters
- **Standard macOS convention:** `~/Library/Application Support/` is where apps store user-facing data
- **User expectations:** Users and support staff know to check Application Support
- **Tool compatibility:** Backup utilities, Console.app, and other macOS tools expect data there
- **Wrong location:** `~/Library/` is for system caches, preferences, and temporary data

### Testing
Always verify your actual log paths during development:

```bash
# Check where logs are actually being written
find ~/Library -name "your_plugin_log.txt" -type f

# Monitor the correct location
tail -f ~/Library/Application\ Support/YourPlugin/logs/your_plugin_log.txt
```

### Real-World Example
```cpp
void DiagnosticLogger::initialize(const juce::String& pluginName,
                                  const juce::String& instanceUUID,
                                  const juce::String& sessionUUID)
{
    // Build correct path to ~/Library/Application Support/
    auto homeDir = juce::File::getSpecialLocation(juce::File::userHomeDirectory);
    auto appSupportDir = homeDir.getChildFile("Library").getChildFile("Application Support");
    auto bucketpluckDir = appSupportDir.getChildFile("Bucketpluck");
    auto logsDir = bucketpluckDir.getChildFile("logs");

    globalLogFile = logsDir.getChildFile("bucketpluck_log.txt");
    // Result: ~/Library/Application Support/Bucketpluck/logs/bucketpluck_log.txt ✅
}
```

---

### 12. Testing Checklist
>
> ✅ **Initialization:**
> - [ ] Global log file created on first log
> - [ ] Session log file created when session UUID available
> - [ ] Directories created automatically if missing
>
> ✅ **Log Entries:**
> - [ ] Timestamps are accurate and formatted correctly
> - [ ] Log levels display correctly ([INFO], [DEBUG], etc.)
> - [ ] Instance ID shows first 8 chars of UUID
> - [ ] Messages are readable and informative
>
> ✅ **Thread Safety:**
> - [ ] No crashes when logging from audio thread
> - [ ] No crashes when logging from multiple threads simultaneously
> - [ ] No audio dropouts due to logging
>
> ✅ **File Management:**
> - [ ] Logs persist across plugin reloads
> - [ ] Session logs organized by instance/session folders
> - [ ] Global log accumulates all messages
>
> ✅ **CLAUDE.md Integration:**
> - [ ] Log paths documented
> - [ ] Quick access commands provided
> - [ ] Grep patterns for common issues
>
> ---
>
> ## Success Metrics
>
> A successful diagnostic logging implementation will:
>
> ✅ Write to both global and session logs simultaneously
> ✅ Never crash or cause audio dropouts
> ✅ Provide clear, timestamped, categorized log messages
> ✅ Make finding logs easy (global log for quick access)
> ✅ Enable historical debugging (session logs per instance)
> ✅ Help diagnose issues in production environments
> ✅ Be documented in CLAUDE.md for AI assistant access
>
> ---
>
> **Last Updated:** 2025-10-11
> **Version:** 1.0
> **Status:** Production-ready template
