#include <juce_gui_extra/juce_gui_extra.h>
#include "AppConfig.h"
#include "MainComponent.h"

class DiagnosticKitApplication : public juce::JUCEApplication
{
public:
    const juce::String getApplicationName() override    { return "DiagnosticKit"; }
    const juce::String getApplicationVersion() override { return "1.0.0"; }
    bool moreThanOneInstanceAllowed() override           { return false; }

    void initialise (const juce::String&) override
    {
        auto config = AppConfig::load();
        if (! config.has_value())
        {
            juce::AlertWindow::showMessageBoxAsync (
                juce::MessageBoxIconType::WarningIcon,
                "Configuration Error",
                "Could not load .env configuration file.\n\n"
                "Please ensure the app was built correctly with a valid .env file.",
                "Quit",
                nullptr,
                juce::ModalCallbackFunction::create ([this](int) { quit(); }));
            return;
        }

        config_ = std::move (*config);
        mainWindow_ = std::make_unique<MainWindow> (config_);
    }

    void shutdown() override
    {
        mainWindow_.reset();
    }

    void systemRequestedQuit() override
    {
        quit();
    }

private:
    class MainWindow : public juce::DocumentWindow
    {
    public:
        MainWindow (const AppConfig& config)
            : DocumentWindow (config.appName,
                              juce::Desktop::getInstance().getDefaultLookAndFeel()
                                  .findColour (ResizableWindow::backgroundColourId),
                              DocumentWindow::closeButton)
        {
            setUsingNativeTitleBar (true);
            setContentOwned (new MainComponent (config), true);
            setResizable (false, false);
            centreWithSize (getWidth(), getHeight());
            setVisible (true);
        }

        void closeButtonPressed() override
        {
            juce::JUCEApplication::getInstance()->systemRequestedQuit();
        }
    };

    AppConfig config_;
    std::unique_ptr<MainWindow> mainWindow_;
};

START_JUCE_APPLICATION (DiagnosticKitApplication)
