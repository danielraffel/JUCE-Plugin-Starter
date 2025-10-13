# Bucketpluck Modulation Matrix & Automation Specifications

**Status:** Planned (for post-Phase 11 refinement)
**Created:** 2025-10-11

## Overview

This document specifies the implementation of a proper modulation routing system and parameter automation with visual feedback, following industry-standard patterns used in professional audio plugins.

---

## 1. Current State

### ✅ What's Working
- LFOs generate modulation signals (2 LFOs per plugin)
- LFO parameters are accessible (rate, waveform, depth, phase, tempo sync)
- Drift oscillator provides analog-style slow modulation
- Safety limiters and stereo processing functional

### ❌ Current Limitations
- **Hardcoded routing**: LFO1 → delay time, LFO2 → feedback (in FX)
- **No routing matrix**: Can't route any LFO to any parameter
- **No automation feedback**: Knobs don't visually move when automated
- **No modulation feedback**: Knobs don't show LFO modulation visually
- **No user interaction with modulated parameters**: Can't "grab" a modulated knob and have it continue moving

---

## 2. Modulation Matrix Architecture

### 2.1 Routing System

**Recommended Architecture:**

```cpp
class ModulationMatrix {
    enum Destination {
        // List all modulatable parameters
        DELAY_TIME,
        FEEDBACK,
        BBD_STAGES,
        HI_CUT_FREQ,
        DRIVE,
        // ... etc
    };

    struct Routing {
        int sourceId;           // LFO index (0 or 1)
        Destination dest;       // Target parameter
        float amount;          // Modulation depth (-1 to +1)
        bool bipolar;          // Bipolar (-1 to +1) or unipolar (0 to 1)
        bool enabled;          // Is routing active?
    };

    // Core methods
    void setRouting(int lfoId, Destination dest, float amount, bool bipolar = true);
    void clearRouting(Destination dest);
    float getModulation(Destination dest) const;
    float applyModulation(Destination dest, float baseValue, float minValue, float maxValue) const;
};
```

**Key Features:**
1. **One routing per destination**: Each parameter can only be modulated by one LFO at a time
2. **Amount control**: Independent depth control per routing
3. **Bipolar/Unipolar**: Supports both modulation types
4. **Runtime updates**: Can change routings in real-time without audio glitches

### 2.2 Integration with Parameters

**Current approach (problematic):**
```cpp
// Hardcoded in processChannel()
delayMs *= (1.0f + lfo1Value * lfo1Depth * 0.5f);
```

**Proper approach:**
```cpp
// In processBlock(), before audio processing:
modulationMatrix.processBlock(sampleRate, buffer.getNumSamples(), currentBPM);

// When reading parameters:
float baseDelayTime = parameters.getRawParameterValue("delayTimeMs")->load();
float modulatedDelayTime = modulationMatrix.applyModulation(
    ModulationMatrix::DELAY_TIME,
    baseDelayTime,
    2.5f,   // min
    50.0f   // max
);
```

**Benefits:**
- Clean separation of concerns
- Easy to add/remove modulation destinations
- Consistent modulation behavior across all parameters
- Can be serialized/saved with presets

---

## 3. Parameter Automation with Visual Feedback

### 3.1 Requirements

For professional parameter automation with visual feedback, we need:

1. **Automation playback**: Parameter values from DAW automation are reflected in audio
2. **Visual feedback**: Knobs visually rotate/move when automated or modulated
3. **Touch sensitivity**: When user touches an automated knob:
   - Automation is temporarily overridden
   - When released, automation resumes
4. **Modulation visualization**:
   - Show modulation range (e.g., ring around knob showing min/max of LFO sweep)
   - Knob position shows current modulated value, not just base value

### 3.2 UI Component Architecture

**Knob Component Requirements:**

```cpp
class ModulatableKnob : public juce::Slider {
public:
    // Parameter binding
    void bindToParameter(juce::AudioProcessorValueTreeState& apvts,
                        const juce::String& parameterID);

    // Modulation display
    void setModulationAmount(float amount);           // -1 to +1
    void setModulationBipolar(bool isBipolar);
    void setCurrentModulatedValue(float modulatedValue);

    // Visual feedback
    void paint(juce::Graphics& g) override;
    // Draw:
    // 1. Base knob position (from parameter)
    // 2. Modulation range (arc showing min/max sweep)
    // 3. Current modulated position (brighter indicator)

    // Interaction
    void mouseDown(const juce::MouseEvent& e) override;
    // On touch: set automation override flag

    void mouseUp(const juce::MouseEvent& e) override;
    // On release: clear automation override flag

private:
    juce::RangedAudioParameter* boundParameter = nullptr;
    float modulationAmount = 0.0f;
    float currentModulated Value = 0.0f;
    bool isBipolar = true;
};
```

