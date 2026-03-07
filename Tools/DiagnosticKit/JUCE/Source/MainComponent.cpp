#include "MainComponent.h"

MainComponent::MainComponent (const AppConfig& config)
    : juce::Thread ("DiagnosticWorker"),
      config_ (config),
      collector_ (config),
      uploader_ (config)
{
    // Title
    titleLabel_.setText (config_.appName, juce::dontSendNotification);
    titleLabel_.setFont (juce::FontOptions (22.0f, juce::Font::bold));
    titleLabel_.setJustificationType (juce::Justification::centred);
    addAndMakeVisible (titleLabel_);

    // Subtitle
    subtitleLabel_.setText ("Submit a diagnostic report to help us troubleshoot issues",
                           juce::dontSendNotification);
    subtitleLabel_.setJustificationType (juce::Justification::centred);
    subtitleLabel_.setColour (juce::Label::textColourId, juce::Colours::grey);
    addAndMakeVisible (subtitleLabel_);

    // Status label (shown during collection/submission)
    statusLabel_.setJustificationType (juce::Justification::centred);
    statusLabel_.setFont (juce::FontOptions (16.0f));
    addAndMakeVisible (statusLabel_);

    // Feedback
    if (config_.allowUserFeedback)
    {
        feedbackLabel_.setText ("Describe the issue (optional):", juce::dontSendNotification);
        feedbackLabel_.setFont (juce::FontOptions (14.0f));
        addAndMakeVisible (feedbackLabel_);

        feedbackEditor_.setMultiLine (true);
        feedbackEditor_.setReturnKeyStartsNewLine (true);
        addAndMakeVisible (feedbackEditor_);
    }

    // Buttons
    submitButton_.onClick = [this] { onSubmitClicked(); };
    addAndMakeVisible (submitButton_);

    openBrowserButton_.onClick = [this]
    {
        if (issueUrl_.isNotEmpty())
            juce::URL (issueUrl_).launchInDefaultBrowser();
    };
    addChildComponent (openBrowserButton_);

    doneButton_.onClick = [this]
    {
        juce::JUCEApplication::getInstance()->systemRequestedQuit();
    };
    addChildComponent (doneButton_);

    tryAgainButton_.onClick = [this]
    {
        state_ = State::Idle;
        errorMessage_.clear();
        updateUI();
    };
    addChildComponent (tryAgainButton_);

    setSize (config_.windowWidth, config_.windowHeight);
    updateUI();
}

MainComponent::~MainComponent()
{
    stopThread (5000);
}

void MainComponent::paint (juce::Graphics& g)
{
    g.fillAll (getLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId));
}

void MainComponent::resized()
{
    auto area = getLocalBounds().reduced (20);

    titleLabel_.setBounds (area.removeFromTop (30));
    area.removeFromTop (5);
    subtitleLabel_.setBounds (area.removeFromTop (20));
    area.removeFromTop (20);

    if (state_ == State::Idle)
    {
        if (config_.allowUserFeedback)
        {
            feedbackLabel_.setBounds (area.removeFromTop (20));
            area.removeFromTop (5);
            feedbackEditor_.setBounds (area.removeFromTop (80));
            area.removeFromTop (15);
        }

        auto buttonArea = area.removeFromBottom (40);
        submitButton_.setBounds (buttonArea);
    }
    else if (state_ == State::Collecting || state_ == State::Submitting)
    {
        statusLabel_.setBounds (area.withTrimmedTop (60).removeFromTop (60));
    }
    else if (state_ == State::Success)
    {
        statusLabel_.setBounds (area.removeFromTop (80));

        auto buttonArea = area.removeFromBottom (40);
        auto halfWidth = buttonArea.getWidth() / 2 - 5;
        openBrowserButton_.setBounds (buttonArea.removeFromLeft (halfWidth));
        buttonArea.removeFromLeft (10);
        doneButton_.setBounds (buttonArea);
    }
    else if (state_ == State::Error)
    {
        statusLabel_.setBounds (area.removeFromTop (120));

        auto buttonArea = area.removeFromBottom (40);
        auto halfWidth = buttonArea.getWidth() / 2 - 5;
        tryAgainButton_.setBounds (buttonArea.removeFromLeft (halfWidth));
        buttonArea.removeFromLeft (10);
        doneButton_.setBounds (buttonArea);
    }
}

void MainComponent::updateUI()
{
    feedbackLabel_.setVisible (state_ == State::Idle && config_.allowUserFeedback);
    feedbackEditor_.setVisible (state_ == State::Idle && config_.allowUserFeedback);
    submitButton_.setVisible (state_ == State::Idle);

    statusLabel_.setVisible (state_ != State::Idle);
    openBrowserButton_.setVisible (state_ == State::Success);
    doneButton_.setVisible (state_ == State::Success || state_ == State::Error);
    tryAgainButton_.setVisible (state_ == State::Error);

    if (state_ == State::Collecting)
        statusLabel_.setText ("Collecting diagnostic information...", juce::dontSendNotification);
    else if (state_ == State::Submitting)
        statusLabel_.setText ("Submitting to GitHub...", juce::dontSendNotification);
    else if (state_ == State::Success)
        statusLabel_.setText ("Report submitted successfully!\n\n" + issueUrl_, juce::dontSendNotification);
    else if (state_ == State::Error)
        statusLabel_.setText ("Submission failed:\n\n" + errorMessage_, juce::dontSendNotification);

    resized();
    repaint();
}

void MainComponent::onSubmitClicked()
{
    state_ = State::Collecting;
    updateUI();
    startThread();
}

void MainComponent::run()
{
    // Collect diagnostics (runs on background thread)
    auto data = collector_.collectAll (feedbackEditor_.getText());

    if (threadShouldExit())
        return;

    // Switch to submitting state
    juce::MessageManager::callAsync ([this]
    {
        state_ = State::Submitting;
        updateUI();
    });

    // Upload to GitHub
    juce::String errorMsg;
    auto url = uploader_.submit (data, errorMsg);

    if (threadShouldExit())
        return;

    // Update UI with result
    juce::MessageManager::callAsync ([this, url, errorMsg]
    {
        if (url.isNotEmpty())
        {
            issueUrl_ = url;
            state_ = State::Success;
        }
        else
        {
            errorMessage_ = errorMsg;
            state_ = State::Error;
        }
        updateUI();
    });
}
