#include "PluginProcessor.h"
#include "PluginEditor.h"

CLASS_NAME_PLACEHOLDERAudioProcessorEditor::CLASS_NAME_PLACEHOLDERAudioProcessorEditor (
    CLASS_NAME_PLACEHOLDERAudioProcessor& p)
    : AudioProcessorEditor (&p), processorRef (p)
{
    juce::ignoreUnused (processorRef);
    setSize (400, 300);
    startTimerHz (10);  // Poll until native peer is available
}

CLASS_NAME_PLACEHOLDERAudioProcessorEditor::~CLASS_NAME_PLACEHOLDERAudioProcessorEditor()
{
    stopTimer();
    if (visageApp)
    {
        visageApp->close();
        visageApp.reset();
    }
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::timerCallback()
{
    if (! windowCreated && isShowing() && getPeer() != nullptr)
    {
        createVisageWindow();
        stopTimer();
    }
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::createVisageWindow()
{
    visageApp = std::make_unique<visage::ApplicationWindow>();

    visageApp->onDraw() = [this] (visage::Canvas& canvas) {
        canvas.setColor (0xff1a1a2e);
        canvas.fill (0, 0, visageApp->width(), visageApp->height());

        float cx = visageApp->width() * 0.5f;
        float cy = visageApp->height() * 0.5f;
        float r = std::min (visageApp->width(), visageApp->height()) * 0.15f;
        canvas.setColor (0xff00d4aa);
        canvas.circle (cx - r, cy - r, r * 2.0f);
    };

    auto* peer = getPeer();
    void* nativeHandle = peer->getNativeHandle();
    auto bounds = getLocalBounds();

    visageApp->show (bounds.getWidth(), bounds.getHeight(), nativeHandle);
    windowCreated = true;
}

void CLASS_NAME_PLACEHOLDERAudioProcessorEditor::resized()
{
    if (visageApp && windowCreated)
    {
        auto bounds = getLocalBounds();
        visageApp->setWindowDimensions (bounds.getWidth(), bounds.getHeight());
    }
}
