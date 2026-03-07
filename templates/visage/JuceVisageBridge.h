#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include <visage_app/application_window.h>
#include <visage_widgets/frame.h>

/**
 * JuceVisageBridge — Embeds Visage GPU rendering inside a JUCE component.
 *
 * Handles: window creation, mouse/keyboard event routing, focus management,
 * clipboard integration, and cursor style mapping.
 *
 * On iOS, mouse event forwarding is skipped — Visage's VisageMetalView
 * handles touch events natively.
 */
class JuceVisageBridge : public juce::Component,
                         public juce::Timer,
                         public juce::ComponentListener
{
public:
    JuceVisageBridge();
    ~JuceVisageBridge() override;

    void setRootFrame (visage::Frame* frame);
    void shutdownRendering();

    // juce::Component
    void paint (juce::Graphics& g) override;
    void resized() override;
    void visibilityChanged() override;
    bool keyPressed (const juce::KeyPress& key) override;

    // juce::Timer
    void timerCallback() override;

#if !JUCE_IOS
    // Mouse events (desktop only — iOS uses native touch via VisageMetalView)
    void mouseDown (const juce::MouseEvent& e) override;
    void mouseUp (const juce::MouseEvent& e) override;
    void mouseDrag (const juce::MouseEvent& e) override;
    void mouseMove (const juce::MouseEvent& e) override;
    void mouseWheelMove (const juce::MouseEvent& e,
                         const juce::MouseWheelDetails& wheel) override;
#endif

private:
    void createEmbeddedWindow();
    void setFocusedChild (visage::Frame* child);

    static int convertModifiers (const juce::ModifierKeys& mods);
    static visage::KeyCode convertKeyCode (const juce::KeyPress& key);

#if !JUCE_IOS
    visage::MouseEvent convertMouseEvent (const juce::MouseEvent& e) const;
    visage::Frame* mouseDownFrame_ = nullptr;
    visage::Frame* hoverFrame_ = nullptr;
#endif

    std::unique_ptr<visage::ApplicationWindow> visageWindow;
    visage::Frame* rootFrame_ = nullptr;
    visage::Frame* focusedChild_ = nullptr;
    visage::FrameEventHandler eventHandler_;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (JuceVisageBridge)
};
