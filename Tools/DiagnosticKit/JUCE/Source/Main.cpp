#include <juce_gui_extra/juce_gui_extra.h>
#include "AppConfig.h"
#include "MainComponent.h"
#include "DiagnosticCollector.h"
#include "GitHubUploader.h"

class DiagnosticKitApplication : public juce::JUCEApplication
{
public:
    const juce::String getApplicationName() override    { return "DiagnosticKit"; }
    const juce::String getApplicationVersion() override { return "1.0.0"; }
    bool moreThanOneInstanceAllowed() override           { return false; }

    void initialise (const juce::String& commandLine) override
    {
        auto config = AppConfig::load();
        if (! config.has_value())
        {
            if (commandLine.contains ("--cli"))
            {
                std::cerr << "ERROR: Could not load .env configuration.\n";
                setApplicationReturnValue (1);
                quit();
                return;
            }

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

        // CLI test mode: collect and submit diagnostics without GUI
        if (commandLine.contains ("--cli"))
        {
            // Run on a background thread so the message loop stays alive
            juce::Thread::launch ([this, noUpload = commandLine.contains ("--no-upload")]
            {
                runCLI (noUpload);
            });
            return;
        }

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
    void runCLI (bool noUpload)
    {
        std::cout << "=== DiagnosticKit CLI Mode ===\n";
        std::cout << "Collecting diagnostics...\n" << std::flush;

        DiagnosticCollector collector (config_);
        auto data = collector.collectAll ("CLI test submission");

        std::cout << "\n--- Collected Data ---\n";
        std::cout << data.systemInfo.toStdString() << "\n";
        std::cout << data.pluginStatus.toStdString() << "\n";
        std::cout << data.dependencies.toStdString() << "\n";
        std::cout << data.pythonEnvironment.toStdString() << "\n";
        std::cout << data.pipelineHealth.toStdString() << "\n";
        std::cout << data.sessionLogs.toStdString() << "\n";
        std::cout << data.crashLogs.toStdString() << "\n";
        std::cout << data.pluginValidation.toStdString() << "\n";
        std::cout << data.dawDiagnostics.toStdString() << "\n";
        std::cout << data.installerInfo.toStdString() << "\n";
        std::cout << data.securityInfo.toStdString() << "\n";
        std::cout << std::flush;

        if (noUpload)
        {
            std::cout << "\n--- Skipping upload (--no-upload) ---\n" << std::flush;
            juce::MessageManager::callAsync ([this] { quit(); });
            return;
        }

        std::cout << "\n--- Submitting to GitHub ---\n" << std::flush;
        GitHubUploader uploader (config_);
        juce::String errorMsg;
        auto issueUrl = uploader.submit (data, errorMsg);

        if (issueUrl.isNotEmpty())
        {
            std::cout << "SUCCESS: " << issueUrl.toStdString() << "\n" << std::flush;
        }
        else
        {
            std::cerr << "UPLOAD FAILED: " << errorMsg.toStdString() << "\n" << std::flush;
            setApplicationReturnValue (1);
        }

        juce::MessageManager::callAsync ([this] { quit(); });
    }

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
            setResizable (true, true);
            setResizeLimits (350, 300, 800, 900);
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
