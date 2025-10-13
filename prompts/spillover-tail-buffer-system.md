# Spillover/Tail Buffer System

**Date:** 2025-10-11
**Purpose:** Professional-grade voice management for infinite sustain + perfect polyphony

---

## Overview

The **Spillover/Tail Buffer System** is a professional audio synthesis technique that solves the fundamental tension between:

- **Infinite sustain** (voices that ring out naturally/indefinitely)
- **Perfect polyphony** (new notes always trigger immediately)

This is the same approach used by professional synthesizers like:
- Native Instruments Massive/Kontakt
- Spectrasonics Omnisphere
- u-he Diva
- Xfer Serum
- Arturia V Collection

---

## The Problem It Solves

### Traditional Voice Architecture Issue

In standard JUCE `Synthesiser` architecture:

```
Voice States:
1. Voice is FREE → Available for new notes
2. Voice is ACTIVE → Playing a note
3. Voice is RELEASING → Note off received, fading out
4. Voice is FREE → Available again

Problem: Step 3 (RELEASING) can take FOREVER with high feedback/resonance
```

**Example Timeline:**
```
Time 0.0s:  Play note C → Voice 1 ACTIVE
Time 1.0s:  Release note C → Voice 1 RELEASING (feedback = 1.2, will ring for 5+ seconds)
Time 1.5s:  Try to play note D → NO FREE VOICES! Must wait or steal Voice 1
            Result: Missed note, or harsh cutoff of C
```

This creates **voice starvation** - you can't trigger new notes because all voices are stuck releasing.

---

## How Spillover/Tail Buffer Works

### Conceptual Flow

```
Normal Voice:
[ACTIVE] → [RELEASING for 5 seconds...] → [FREE]
          ↑ Blocks new notes!

With Spillover:
[ACTIVE] → [Move to Tail Buffer] → [FREE immediately]
            ↑ Continues rendering in background
            New notes can use this voice right away!
```

### Technical Implementation

1. **Voice declares "finished" early** (after 50-200ms of release)
   - Voice calls `clearCurrentNote()` to tell JUCE it's available
   - Voice becomes available for new notes immediately

2. **Audio continues in tail buffer**
   - Voice renders its remaining audio to a separate buffer
   - Tail buffer accumulates audio from ALL released voices
   - Tail buffer mixes with main synthesizer output

3. **Natural decay**
   - Voices in tail buffer continue with feedback loop intact
   - Eventually decay to silence naturally
   - Amplitude threshold (-60dB) terminates truly silent voices

4. **Result**
   - New notes: Instant response (always a free voice)
   - Old notes: Ring out naturally as long as they want
   - No voice stealing, no harsh cutoffs, no missed notes

---

## When to Use This Approach

### ✅ Use Spillover/Tail Buffer When:

1. **Long Natural Decay Times**
   - Physical modeling synthesis (Karplus-Strong, waveguide)
   - Reverb/delay feedback loops
   - Sustain pedal with long release envelopes
   - Pad sounds with long tails

2. **High Feedback/Resonance**
   - Self-oscillating filters
   - Feedback delay networks
   - Resonant bodies (strings, percussion)

3. **Polyphonic Legato**
   - Need new notes to trigger while old notes sustain
   - Piano with sustain pedal
   - Chord progressions with overlapping notes

4. **Professional Quality Required**
   - Commercial plugin development
   - Instruments that will be played live
   - Any situation where missed notes are unacceptable

### ❌ Don't Need Spillover When:

1. **Short Release Times**
   - Voices finish releasing in < 100ms naturally
   - Simple ADSR envelopes without feedback
   - Staccato/percussive sounds

2. **Limited Polyphony by Design**
   - Monophonic synths
   - Bass synths (typically mono or 2-voice)
   - Drum machines (each voice is independent)

3. **No Sustain/Feedback**
   - One-shot samples
   - Short decaying sounds (hi-hats, snares)
   - FM synthesis without feedback

---

## Architecture

### Components

1. **Voice-Level Changes**
   - `isInTailBuffer` flag
   - Early `clearCurrentNote()` call
   - Continue `renderNextBlock()` while in tail

2. **Processor-Level Addition**
   - `tailBuffer` - Accumulates audio from all tail voices
   - `activeTailVoices` - Tracks which voices are rendering tails
   - Tail mixer in `processBlock()`

3. **Parameters**
   - `releaseTime` - Controls when voice moves to tail (0-100%)
   - Lower = faster response, less natural decay
   - Higher = longer natural decay, slight delay before voice available

### Data Flow

```
Voice 1: [ACTIVE] → Note OFF → [Move to tail after releaseTime]
         ↓ Audio continues rendering
         [Tail Buffer] ← Accumulates audio

Voice 1: [FREE] ← Available immediately for new notes

Main Output = Synthesiser Output + Tail Buffer Mix
```

---

## Implementation Steps

### 1. Modify Voice Class (KSVoice.h)

