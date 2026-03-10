#include "MainComponent.h"

MainComponent::MainComponent (const AppConfig& config)
    : juce::Thread ("DiagnosticWorker"),
      config_ (config),
      collector_ (config),
      uploader_ (config)
{
    // Subtitle (title is shown in native title bar)
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

    // Preview editor (read-only, shows collected data before upload)
    previewEditor_.setMultiLine (true);
    previewEditor_.setReadOnly (true);
    previewEditor_.setScrollbarsShown (true);
    addChildComponent (previewEditor_);

    // Buttons
    collectButton_.onClick = [this] { onCollectClicked(); };
    addAndMakeVisible (collectButton_);

    submitButton_.onClick = [this] { onSubmitClicked(); };
    addChildComponent (submitButton_);

    copyUrlButton_.onClick = [this]
    {
        if (issueUrl_.isNotEmpty())
            juce::SystemClipboard::copyTextToClipboard (issueUrl_);
    };
    addChildComponent (copyUrlButton_);

    openBrowserButton_.onClick = [this]
    {
        if (issueUrl_.isNotEmpty())
            juce::URL (issueUrl_).launchInDefaultBrowser();
    };
    addChildComponent (openBrowserButton_);

    privacyNoteLabel_.setFont (juce::FontOptions (11.0f));
    privacyNoteLabel_.setColour (juce::Label::textColourId, juce::Colours::grey);
    privacyNoteLabel_.setJustificationType (juce::Justification::centred);
    addChildComponent (privacyNoteLabel_);

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

    cancelButton_.onClick = [this]
    {
        state_ = State::Idle;
        updateUI();
    };
    addChildComponent (cancelButton_);

    setSize (config_.windowWidth, config_.windowHeight);
    updateUI();
}

MainComponent::~MainComponent()
{
    stopTimer();
    stopThread (5000);
}

void MainComponent::timerCallback()
{
    progressDots_ = (progressDots_ + 1) % 4;
    juce::String dots;
    for (int i = 0; i < progressDots_; ++i)
        dots << ".";

    if (state_ == State::Collecting)
        statusLabel_.setText ("Collecting diagnostic information" + dots + "\n\nThis may take up to 30 seconds", juce::dontSendNotification);
    else if (state_ == State::Submitting)
        statusLabel_.setText ("Submitting to GitHub" + dots, juce::dontSendNotification);
}

void MainComponent::paint (juce::Graphics& g)
{
    g.fillAll (getLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId));
}

void MainComponent::resized()
{
    auto area = getLocalBounds().reduced (20);

    subtitleLabel_.setBounds (area.removeFromTop (20));
    area.removeFromTop (10);

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
        collectButton_.setBounds (buttonArea);
    }
    else if (state_ == State::Collecting || state_ == State::Submitting)
    {
        statusLabel_.setBounds (area.withTrimmedTop (60).removeFromTop (60));
    }
    else if (state_ == State::Preview)
    {
        statusLabel_.setBounds (area.removeFromTop (25));
        area.removeFromTop (5);

        auto buttonArea = area.removeFromBottom (40);
        auto thirdWidth = buttonArea.getWidth() / 2 - 5;
        submitButton_.setBounds (buttonArea.removeFromLeft (thirdWidth));
        buttonArea.removeFromLeft (10);
        cancelButton_.setBounds (buttonArea);

        previewEditor_.setBounds (area);
    }
    else if (state_ == State::Success)
    {
        statusLabel_.setBounds (area.removeFromTop (80));

        // Privacy note at bottom, above buttons
        auto doneArea = area.removeFromBottom (40);
        area.removeFromBottom (8);
        privacyNoteLabel_.setBounds (area.removeFromBottom (45));
        area.removeFromBottom (8);

        // Three buttons: Copy URL | Open in Browser | Done
        auto buttonArea = area.removeFromBottom (40);
        auto thirdWidth = (buttonArea.getWidth() - 20) / 3;
        copyUrlButton_.setBounds (buttonArea.removeFromLeft (thirdWidth));
        buttonArea.removeFromLeft (10);
        openBrowserButton_.setBounds (buttonArea.removeFromLeft (thirdWidth));
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
    // Hide everything first
    feedbackLabel_.setVisible (false);
    feedbackEditor_.setVisible (false);
    collectButton_.setVisible (false);
    submitButton_.setVisible (false);
    cancelButton_.setVisible (false);
    previewEditor_.setVisible (false);
    statusLabel_.setVisible (false);
    copyUrlButton_.setVisible (false);
    openBrowserButton_.setVisible (false);
    privacyNoteLabel_.setVisible (false);
    doneButton_.setVisible (false);
    tryAgainButton_.setVisible (false);

    switch (state_)
    {
        case State::Idle:
            if (config_.allowUserFeedback)
            {
                feedbackLabel_.setVisible (true);
                feedbackEditor_.setVisible (true);
            }
            collectButton_.setVisible (true);
            break;

        case State::Collecting:
            statusLabel_.setVisible (true);
            statusLabel_.setText ("Collecting diagnostic information...\n\nThis may take up to 30 seconds", juce::dontSendNotification);
            progressDots_ = 0;
            startTimer (500);
            break;

        case State::Preview:
            stopTimer();
            statusLabel_.setVisible (true);
            statusLabel_.setText ("Review the data below before submitting:", juce::dontSendNotification);
            previewEditor_.setVisible (true);
            submitButton_.setVisible (true);
            cancelButton_.setVisible (true);
            break;

        case State::Submitting:
            statusLabel_.setVisible (true);
            statusLabel_.setText ("Submitting to GitHub...", juce::dontSendNotification);
            progressDots_ = 0;
            startTimer (500);
            break;

        case State::Success:
            stopTimer();
            statusLabel_.setVisible (true);
            statusLabel_.setText ("Report submitted successfully!\n\n" + issueUrl_, juce::dontSendNotification);
            copyUrlButton_.setVisible (true);
            openBrowserButton_.setVisible (true);
            privacyNoteLabel_.setVisible (true);
            privacyNoteLabel_.setText ("This report was sent to a private repository.\n"
                                       "The link above may show a 404 page — that's normal.\n"
                                       "The developer has been automatically notified.",
                                       juce::dontSendNotification);
            doneButton_.setVisible (true);
            break;

        case State::Error:
            stopTimer();
            statusLabel_.setVisible (true);
            statusLabel_.setText ("Submission failed:\n\n" + errorMessage_, juce::dontSendNotification);
            tryAgainButton_.setVisible (true);
            doneButton_.setVisible (true);
            break;
    }

    resized();
    repaint();
}

