#include "JuceVisageBridge.h"

JuceVisageBridge::JuceVisageBridge()
{
    setOpaque (true);
    setWantsKeyboardFocus (false);
    setInterceptsMouseClicks (true, true);
    setMouseClickGrabsKeyboardFocus (false);

    // Configure Visage event handler callbacks
    eventHandler_.request_keyboard_focus = [this] (visage::Frame* child) {
        setFocusedChild (child);
    };

    eventHandler_.read_clipboard_text = []() -> std::string {
        return juce::SystemClipboard::getTextFromClipboard().toStdString();
    };

    eventHandler_.set_clipboard_text = [] (const std::string& text) {
        juce::SystemClipboard::copyTextToClipboard (juce::String (text));
    };

    eventHandler_.set_cursor_style = [this] (visage::MouseCursor cursor) {
        switch (cursor)
        {
            case visage::MouseCursor::Arrow:
                setMouseCursor (juce::MouseCursor::NormalCursor);
                break;
            case visage::MouseCursor::IBeam:
                setMouseCursor (juce::MouseCursor::IBeamCursor);
                break;
            case visage::MouseCursor::Crosshair:
                setMouseCursor (juce::MouseCursor::CrosshairCursor);
                break;
            case visage::MouseCursor::PointingHand:
                setMouseCursor (juce::MouseCursor::PointingHandCursor);
                break;
            case visage::MouseCursor::LeftRight:
                setMouseCursor (juce::MouseCursor::LeftRightResizeCursor);
                break;
            case visage::MouseCursor::UpDown:
                setMouseCursor (juce::MouseCursor::UpDownResizeCursor);
                break;
            default:
                setMouseCursor (juce::MouseCursor::NormalCursor);
                break;
        }
    };

    eventHandler_.request_redraw = [this] (visage::Frame*) {
        repaint();
    };

    startTimer (16); // ~60fps window creation check
}

JuceVisageBridge::~JuceVisageBridge()
{
    stopTimer();
    shutdownRendering();
}

void JuceVisageBridge::setRootFrame (visage::Frame* frame)
{
    rootFrame_ = frame;

    if (rootFrame_)
        rootFrame_->setEventHandler (&eventHandler_);
}

void JuceVisageBridge::shutdownRendering()
{
    if (visageWindow)
    {
        if (rootFrame_)
            visageWindow->removeChild (rootFrame_);

        visageWindow.reset();
    }
}

void JuceVisageBridge::paint (juce::Graphics&)
{
    // Visage handles all rendering via GPU (Metal/D3D11/Vulkan) — nothing to paint
}

void JuceVisageBridge::resized()
{
    if (visageWindow && rootFrame_)
    {
        auto bounds = getLocalBounds();
        visageWindow->setBounds (0, 0, bounds.getWidth(), bounds.getHeight());
        rootFrame_->setBounds (0, 0, bounds.getWidth(), bounds.getHeight());
    }
}

void JuceVisageBridge::visibilityChanged()
{
    if (isShowing() && !visageWindow)
        createEmbeddedWindow();
}

void JuceVisageBridge::timerCallback()
{
    if (!visageWindow && isShowing() && getPeer())
    {
        createEmbeddedWindow();

        if (visageWindow)
            stopTimer();
    }
}

void JuceVisageBridge::createEmbeddedWindow()
{
    if (visageWindow || !isShowing() || !getPeer())
        return;

    auto* peer = getPeer();
    void* parentHandle = peer->getNativeHandle();
    auto bounds = getLocalBounds();

    if (bounds.getWidth() <= 0 || bounds.getHeight() <= 0)
        return;

    visageWindow = std::make_unique<visage::ApplicationWindow>();

    float scale = juce::Desktop::getInstance()
                      .getDisplays()
                      .getDisplayForPoint (getScreenPosition())
                      ->scale;
    visageWindow->setDpiScale (scale);

    int w = bounds.getWidth();
    int h = bounds.getHeight();
    visageWindow->show (
        visage::Dimension::logicalPixels (w),
        visage::Dimension::logicalPixels (h),
        parentHandle
    );
    visageWindow->setBounds (0, 0, w, h);

    if (rootFrame_)
    {
        rootFrame_->init();
        visageWindow->addChild (rootFrame_);
        rootFrame_->setBounds (0, 0, w, h);
    }

    // Flush first frame to prevent flash on window creation
    visageWindow->drawWindow();
}

// --- Focus management ---

void JuceVisageBridge::setFocusedChild (visage::Frame* child)
{
    if (child)
    {
        setWantsKeyboardFocus (true);
        grabKeyboardFocus();
    }
    else
    {
        setWantsKeyboardFocus (false);
        giveAwayKeyboardFocus();
    }

    focusedChild_ = child;
}

// --- Keyboard ---

int JuceVisageBridge::convertModifiers (const juce::ModifierKeys& mods)
{
    int result = 0;

    if (mods.isShiftDown())
        result |= visage::kModifierShift;
    if (mods.isAltDown())
        result |= visage::kModifierAlt;

#if JUCE_MAC || JUCE_IOS
    if (mods.isCommandDown())
        result |= visage::kModifierCmd;
    if (mods.isCtrlDown())
        result |= visage::kModifierMacCtrl;
#else
    if (mods.isCtrlDown())
        result |= visage::kModifierRegCtrl;
#endif

    return result;
}