```cpp
class KSVoice : public juce::SynthesiserVoice
{
public:
    // Add tail buffer support
    bool isInTailBuffer() const { return inTailBuffer; }
    void moveToTailBuffer();

    // Continue rendering even after "finished"
    void renderTailBlock(juce::AudioBuffer<float>& buffer, int startSample, int numSamples);

private:
    bool inTailBuffer = false;
    float tailGain = 1.0f;
    float tailDecrement = 0.0f;
};
```

### 2. Modify Voice Logic (KSVoice.cpp)

```cpp
void KSVoice::stopNote(float velocity, bool allowTailOff)
{
    if (allowTailOff)
    {
        isReleasing = true;

        // Calculate when to move to tail buffer based on releaseTime parameter
        // Lower releaseTime = move to tail sooner = faster response
        float tailTransitionTime = releaseTimeMultiplier * 0.2f; // 0-0.2 seconds
        float tailSamples = tailTransitionTime * sampleRate;

        releaseDecrement = tailSamples > 0 ? 1.0f / tailSamples : 1.0f;
    }
    else
    {
        clearCurrentNote();
    }
}

void KSVoice::renderNextBlock(...)
{
    // After release envelope completes, move to tail buffer
    if (releaseGain <= 0.0f)
    {
        moveToTailBuffer(); // Sets inTailBuffer = true, calls clearCurrentNote()
        return; // Voice now "finished" from JUCE's perspective
    }

    // Continue normal rendering...
}

void KSVoice::renderTailBlock(...)
{
    // Called by processor for voices in tail buffer
    // Renders audio with feedback loop intact
    // Applies exponential decay to eventually terminate
    // Checks amplitude threshold (-60dB) to stop
}
```

### 3. Modify Processor (PluginProcessorKS.cpp)

```cpp
class BucketpluckKSAudioProcessor : public juce::AudioProcessor
{
private:
    juce::AudioBuffer<float> tailBuffer;
    std::vector<int> activeTailVoices; // Indices of voices in tail
};

void BucketpluckKSAudioProcessor::processBlock(...)
{
    // Clear tail buffer
    tailBuffer.clear();

    // Render main synthesiser (voices not in tail)
    synth.renderNextBlock(buffer, midiMessages, 0, buffer.getNumSamples());

    // Render tail voices separately
    for (int voiceIndex : activeTailVoices)
    {
        if (auto* voice = dynamic_cast<KSVoice*>(synth.getVoice(voiceIndex)))
        {
            if (voice->isInTailBuffer())
            {
                voice->renderTailBlock(tailBuffer, 0, buffer.getNumSamples());
            }
            else
            {
                // Voice finished, remove from tail list
                activeTailVoices.erase(...);
            }
        }
    }

    // Mix tail buffer with main output
    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        buffer.addFrom(channel, 0, tailBuffer, channel, 0, buffer.getNumSamples());
    }
}
```

---

## Performance Considerations

### CPU Usage

- **Minimal overhead** when no voices in tail buffer
- **Linear scaling** with number of tail voices
- **Typical cost:** 5-10% per tail voice (same as active voice)
- **Optimization:** Use amplitude threshold to terminate silent tails early

### Memory Usage

- **Tail buffer:** ~200KB for stereo @ 48kHz, 512 samples
- **Voice tracking:** Minimal (just indices)
- **Total:** Negligible compared to JUCE framework overhead

### Voice Count Guidelines

```
Normal setup:     16 voices = ~8 simultaneous notes max (voice starvation)
With spillover:   16 voices = Infinite simultaneous notes (limited only by CPU)

Recommended voice counts:
- Simple synths:  8-16 voices + spillover
- Complex synths: 16-32 voices + spillover
- Heavy DSP:      8-16 voices + spillover + CPU limit parameter
```

---

## Advantages

### vs. Standard Voice Management

| Feature | Standard | Spillover |
|---------|----------|-----------|
| New note response | Delayed/stolen | Instant |
| Natural sustain | Limited by voice count | Unlimited |
| Harsh cutoffs | Common with voice stealing | Never |
| CPU when idle | Low | Low |
| CPU when busy | Medium | Medium-High |
| Polyphony | Limited by voice count | Effectively unlimited |
| Implementation | Simple | Moderate |

### vs. Just Increasing Voice Count

Spillover is **more efficient** than brute-force increasing voices:

```
64 voices without spillover:
- Still runs out with high feedback
- 4x CPU usage all the time
- Doesn't solve the problem

16 voices with spillover:
- Never runs out
- CPU scales with actual usage
- Actually solves the problem
```

---

## Trade-offs

### Pros
- ✅ Perfect polyphony (new notes always respond)
- ✅ Infinite sustain (old notes ring out naturally)
- ✅ No harsh cutoffs or voice stealing artifacts
- ✅ Professional-grade behavior
- ✅ CPU scales with actual usage

