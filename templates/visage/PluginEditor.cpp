#include "PluginProcessor.h"
#include "PluginEditor.h"

CLASS_NAME_PLACEHOLDERAudioProcessorEditor::CLASS_NAME_PLACEHOLDERAudioProcessorEditor (CLASS_NAME_PLACEHOLDERAudioProcessor& p)
    : AudioProcessorEditor (&p), processorRef (p)
{
    juce::ignoreUnused (processorRef);
    setSize (800, 600);
    startTimer (10); // Defer UI creation until bounds are valid
}

CLASS_NAME_PLACEHOLDERAudioProcessorEditor::~CLASS_NAME_PLACEHOLDERAudioProcessorEditor()
{
    stopTimer();

    if (bridge)
        bridge->shutdownRendering();

    if (rootFrame)
        rootFrame->removeAllChildren();

    rootFrame.reset();
    bridge.reset();
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::timerCallback()
{
    if (!rootFrame && getLocalBounds().getWidth() > 0)
    {
        stopTimer();
        createVisageUI();
        startTimer (33); // 30fps polling for processor state updates
        return;
    }

    // Use this timer to poll processor state and update UI
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::createVisageUI()
{
    rootFrame = std::make_unique<visage::Frame>();

    // --- Add your Visage child frames here ---
    // Example:
    // auto myPanel = rootFrame->addChild<visage::Frame>();
    // Do NOT set child bounds here — set them in layoutChildren() instead
    // (DPI may still be 1.0 at this point)

    // Native title bar for standalone mode
    if (auto* window = findParentComponentOfClass<juce::DocumentWindow>())
    {
        window->setUsingNativeTitleBar (true);
        setSize (800, 600); // Must re-assert after title bar switch
    }

    bridge = std::make_unique<JuceVisageBridge>();
    addAndMakeVisible (*bridge);
    bridge->setRootFrame (rootFrame.get());
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::resized()
{
    if (bridge)
        bridge->setBounds (getLocalBounds());

    if (rootFrame)
    {
        rootFrame->setBounds (0, 0, getWidth(), getHeight());
        layoutChildren();
    }
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::layoutChildren()
{
    // Set all child frame bounds here (called from resized, after DPI is correct).
    // Example:
    // if (myPanel) myPanel->setBounds(20, 40, 220, 210);
}