### 3.3 Timer-Based Updates

**Recommended Implementation:**

```cpp
class PluginEditor : public juce::AudioProcessorEditor,
                     private juce::Timer {
public:
    PluginEditor(AudioProcessor& p) : processor(p) {
        startTimerHz(60);  // 60 FPS updates
    }

private:
    void timerCallback() override {
        // Update all knobs with current modulated values
        for (auto& knob : modulatableKnobs) {
            auto baseValue = knob->boundParameter->getValue();
            auto modAmount = processor.getModulationAmount(knob->destination);
            knob->setModulationAmount(modAmount);

            // Get actual modulated value from processor
            auto modulatedValue = processor.getModulatedValue(knob->destination);
            knob->setCurrentModulatedValue(modulatedValue);
        }

        repaint();  // Trigger visual update
    }

    std::vector<std::unique_ptr<ModulatableKnob>> modulatableKnobs;
};
```

**Performance Considerations:**
- Only update visible knobs (skip if editor is minimized)
- Use dirty flags to avoid unnecessary repaints
- Cache modulation calculations per block, not per sample

---

## 4. Implementation Strategy

### Phase 1: Modulation Matrix Core (1-2 days)

1. **Create ModulationMatrix class** in delay_core/
   - Implement the routing architecture described in section 2.1
   - Define all Destination enum values for Bucketpluck parameters
   - Implement setRouting(), getModulation(), applyModulation()

2. **Update both processors**:
   - Replace hardcoded LFO modulation with matrix
   - Add matrix.processBlock() calls
   - Update all parameter reads to use applyModulation()

3. **Test audio functionality**:
   - Verify modulation still works
   - Test edge cases (parameter limits, multiple routings)
   - Ensure no audio glitches

### Phase 2: Modulation UI (2-3 days)

1. **Create ModulatableKnob component**:
   - Extend juce::Slider
   - Add modulation visualization
   - Implement touch sensitivity

2. **Update plugin editors**:
   - Replace generic knobs with ModulatableKnobs
   - Add timer callback for visual updates
   - Bind knobs to modulation matrix

3. **Test UI behavior**:
   - Verify knobs rotate with automation
   - Test modulation range display
   - Validate touch override behavior

### Phase 3: Modulation Routing UI (3-4 days)

1. **Create ModulationSettingsPanel**:
   - Matrix view showing all routings
   - Drag-and-drop routing creation
   - Amount/bipolar controls per routing
   - LFO visualization (waveform display)

2. **Integration**:
   - Add MOD button to main UI
   - Show/hide modulation panel
   - Save/load routing with presets

3. **Polish**:
   - Animations for routing changes
   - Visual feedback when routing is active
   - Tooltips and help text

---

## 5. User Experience Scenarios

### Scenario 1: Setting Up LFO Modulation

**Current (hardcoded):**
1. Set LFO1 rate to 2Hz
2. Set LFO1 depth to 50%
3. Delay time modulates automatically
4. **Problem**: Can't modulate other parameters

**Proposed (with matrix):**
1. Set LFO1 rate to 2Hz
2. Click MOD button → Opens routing panel
3. Drag LFO1 output to "Delay Time" destination
4. Adjust depth slider → 50%
5. **Result**: Delay time modulates, visual ring shows modulation range on knob
6. Can add more routings: LFO1 → Hi Cut, LFO1 → Drive, etc.

### Scenario 2: DAW Automation

**Current (no visual feedback):**
1. Automate delay time in Logic Pro
2. Play back → audio reflects automation
3. **Problem**: Knob doesn't move

**Proposed:**
1. Automate delay time in Logic Pro
2. Play back → audio reflects automation
3. **Knob rotates in sync with automation**
4. User can see exact automated value at any time
5. Touching knob temporarily overrides automation

### Scenario 3: Combined Automation + Modulation