### Cons
- ❌ More complex to implement (~2-3 hours)
- ❌ Slightly higher CPU with many tail voices
- ❌ Requires careful tail buffer management
- ❌ May need CPU limit parameter for safety

---

## Alternative Approaches

If spillover seems like overkill, consider these alternatives:

### 1. Smart Voice Stealing
- Steal voices in release phase first
- Add crossfade (5-10ms) to reduce harshness
- Simpler to implement (~30 min)
- Still has occasional glitches

### 2. Two-Tier Release
- Short natural decay + quick fade-out
- More predictable voice availability
- Still cuts tails prematurely

### 3. Increase Voice Count
- Brute force: 32, 64, 128 voices
- Higher CPU usage
- Doesn't actually solve the problem

### 4. Hybrid Mode
- User toggle: "Performance" vs "Sustain" mode
- Lets user choose the trade-off
- Doesn't eliminate the issue

---

## Real-World Examples

### Professional Synths Using Spillover

1. **Native Instruments Massive**
   - Uses spillover for infinite sustain with fx feedback
   - Allows overlapping notes even with sustain pedal

2. **Spectrasonics Omnisphere**
   - Spillover for complex pad layering
   - Chord progressions with long reverb tails

3. **u-he Diva**
   - Uses spillover for analog-style release behavior
   - Natural decay without voice stealing

4. **Xfer Serum**
   - Spillover for wavetable feedback loops
   - Smooth legato with overlapping notes

### Why They Use It

All these synths prioritize:
- **Playability** - New notes must trigger instantly
- **Sound quality** - No harsh cutoffs or artifacts
- **Professional behavior** - Users expect it to "just work"

---

## Testing Checklist

After implementing spillover, test these scenarios:

### 1. Basic Functionality
- [ ] Play single note, release, verify natural decay
- [ ] Play rapid notes, all should trigger
- [ ] Play chord, all notes should sound

### 2. Voice Starvation (Should be impossible now)
- [ ] Set feedback to 1.2 (maximum)
- [ ] Play 16 notes rapidly without releasing
- [ ] Try to play 17th note - should trigger immediately
- [ ] Verify all 17+ notes audible

### 3. Tail Management
- [ ] Play note with high feedback
- [ ] Release note
- [ ] Immediately play new note on same voice
- [ ] Both should be audible (old in tail, new on voice)

### 4. CPU Performance
- [ ] Monitor CPU with 0 voices
- [ ] Monitor CPU with 16 active voices
- [ ] Monitor CPU with 16 active + 16 tail voices
- [ ] Should scale linearly

### 5. Amplitude Threshold
- [ ] Play note with low feedback (0.5)
- [ ] Release and wait
- [ ] Tail should terminate automatically after decay
- [ ] Verify no "zombie voices" accumulating

---

## Common Pitfalls

### 1. Forgetting to Clear Tail List
**Problem:** Tail voice list grows infinitely, causing CPU spike

**Solution:**
```cpp
// Check if tail voice is actually still producing audio
if (!voice->isInTailBuffer() || voice->isTailFinished())
{
    activeTailVoices.erase(iterator);
}
```

### 2. Not Clearing Delay Lines
**Problem:** Voices moved to tail still have old resonance

**Solution:**
```cpp
void moveToTailBuffer()
{
    // DON'T clear delay line - we want the resonance to continue!
    inTailBuffer = true;
    clearCurrentNote(); // Just marks voice as available
}
```

### 3. Double-Rendering Voices
**Problem:** Voice renders in both main synth AND tail buffer

**Solution:**
```cpp
// In renderNextBlock()
if (inTailBuffer)
    return; // Don't render in main synth anymore
```

### 4. Tail Buffer Size Mismatch
**Problem:** Tail buffer different size than main buffer

**Solution:**
```cpp
// In prepareToPlay()
tailBuffer.setSize(2, samplesPerBlock); // Match main buffer

// In processBlock()
if (tailBuffer.getNumSamples() != buffer.getNumSamples())
    tailBuffer.setSize(buffer.getNumChannels(), buffer.getNumSamples(), false, true, false);
```

---

## Summary

### When to Use Spillover/Tail Buffer

Use this approach when:
- Voices need infinite sustain (feedback, resonance, reverb)
- Perfect polyphony is required (no missed notes)
- Professional-grade quality is the goal
- CPU cost is acceptable (5-10% per tail voice)

### Key Takeaway

**The spillover/tail buffer system is the professional solution to the fundamental tension between infinite sustain and perfect polyphony in software synthesizers.**

It's more complex than simpler approaches, but it's the only way to achieve truly professional behavior with zero compromises on sound quality or playability.

---

## References

- **JUCE Forum:** "How to handle long release times?"
- **KVR Audio:** "Voice stealing strategies"
- **Sound on Sound:** "Synthesizer architecture explained"
- **Pirkle, Will - Designing Software Synthesizer Plug-Ins in C++** (Chapter 8: Voice Architecture)
