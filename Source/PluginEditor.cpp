#include "PluginProcessor.h"
#include "PluginEditor.h"

//==============================================================================
CLASS_NAME_PLACEHOLDERAudioProcessorEditor::CLASS_NAME_PLACEHOLDERAudioProcessorEditor (CLASS_NAME_PLACEHOLDERAudioProcessor& p)
    : AudioProcessorEditor (&p), processorRef (p)
{
    juce::ignoreUnused (processorRef);
    setSize (400, 300);
}

CLASS_NAME_PLACEHOLDERAudioProcessorEditor::~CLASS_NAME_PLACEHOLDERAudioProcessorEditor()
{
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::paint (juce::Graphics& g)
{
    g.fillAll (getLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId));

    g.setColour (juce::Colours::white);
    g.setFont (15.0f);
    g.drawFittedText ("Hello World!", getLocalBounds(), juce::Justification::centred, 1);
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::resized()
{
    // This is where you'd lay out your UI components
}