visage::KeyCode JuceVisageBridge::convertKeyCode (const juce::KeyPress& key)
{
    int keyCode = key.getKeyCode();
    bool hasModifier = key.getModifiers().isCommandDown() || key.getModifiers().isCtrlDown();

    if (hasModifier)
    {
        switch (keyCode)
        {
            case 'A': return visage::KeyCode::A;
            case 'C': return visage::KeyCode::C;
            case 'V': return visage::KeyCode::V;
            case 'X': return visage::KeyCode::X;
            case 'Z': return visage::KeyCode::Z;
            default:  return static_cast<visage::KeyCode> (keyCode);
        }
    }

    auto ch = key.getTextCharacter();
    if (ch > 0 && ch < 127)
        return static_cast<visage::KeyCode> (ch);

    return static_cast<visage::KeyCode> (keyCode);
}

bool JuceVisageBridge::keyPressed (const juce::KeyPress& key)
{
    if (!rootFrame_)
        return false;

    visage::KeyEvent visEvent;
    visEvent.key_code = convertKeyCode (key);
    visEvent.modifiers = convertModifiers (key.getModifiers());

    if (focusedChild_)
    {
        if (focusedChild_->keyPress (visEvent))
            return true;
    }

    return rootFrame_->keyPress (visEvent);
}

// --- Mouse events (desktop only — iOS uses native touch) ---

#if !JUCE_IOS

visage::MouseEvent JuceVisageBridge::convertMouseEvent (const juce::MouseEvent& e) const
{
    visage::MouseEvent visEvent;
    visEvent.window_position = { static_cast<float> (e.x), static_cast<float> (e.y) };
    visEvent.position = visEvent.window_position;
    visEvent.modifiers = convertModifiers (e.mods);

    if (e.mods.isLeftButtonDown())
        visEvent.button_state |= visage::kMouseButtonLeft;
    if (e.mods.isRightButtonDown())
        visEvent.button_state |= visage::kMouseButtonRight;
    if (e.mods.isMiddleButtonDown())
        visEvent.button_state |= visage::kMouseButtonMiddle;

    return visEvent;
}

void JuceVisageBridge::mouseDown (const juce::MouseEvent& e)
{
    if (!rootFrame_)
        return;

    auto visEvent = convertMouseEvent (e);
    mouseDownFrame_ = rootFrame_->frameAtPoint (visEvent.window_position);

    if (mouseDownFrame_)
    {
        visEvent.position = visEvent.window_position - mouseDownFrame_->positionInWindow();
        mouseDownFrame_->mouseDown (visEvent);
    }
}

void JuceVisageBridge::mouseUp (const juce::MouseEvent& e)
{
    if (mouseDownFrame_)
    {
        auto visEvent = convertMouseEvent (e);
        visEvent.position = visEvent.window_position - mouseDownFrame_->positionInWindow();
        mouseDownFrame_->mouseUp (visEvent);
        mouseDownFrame_ = nullptr;
    }
}

void JuceVisageBridge::mouseDrag (const juce::MouseEvent& e)
{
    if (mouseDownFrame_)
    {
        auto visEvent = convertMouseEvent (e);
        visEvent.position = visEvent.window_position - mouseDownFrame_->positionInWindow();
        mouseDownFrame_->mouseDrag (visEvent);
    }
}

void JuceVisageBridge::mouseMove (const juce::MouseEvent& e)
{
    if (!rootFrame_)
        return;

    auto visEvent = convertMouseEvent (e);
    auto* newHover = rootFrame_->frameAtPoint (visEvent.window_position);

    if (newHover != hoverFrame_)
    {
        if (hoverFrame_)
        {
            auto exitEvent = visEvent;
            exitEvent.position = exitEvent.window_position - hoverFrame_->positionInWindow();
            hoverFrame_->mouseExit (exitEvent);
        }

        hoverFrame_ = newHover;

        if (hoverFrame_)
        {
            auto enterEvent = visEvent;
            enterEvent.position = enterEvent.window_position - hoverFrame_->positionInWindow();
            hoverFrame_->mouseEnter (enterEvent);
        }
    }

    if (hoverFrame_)
    {
        visEvent.position = visEvent.window_position - hoverFrame_->positionInWindow();
        hoverFrame_->mouseMove (visEvent);
    }
}

void JuceVisageBridge::mouseWheelMove (const juce::MouseEvent& e,
                                       const juce::MouseWheelDetails& wheel)
{
    if (!rootFrame_)
        return;

    auto visEvent = convertMouseEvent (e);
    auto* target = rootFrame_->frameAtPoint (visEvent.window_position);

    if (target)
    {
        visEvent.position = visEvent.window_position - target->positionInWindow();
        visEvent.wheel_delta_x = wheel.deltaX;
        visEvent.wheel_delta_y = wheel.deltaY;
        target->mouseWheel (visEvent);
    }
}

#endif // !JUCE_IOS