**Current:**
1. Automate feedback to sweep 0% → 100%
2. LFO2 modulates feedback ±30%
3. **Problem**: Hard to visualize combined effect

**Proposed:**
1. Automate feedback to sweep 0% → 100%
2. LFO2 modulates feedback ±30%
3. **Knob shows:**
   - Gray arc: automation range (0% → 100%)
   - Blue ring: LFO modulation range (±30% from automated value)
   - Bright indicator: current combined value
4. User understands exactly what's happening

---

## 6. Technical Challenges & Solutions

### Challenge 1: Thread Safety

**Problem:** UI thread reads modulation values, audio thread writes them

**Solution:**
```cpp
class ModulationMatrix {
private:
    // Use atomic for simple values
    std::atomic<float> cachedModulationValues[NUM_DESTINATIONS];

public:
    // Audio thread: update cache after processing
    void processBlock(...) {
        // ... process LFOs ...
        for (int i = 0; i < NUM_DESTINATIONS; ++i) {
            cachedModulationValues[i].store(getModulation((Destination)i));
        }
    }

    // UI thread: read from cache (no locks needed)
    float getCachedModulation(Destination dest) const {
        return cachedModulationValues[dest].load();
    }
};
```

### Challenge 2: Parameter Value Mapping

**Problem:** Parameters have different ranges, need consistent modulation

**Solution:**
```cpp
float applyModulation(Destination dest, float baseValue,
                     float minValue, float maxValue) const {
    float modulation = getModulation(dest);  // -1 to +1 or 0 to 1
    float range = maxValue - minValue;

    // Apply modulation relative to range
    float modulated = baseValue + (modulation * range);

    // Clamp to valid range
    return juce::jlimit(minValue, maxValue, modulated);
}
```

### Challenge 3: Automation Override

**Problem:** Need to temporarily disable automation when user touches knob

**Solution:**
```cpp
// In AudioProcessor
class BucketpluckFXAudioProcessor {
private:
    std::atomic<bool> parameterOverrides[NUM_PARAMETERS];

public:
    void setParameterOverride(const juce::String& paramID, bool override) {
        // Set flag when user touches parameter
        int index = getParameterIndex(paramID);
        parameterOverrides[index] = override;
    }

    void processBlock(...) {
        for (auto& param : parameters) {
            if (!parameterOverrides[param.index]) {
                // Only apply automation/modulation if not overridden
                float value = param.getValue();
                value = modulationMatrix.applyModulation(param.dest, value, ...);
                // Use modulated value
            } else {
                // Use raw user input value
            }
        }
    }
};
```

---

## 7. Modulation Destinations

### BucketpluckFX Modulatable Parameters

**Core Delay:**
- Delay Time (2.5-50ms)
- Feedback (0-120%)
- Mix (0-100%)

**BBD Character:**
- BBD Stages (512/1024) - discrete stepping
- Noise Amount (0-100%)

**Filters:**
- Hi Cut Frequency (1kHz-22kHz)
- Low Cut On/Off - not typically modulated

**Saturation:**
- Drive (0-100%)
- Character (0-100%)
- Grit (0-100%)

**Stereo:**
- Stereo Width (0-200%)
- Stereo Mode - discrete, not typically modulated

**Levels:**
- Input Level (0-100%)
- Dry/Wet Balance (0-100%)

### BucketpluckKS Modulatable Parameters

**Voice:**
- Feedback (0-120%)
- Excitation Length (0.5-10ms)

**BBD Character:**
- BBD Stages (512/1024)
- Noise Amount (0-100%)

**Filters:**
- Hi Cut Frequency (1kHz-22kHz)

**Saturation:**
- Drive (0-100%)
- Character (0-100%)

**Synthesis:**
- Excitation Type - discrete
- Velocity Curve - discrete
- Glide Time (0-1000ms)

**Note:** Some parameters (like polyphony mode, pitch bend range) are typically not modulated

---

## 8. Preset Integration

### Routing Serialization

**Save format (JSON):**
```json
{
  "modulation_routings": [
    {
      "source": 0,              // LFO1
      "destination": "delay_time",
      "amount": 0.5,
      "bipolar": true,
      "enabled": true
    },
    {
      "source": 1,              // LFO2
      "destination": "feedback",
      "amount": 0.3,
      "bipolar": true,
      "enabled": true
    }
  ],
  "lfo1": {
    "rate": 2.0,
    "waveform": "sine",
    "depth": 50.0,
    "phase": 0.0,
    "tempo_sync": false
  },
  "lfo2": {
    "rate": 4.0,
    "waveform": "triangle",
    "depth": 30.0,
    "phase": 90.0,
    "tempo_sync": false
  }
}
```