juce::String MainComponent::anonymize (const juce::String& text)
{
    auto result = text;

    // Get the current username and home path
    auto home = juce::File::getSpecialLocation (juce::File::userHomeDirectory);
    auto homePath = home.getFullPathName();
    auto username = home.getFileName(); // Last component of home path is the username

   #if JUCE_WINDOWS
    // C:\Users\daniel -> C:\Users\<user>
    result = result.replace (homePath, "C:\\Users\\<user>", true);
    result = result.replace (username, "<user>", false);
    // Also handle forward-slash variants
    result = result.replace (homePath.replace ("\\", "/"), "C:/Users/<user>", true);
   #else
    // /home/daniel -> /home/<user>
    result = result.replace (homePath, "/home/<user>", true);
    result = result.replace ("/Users/" + username, "/Users/<user>", true);
    // Replace bare username if it appears in paths (conservative — only after path separators)
    result = result.replace ("/" + username + "/", "/<user>/", true);
   #endif

    // Anonymize hostname in crash log filenames (e.g., _machinename.ips)
    auto hostname = juce::SystemStats::getComputerName();
    if (hostname.isNotEmpty())
        result = result.replace (hostname, "<hostname>", true);

    return result;
}

void MainComponent::onCollectClicked()
{
    state_ = State::Collecting;
    updateUI();
    startThread();
}

void MainComponent::onSubmitClicked()
{
    state_ = State::Submitting;
    updateUI();

    // Run upload on background thread
    auto& uploader = uploader_;
    auto& data = collectedData_;

    juce::Thread::launch ([this, &uploader, &data]
    {
        juce::String errorMsg;
        auto url = uploader.submit (data, errorMsg);

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
    });
}

void MainComponent::run()
{
    // Collect diagnostics (runs on background thread)
    collectedData_ = collector_.collectAll (feedbackEditor_.getText());

    if (threadShouldExit())
        return;

    // Anonymize all collected data
    collectedData_.systemInfo        = anonymize (collectedData_.systemInfo);
    collectedData_.pluginStatus      = anonymize (collectedData_.pluginStatus);
    collectedData_.crashLogs         = anonymize (collectedData_.crashLogs);
    collectedData_.pluginValidation  = anonymize (collectedData_.pluginValidation);
    collectedData_.dawDiagnostics    = anonymize (collectedData_.dawDiagnostics);
    collectedData_.pythonEnvironment = anonymize (collectedData_.pythonEnvironment);
    collectedData_.sessionLogs       = anonymize (collectedData_.sessionLogs);
    collectedData_.installerInfo     = anonymize (collectedData_.installerInfo);
    collectedData_.dependencies      = anonymize (collectedData_.dependencies);
    collectedData_.pipelineHealth    = anonymize (collectedData_.pipelineHealth);
    collectedData_.securityInfo      = anonymize (collectedData_.securityInfo);

    // Build preview text
    juce::String preview;
    if (collectedData_.userFeedback.isNotEmpty())
        preview << "== User Feedback ==\n" << collectedData_.userFeedback << "\n\n";
    preview << collectedData_.systemInfo << "\n";
    preview << collectedData_.pluginStatus << "\n";
    preview << collectedData_.dependencies << "\n";
    preview << collectedData_.pythonEnvironment << "\n";
    preview << collectedData_.pipelineHealth << "\n";
    preview << collectedData_.sessionLogs << "\n";
    preview << collectedData_.crashLogs << "\n";
    preview << collectedData_.pluginValidation << "\n";
    preview << collectedData_.dawDiagnostics << "\n";
    preview << collectedData_.installerInfo << "\n";
    preview << collectedData_.securityInfo;

    // Switch to preview state on message thread
    juce::MessageManager::callAsync ([this, preview]
    {
        previewEditor_.setText (preview);
        state_ = State::Preview;
        updateUI();
    });
}
