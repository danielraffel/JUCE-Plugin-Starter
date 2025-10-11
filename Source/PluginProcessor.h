#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

//==============================================================================
/**
*/
class CLASS_NAME_PLACEHOLDERAudioProcessor : public juce::AudioProcessor
{
public:
    CLASS_NAME_PLACEHOLDERAudioProcessor();
    ~CLASS_NAME_PLACEHOLDERAudioProcessor() override;

    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;

    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;

    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;

    const juce::String getName() const override;

    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;

    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram (int index) override;
    const juce::String getProgramName (int index) override;
    void changeProgramName (int index, const juce::String& newName) override;

    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    //==============================================================================
    // Path helpers - macOS Application Support paths (no permission prompts)
    static juce::File getApplicationSupportPath();
    static juce::File getSamplesPath();
    static juce::File getPresetsPath();
    static juce::File getUserDataPath();
    static juce::File getLogsPath();

private:
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (CLASS_NAME_PLACEHOLDERAudioProcessor)
};