**JUCE State Storage:**
```cpp
void saveModulationState(juce::ValueTree& tree) const {
    auto modTree = tree.getOrCreateChildWithName("Modulation", nullptr);
    modulationMatrix.saveToValueTree(modTree);
}

void loadModulationState(const juce::ValueTree& tree) {
    auto modTree = tree.getChildWithName("Modulation");
    if (modTree.isValid()) {
        modulationMatrix.loadFromValueTree(modTree);
    }
}
```

---

## 9. Testing Plan

### Unit Tests

1. **ModulationMatrix Tests:**
   - Test routing add/remove/update
   - Test modulation calculation accuracy
   - Test parameter range clamping
   - Test bipolar vs unipolar modes

2. **Parameter Tests:**
   - Test automation values are respected
   - Test modulation is applied correctly
   - Test combined automation + modulation

3. **Thread Safety Tests:**
   - Stress test with rapid routing changes
   - Verify no audio glitches during UI updates
   - Test parameter override mechanism

### Integration Tests

1. **DAW Automation:**
   - Test in Logic Pro, Ableton Live, Reaper
   - Verify knob movement matches automation
   - Test touch override behavior

2. **Preset Recall:**
   - Save preset with routings → recall → verify identical
   - Test routing state persistence across DAW sessions

3. **Performance:**
   - Measure CPU impact of visual updates
   - Verify no audio dropouts with 60 FPS UI updates
   - Test with maximum modulation routings

---

## 10. Future Enhancements

### Modulation Sources (Beyond LFOs)

Could add:
- **Envelope Followers**: Modulate based on input signal level
- **MIDI CC**: Direct MIDI CC to parameter mapping
- **Expression Pedal**: CV-style control
- **Random**: Per-block random modulation
- **Sequencer**: Step-based modulation

### Advanced Routing

- **Modulation depth modulation**: Use LFO2 to modulate LFO1's depth
- **Multi-source**: Allow multiple LFOs to modulate one parameter (summed)
- **Modulation curves**: Apply curves (exponential, logarithmic) to modulation
- **Side-chain**: Modulate based on external audio input

### UI Enhancements

- **Modulation learn**: Click "Learn" → move any knob → auto-creates routing
- **Preset modulation templates**: "Vibrato", "Wobble", "Rhythmic Pump"
- **Waveform editor**: Draw custom LFO waveforms
- **Modulation meters**: Real-time visualization of all active modulations

---

## 11. References

### JUCE Documentation
- AudioProcessorValueTreeState - Parameter management
- AudioProcessorValueTreeState::Listener - Automation tracking
- Component::mouseDown/mouseUp - Touch sensitivity
- Timer - UI update mechanism

### Industry Standards
- **Serum** (Xfer Records) - Gold standard for modulation routing UI
- **Vital** (Matt Tytel) - Open-source, excellent modulation visualization
- **Bitwig Studio** - Modulation system with visual feedback
- **Ableton Live** - Automation lanes and modulation mapping

---

## 12. Success Criteria

This modulation system will be considered complete when:

✅ **Functionality:**
1. Any LFO can be routed to any modulatable parameter
2. Modulation depth is independently controllable per routing
3. DAW automation works correctly and combines with modulation
4. No audio glitches or dropouts from modulation processing

✅ **User Experience:**
5. Knobs visually rotate/move when automated
6. Knobs show modulation range and current position
7. Touching an automated knob temporarily overrides automation
8. Modulation routing is intuitive (drag-and-drop or similar)

✅ **Technical:**
9. Thread-safe (no crashes or race conditions)
10. Performant (< 5% CPU for visual updates @ 60 FPS)
11. Preset-compatible (routings save/load correctly)
12. Works in all major DAWs (Logic, Ableton, Reaper)

---

**Document Status:** Specification Complete
**Implementation Status:** Pending (post-Phase 11)
**Est. Implementation Time:** 6-9 days (Phases 1-3)
**Priority:** High (critical for professional plugin usability)
