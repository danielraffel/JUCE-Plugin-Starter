#pragma once

#include "PluginProcessor.h"
#include <juce_audio_processors/juce_audio_processors.h>
#include <visage/app.h>

class CLASS_NAME_PLACEHOLDERAudioProcessorEditor : public juce::AudioProcessorEditor,
                                                    private juce::Timer
{
public:
    explicit CLASS_NAME_PLACEHOLDERAudioProcessorEditor (CLASS_NAME_PLACEHOLDERAudioProcessor&);
    ~CLASS_NAME_PLACEHOLDERAudioProcessorEditor() override;

    void resized() override;

private:
    void timerCallback() override;
    void createVisageWindow();

    CLASS_NAME_PLACEHOLDERAudioProcessor& processorRef;
    std::unique_ptr<visage::ApplicationWindow> visageApp;
    bool windowCreated = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (CLASS_NAME_PLACEHOLDERAudioProcessorEditor)
};
