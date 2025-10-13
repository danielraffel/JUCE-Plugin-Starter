# Generic Audio/MIDI Settings Implementation Prompt

**Purpose:** A reusable prompt for implementing professional audio/MIDI device configuration with auto-detection, real-time feedback, and persistent settings in JUCE audio plugins.

**Based on:** Proven patterns from production JUCE applications.

---

## Prompt Template

> **Context:** I'm developing a JUCE audio plugin called [PLUGIN_NAME]. I want to implement a professional audio/MIDI settings system with device auto-detection, real-time input monitoring, and user-friendly configuration UI.
>
> **Requirements:**
>
> ### 1. Settings Button & Panel System
>
> Implement a settings button/menu that opens a configuration panel with:
> - **Modal overlay** with dark background
> - **Tabbed interface** for organizing settings
> - **Audio/MIDI Settings button** in main settings tab
> - **Keyboard shortcuts** (ESC to close, TAB navigation)
> - **Auto-save** with debounced persistence (2-second delay)
>
> ### 2. Audio/MIDI Configuration Window
>
> Create a dedicated modal dialog for device configuration with **two tabs**:
>
> #### **Audio Tab:**
> - Output device dropdown
> - Input device dropdown
> - Sample rate selector
> - Buffer size selector
> - **Test button** (plays 440Hz sine tone)
> - **Input level meter** (8-bar VU meter with color coding)
>   - Blue: Normal levels (-∞ to -12dB)
>   - Orange: High levels (-12dB to -3dB)
>   - Red: Peak levels (-3dB to 0dB)
> - Real-time visual feedback of input audio
>
> #### **MIDI Tab:**
> - **Scrollable list** of all available MIDI input devices
> - **Toggle button** for each device (enable/disable)
> - **Bluetooth MIDI button** (opens system Audio MIDI Setup)
> - **Exclude Bluetooth devices from list** (prevents crashes on some systems)
> - **Visual indicator** for currently enabled devices
>
> ### 3. Auto-Detection & Auto-Enable System
>
> Implement automatic MIDI device detection with:
> - **Periodic scanning** (every 1 second via Timer)
> - **Change listener** for immediate device change detection
> - **Auto-enable new devices** when connected
> - **Standalone-only feature** (disabled in plugin mode)
> - **Persistent device preferences** (remember user's enable/disable choices)
> - **Known devices list** (track which devices have been seen before)
>
> **Detection Algorithm:**
> ```
> 1. Get current list of available MIDI devices
> 2. Compare to known devices list
> 3. For NEW devices:
>    - Add to known devices list
>    - Auto-enable the device
>    - Save to preferences
> 4. For KNOWN devices:
>    - Check user's saved preference (enabled/disabled)
>    - Apply saved preference if it differs from current state
> 5. Update UI to reflect current device states
> ```
>
> ### 4. Settings Persistence
>
> Implement a settings manager with:
> - **Thread-safe singleton** pattern
> - **Debounced auto-save** (wait 2 seconds after last change)
> - **Type-safe accessors** (getBool, getInt, getString, etc.)
> - **XML storage** using JUCE ApplicationProperties
> - **Platform-appropriate location**:
>   - macOS: `~/Library/Application Support/[PluginName]/`
>   - Windows: `%APPDATA%/[PluginName]/`
>
> **Settings Structure:**
> ```xml
> <settings>
>   <!-- User preferences -->
>   <general>
>     <property name="darkMode" value="true"/>
>     <property name="tooltipsEnabled" value="true"/>
>   </general>
>
>   <!-- MIDI device preferences -->
>   <midi_known_devices>
>     <device id="device_identifier_1"/>
>     <device id="device_identifier_2"/>
>   </midi_known_devices>
>
>   <midi_device_states>
>     <device id="device_identifier_1" enabled="true"/>
>     <device id="device_identifier_2" enabled="false"/>
>   </midi_device_states>
>
>   <!-- Audio settings handled by JUCE AudioDeviceManager -->
> </settings>
> ```
>
> ### 5. Device Manager Access Pattern
>
> Implement proper device manager access for both standalone and plugin modes:
>
> ```cpp
> juce::AudioDeviceManager* getDeviceManager()
> {
>     // Standalone mode: Use StandalonePluginHolder
>     if (auto* holder = juce::StandalonePluginHolder::getInstance())
>         return &holder->deviceManager;
>
>     // Plugin mode: Create local fallback (limited functionality)
>     static juce::AudioDeviceManager fallbackManager;
>     static bool initialized = false;
>
>     if (!initialized)
>     {
>         fallbackManager.initialiseWithDefaultDevices(2, 2);
>         initialized = true;
>     }
>
>     return &fallbackManager;
> }
> ```
>
> ### 6. Real-time Input Level Monitoring
>
> Implement audio input level monitoring with:
> - **AudioIODeviceCallback** interface implementation
> - **RMS level calculation** across all input channels
> - **60 Hz UI update** via Timer
> - **Smoothing filter** (70% old value + 30% new value)
> - **Auto-scaling** (multiply by 4x for visible range)
> - **8-bar vertical VU meter** component
>
> **Algorithm:**
> ```cpp
> // In audio callback
> void audioDeviceIOCallback(const float** input, int numInputChannels, int numSamples)
> {
>     float maxLevel = 0.0f;
>
>     for (int ch = 0; ch < numInputChannels; ++ch)
>     {
>         float sum = 0.0f;
>         for (int i = 0; i < numSamples; ++i)
>             sum += input[ch][i] * input[ch][i];
>
>         float rms = std::sqrt(sum / numSamples);
>         maxLevel = std::max(maxLevel, rms);
>     }
>
>     currentInputLevel.store(maxLevel);  // Atomic for thread safety
> }
>
> // In timer callback (UI thread)
> void timerCallback()
> {
>     float level = currentInputLevel.load();
>     level = std::min(1.0f, level * 4.0f);  // Auto-gain
>     smoothedLevel = smoothedLevel * 0.7f + level * 0.3f;  // Smooth
>     meterComponent->setLevel(smoothedLevel);
> }
> ```
>
> ### 7. Save/Cancel Button Pattern
>
> Implement save/cancel with proper state management:
> - **On dialog open**: Store original AudioDeviceSetup
> - **Real-time preview**: Changes apply immediately as user adjusts
> - **Save button**: Just closes dialog (changes already applied)
> - **Cancel button**: Restore original setup, then close dialog
>
> ```cpp
> class AudioMidiWindow
> {
>     juce::AudioDeviceManager::AudioDeviceSetup originalSetup;
>
>     void onOpen()
>     {
>         originalSetup = deviceManager.getAudioDeviceSetup();
>     }
>
>     void onSaveClicked()
>     {
>         // Settings already applied - just close
>         closeWindow();
>     }
>
>     void onCancelClicked()
>     {
>         // Revert to original settings
>         juce::String error = deviceManager.setAudioDeviceSetup(originalSetup, true);
>         closeWindow();
>     }
> }
> ```
>
> ### 8. UI Component Hierarchy
>
> **Recommended structure:**
> ```
> SettingsPanel (modal overlay)
> ├── TabbedComponent
> │   ├── GeneralTab
> │   │   ├── Various settings controls
> │   │   └── "Audio/MIDI Settings..." button ← TRIGGERS DIALOG
> │   ├── OtherTab1
> │   └── OtherTab2
>
> AudioMidiWindow (separate modal window)
> ├── TabbedComponent
> │   ├── AudioTab
> │   │   ├── Output device ComboBox
> │   │   ├── Input device ComboBox
> │   │   ├── Sample rate ComboBox
> │   │   ├── Buffer size ComboBox
> │   │   ├── Test button
> │   │   └── InputLevelMeter (custom component)
> │   └── MIDITab
> │       ├── ScrollableContainer
> │       │   └── Device toggles (dynamically generated)
> │       └── Bluetooth MIDI button
> └── Save/Cancel buttons
> ```
>
> ### 9. JUCE Classes to Use
>
> **Core Classes:**
> - `juce::AudioDeviceManager` - Central device management
> - `juce::MidiInput::getAvailableDevices()` - Get MIDI device list
> - `juce::AudioIODeviceCallback` - Audio callback interface
> - `juce::ChangeListener` - Device change notifications
> - `juce::Timer` - Periodic updates, UI refresh
>
> **UI Classes:**
> - `juce::DocumentWindow` - Modal dialog window
> - `juce::TabbedComponent` - Tab containers
> - `juce::ComboBox` - Dropdowns for device selection
> - `juce::ToggleButton` - MIDI device enable/disable
> - `juce::TextButton` - Save/Cancel/Test buttons
> - `juce::Component` - Base for custom components (VU meter)
>
> **Storage Classes:**
> - `juce::ApplicationProperties` - Settings persistence
> - `juce::PropertiesFile` - XML file handling
> - `juce::XmlElement` - Settings structure
> - `juce::StandalonePluginHolder` - Standalone context access
>
> ### 10. Implementation Strategy
>
> **Phase 1: Settings Panel (1-2 days)**
> 1. Create SettingsComponent with tabbed interface
> 2. Add "Audio/MIDI Settings..." button to General tab
> 3. Implement modal overlay pattern
> 4. Add keyboard shortcuts (ESC, TAB)
> 5. Test show/hide functionality
>
> **Phase 2: Audio/MIDI Window (2-3 days)**
> 1. Create AudioMidiWindow as DocumentWindow
> 2. Implement Audio tab with device dropdowns
> 3. Implement MIDI tab with device toggles
> 4. Add test tone generator (440Hz sine)
> 5. Integrate with AudioDeviceManager
> 6. Test save/cancel functionality
>
> **Phase 3: Input Level Meter (1 day)**
> 1. Create InputLevelMeterComponent (custom Component)
> 2. Implement AudioIODeviceCallback for level detection
> 3. Add RMS calculation and smoothing
> 4. Draw 8-bar VU meter with color coding
> 5. Connect to timer for 60 Hz updates
>
> **Phase 4: Auto-Detection System (1-2 days)**
> 1. Create MidiDeviceAutoEnabler class
> 2. Implement Timer for 1-second polling
> 3. Add ChangeListener for immediate detection
> 4. Implement known devices tracking
> 5. Add auto-enable logic for new devices
> 6. Test plug/unplug scenarios
>
> **Phase 5: Settings Persistence (1 day)**
> 1. Create SettingsManager singleton
> 2. Implement type-safe getters/setters
> 3. Add debounced auto-save (2-second delay)
> 4. Store MIDI device preferences
> 5. Load preferences on startup
> 6. Test persistence across app restarts
>
> ### 11. Testing Checklist
>
> After implementation, verify:
> - [ ] Settings button opens modal panel
> - [ ] Audio/MIDI button opens configuration window
> - [ ] Audio tab shows all available devices
> - [ ] MIDI tab shows all non-Bluetooth devices
> - [ ] Bluetooth MIDI button opens system Audio MIDI Setup
> - [ ] Input level meter responds to audio input
> - [ ] Test button plays 440Hz tone
> - [ ] New MIDI devices are auto-enabled when plugged in
> - [ ] User preferences persist across app restarts
> - [ ] Cancel button reverts changes
> - [ ] Save button applies changes
> - [ ] ESC key closes dialogs
> - [ ] Works in standalone mode (primary use case)
> - [ ] Gracefully degrades in plugin mode
> - [ ] No crashes when devices are plugged/unplugged
> - [ ] Settings save/load correctly
>
> ### 12. Common Pitfalls to Avoid
>
> ❌ **Don't include Bluetooth MIDI devices in device list**
> ```cpp
> // BAD: Can cause crashes on some systems
> auto devices = juce::MidiInput::getAvailableDevices();
> for (const auto& device : devices)
>     addDeviceToList(device);
> ```
>
> ✅ **Filter out Bluetooth devices**
> ```cpp
> // GOOD: Safe filtering
> auto devices = juce::MidiInput::getAvailableDevices();
> for (const auto& device : devices)
> {
>     if (!device.name.containsIgnoreCase("bluetooth"))
>         addDeviceToList(device);
> }
> ```
>
> ❌ **Don't forget to unregister callbacks**
> ```cpp
> // BAD: Memory leak
> class MidiMonitor
> {
>     MidiMonitor() { deviceManager.addChangeListener(this); }
>     // Missing: deviceManager.removeChangeListener(this);
> };
> ```
>
> ✅ **Always cleanup**
> ```cpp
> // GOOD: Proper cleanup
> ~MidiMonitor()
> {
>     deviceManager.removeChangeListener(this);
>     stopTimer();
> }
> ```
>
> ❌ **Don't poll MIDI devices too frequently**
> ```cpp
> // BAD: Wasteful, causes UI jank
> startTimer(100);  // 10 times per second
> ```
>
> ✅ **Use reasonable polling rate**
> ```cpp
> // GOOD: Once per second is plenty
> startTimer(1000);
> ```
>
> ❌ **Don't block audio thread with UI updates**
> ```cpp
> // BAD: UI calls in audio callback
> void audioCallback(...)
> {
>     meterComponent->setLevel(level);  // UI call in audio thread!
> }
> ```
>
> ✅ **Use atomics and timer for UI updates**
> ```cpp
> // GOOD: Thread-safe communication
> void audioCallback(...)
> {
>     currentLevel.store(level);  // Atomic write
> }
>
> void timerCallback()
> {
>     float level = currentLevel.load();  // Atomic read
>     meterComponent->setLevel(level);  // UI call in message thread
> }
> ```
>
> ### 13. Performance Tips
>
> 1. **Device Scanning:**
>    - Poll MIDI devices at 1 Hz maximum
>    - Use ChangeListener for immediate detection
>    - Cache device lists to avoid repeated queries
>
> 2. **UI Updates:**
>    - Update input level meter at 60 Hz (16ms)
>    - Use smoothing to reduce visual jitter
>    - Only update visible components
>
> 3. **Settings Persistence:**
>    - Debounce saves (2-second delay)
>    - Only save when values actually change
>    - Use async file operations for large settings
>
> ### 14. User Experience Best Practices
>
> **From professional audio applications:**
> - Provide **immediate visual feedback** (input meters, device lists)
> - **Auto-enable new devices** (users expect plug-and-play)
> - **Remember user preferences** (don't reset on every open)
> - Show **clear device names** (not cryptic identifiers)
> - Provide **test functionality** (test tone, MIDI input indicator)
> - Use **standard keyboard shortcuts** (ESC, TAB, Enter)
> - Add **tooltips** for non-obvious controls
> - Display **sample rate and buffer size** prominently
> - Show **current device status** (active, inactive, error)
>
> ### 15. Output Request
>
> Please implement the audio/MIDI settings system following these patterns. Specifically:
>
> 1. Create SettingsComponent with tabbed interface
> 2. Create AudioMidiWindow with Audio/MIDI tabs
> 3. Implement InputLevelMeterComponent with real-time monitoring
> 4. Create MidiDeviceAutoEnabler for auto-detection
> 5. Create SettingsManager for persistent preferences
> 6. Integrate into existing plugin UI (settings button)
> 7. Test all functionality in standalone mode
> 8. Document any deviations from the reference patterns
>
> **Important:** Follow the exact patterns shown for consistency and proven reliability. Focus on robustness, thread safety, and user experience.

---

## Example Usage

### For an Effect Plugin

```markdown
I'm developing a JUCE effect plugin called "MyDelay". I want to implement audio/MIDI
settings with:

- Settings panel accessible from toolbar button
- Audio device configuration (input, output, sample rate, buffer size)
- MIDI device management with auto-enable for new devices
- Input level meter for monitoring
- Settings persistence across sessions

The plugin is primarily standalone but should gracefully handle plugin mode.

Please implement this system following the patterns in:
plans/audio-midi-settings-prompt.md

Use the Phase 1-5 implementation strategy and all the code patterns provided.
```

### For a Synthesizer Plugin

```markdown
I'm developing a JUCE synthesizer plugin called "MySynth". I need audio/MIDI settings
similar to professional DAWs:

- Quick access via settings button or menu
- Audio device selector with test tone
- MIDI device list with enable/disable toggles
- Auto-detect and enable new MIDI keyboards when plugged in
- Visual input monitoring
- Persistent user preferences

Focus on MIDI functionality since this is an instrument. Use the audio/MIDI settings
template from plans/audio-midi-settings-prompt.md
```

### For a Utility Plugin

```markdown
I have a JUCE utility plugin "MyTool" that needs basic audio/MIDI configuration.

Required features:
- Settings dialog with audio device selection
- Sample rate and buffer size controls
- MIDI device toggles
- Save/cancel functionality

Keep it simple but follow best practices from plans/audio-midi-settings-prompt.md
```

---

## Customization Guide

When using this prompt, customize these sections:

1. **[PLUGIN_NAME]** - Your plugin's name
2. **Tab structure** - Adjust based on your plugin's needs
3. **Settings list** - Your specific settings beyond audio/MIDI
4. **Phase timing** - Adjust based on your schedule
5. **UI framework** - Use JUCE components or custom graphics

---

## Success Metrics

A successful implementation will have:

✅ Clean separation between UI, device management, and audio processing
✅ Thread-safe communication (no race conditions or crashes)
✅ Devices automatically detected when plugged in
✅ Input level meter responding to audio in real-time
✅ Settings persisting correctly across app restarts
✅ Save/Cancel working as expected
✅ No audio dropouts when changing devices
✅ Works in standalone mode (primary target)
✅ Graceful degradation in plugin mode

---

## References for Implementation

### JUCE Documentation
- [AudioDeviceManager Tutorial](https://docs.juce.com/master/tutorial_audio_device_manager.html)
- [MidiInput Class Reference](https://docs.juce.com/master/classMidiInput.html)
- [Audio I/O Tutorial](https://docs.juce.com/master/tutorial_audio_input.html)
- [ApplicationProperties](https://docs.juce.com/master/classApplicationProperties.html)

### Design Patterns
- **Singleton** - Settings management
- **Observer** - Device change notifications (ChangeListener)
- **Strategy** - Different device handling for standalone/plugin
- **Command** - Settings operations with undo/redo capability (optional)

---

## Implementation Notes

### MIDI Auto-Enabler Integration Challenge

**Issue:** JUCE's `StandalonePluginHolder` class is not accessible from standard AudioProcessor or AudioProcessorEditor code during compilation. This prevents initializing the MidiDeviceAutoEnabler from these classes.

**Root Cause:**
- `StandalonePluginHolder` is defined in `juce_audio_plugin_client` module
- This class is only available in standalone builds, not in plugin (AU/VST3) builds
- Conditional compilation (`#if JUCE_STANDALONE_APPLICATION`) doesn't help because the header isn't included

**Solutions:**

**Option 1: Custom Standalone Wrapper (Recommended)**
Create a custom standalone application wrapper that initializes the MIDI auto-enabler:

```cpp
// In your custom standalone main.cpp
class CustomStandaloneFilterWindow : public juce::DocumentWindow
{
public:
    CustomStandaloneFilterWindow()
    {
        // After creating your plugin instance
        if (auto* holder = StandalonePluginHolder::getInstance())
        {
            midiAutoEnabler = std::make_unique<MidiDeviceAutoEnabler>(
                holder->deviceManager
            );
        }
    }

private:
    std::unique_ptr<MidiDeviceAutoEnabler> midiAutoEnabler;
};
```

**Option 2: Separate Standalone Target**
Use CMake to create a separate standalone target with its own main.cpp that has access to the device manager.

**Option 3: Runtime Initialization**
Initialize from a settings window or menu command where you have direct access to the AudioDeviceManager:

```cpp
// In your settings window
void AudioMidiWindow::showWindow(juce::AudioDeviceManager& deviceManager)
{
    // Initialize MIDI auto-enabler when settings window opens
    static std::unique_ptr<MidiDeviceAutoEnabler> midiAutoEnabler;
    if (!midiAutoEnabler)
        midiAutoEnabler = std::make_unique<MidiDeviceAutoEnabler>(deviceManager);
}
```

**Important:** The MidiDeviceAutoEnabler class itself is fully functional and tested. The integration challenge only affects *where* it can be initialized, not *how* it works.

---

**Last Updated:** 2025-10-11
**Version:** 1.0
**Status:** Production-ready template
**Tested With:** Multiple professional JUCE applications
