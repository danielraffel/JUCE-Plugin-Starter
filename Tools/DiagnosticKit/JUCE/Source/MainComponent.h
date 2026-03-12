#pragma once
#include <juce_gui_extra/juce_gui_extra.h>
#include "AppConfig.h"
#include "DiagnosticCollector.h"
#include "GitHubUploader.h"

class MainComponent : public juce::Component,
                      private juce::Thread,
                      private juce::Timer
{
public:
    MainComponent (const AppConfig& config);
    ~MainComponent() override;

    void paint (juce::Graphics& g) override;
    void resized() override;

private:
    enum class State { Idle, Collecting, Preview, Submitting, Success, Error };

    void run() override; // Background thread for collection + upload
    void timerCallback() override; // Animate progress indicator
    void updateUI();
    void onCollectClicked();
    void onSubmitClicked();

    /** Replace username/home paths with anonymized versions. */
    static juce::String anonymize (const juce::String& text);

    const AppConfig& config_;
    DiagnosticCollector collector_;
    GitHubUploader uploader_;

    State state_ = State::Idle;
    juce::String statusMessage_;
    juce::String issueUrl_;
    juce::String errorMessage_;
    DiagnosticData collectedData_;
    int progressDots_ = 0;

    // UI Components
    juce::Label subtitleLabel_;
    juce::Label statusLabel_;
    juce::Label feedbackLabel_;
    juce::TextEditor feedbackEditor_;
    juce::Label emailLabel_;
    juce::TextEditor emailEditor_;
    juce::TextEditor previewEditor_;  // Shows collected data before upload
    juce::Label privacyInfoLabel_;    // "Learn how we protect your data" on Preview
    juce::Label trustInfoLabel_;      // Privacy assurance on Idle screen
    juce::TextButton collectButton_ { "Collect Diagnostic" };
    juce::TextButton submitButton_ { "Submit to GitHub" };
    juce::TextButton copyUrlButton_ { "Copy URL" };
    juce::TextButton openBrowserButton_ { "Open in Browser" };
    juce::Label privacyNoteLabel_;
    juce::TextButton doneButton_ { "Done" };
    juce::TextButton tryAgainButton_ { "Try Again" };
    juce::TextButton cancelButton_ { "Cancel" };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};
