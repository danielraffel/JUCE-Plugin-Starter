#pragma once

#include "PluginProcessor.h"
#include <juce_audio_processors/juce_audio_processors.h>

//==============================================================================
/**
*/
class CLASS_NAME_PLACEHOLDERAudioProcessorEditor : public juce::AudioProcessorEditor
{
public:
    explicit CLASS_NAME_PLACEHOLDERAudioProcessorEditor (CLASS_NAME_PLACEHOLDERAudioProcessor&);
    ~CLASS_NAME_PLACEHOLDERAudioProcessorEditor() override;

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    CLASS_NAME_PLACEHOLDERAudioProcessor& processorRef;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (CLASS_NAME_PLACEHOLDERAudioProcessorEditor)
};
