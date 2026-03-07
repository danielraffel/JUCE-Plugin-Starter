#pragma once
#include <juce_gui_extra/juce_gui_extra.h>
#include "AppConfig.h"
#include "DiagnosticCollector.h"
#include "GitHubUploader.h"

class MainComponent : public juce::Component,
                      private juce::Thread
{
public:
    MainComponent (const AppConfig& config);
    ~MainComponent() override;

    void paint (juce::Graphics& g) override;
    void resized() override;

private:
    enum class State { Idle, Collecting, Submitting, Success, Error };

    void run() override; // Background thread for collection + upload
    void updateUI();
    void onSubmitClicked();

    const AppConfig& config_;
    DiagnosticCollector collector_;
    GitHubUploader uploader_;

    State state_ = State::Idle;
    juce::String statusMessage_;
    juce::String issueUrl_;
    juce::String errorMessage_;

    // UI Components
    juce::Label titleLabel_;
    juce::Label subtitleLabel_;
    juce::Label statusLabel_;
    juce::Label feedbackLabel_;
    juce::TextEditor feedbackEditor_;
    juce::TextButton submitButton_ { "Collect & Submit Diagnostic" };
    juce::TextButton openBrowserButton_ { "Open in Browser" };
    juce::TextButton doneButton_ { "Done" };
    juce::TextButton tryAgainButton_ { "Try Again" };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};
