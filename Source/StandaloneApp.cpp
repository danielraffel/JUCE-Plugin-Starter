/**
 * StandaloneApp.cpp — Custom standalone application wrapper
 *
 * Replaces JUCE's default StandaloneFilterApp (via JUCE_USE_CUSTOM_PLUGIN_STANDALONE_APP)
 * to add "Check for Updates..." menu item and AutoUpdater lifecycle management.
 *
 * On macOS: "Check for Updates..." appears in the app name menu (between About and Settings)
 * On Windows: "Check for Updates..." appears in a Help menu (no file menu in standalone)
 *
 * This file is only compiled for the Standalone target.
 */

#include <JuceHeader.h>
#include <juce_audio_plugin_client/Standalone/juce_StandaloneFilterWindow.h>

#if ENABLE_AUTO_UPDATE
#include "AutoUpdater.h"
#endif

//==============================================================================
class UpdateMenuBarModel : public juce::MenuBarModel
{
public:
    enum MenuIDs
    {
        checkForUpdatesID = 9001
    };

    juce::StringArray getMenuBarNames() override
    {
       #if JUCE_MAC
        return {};
       #else
        return { "Help" };
       #endif
    }

    juce::PopupMenu getMenuForIndex (int, const juce::String& menuName) override
    {
        juce::PopupMenu menu;

       #if ! JUCE_MAC
        if (menuName == "Help")
        {
           #if ENABLE_AUTO_UPDATE
            menu.addItem (checkForUpdatesID, "Check for Updates...");
           #endif
        }
       #endif

        return menu;
    }

    void menuItemSelected (int menuItemID, int) override
    {
       #if ENABLE_AUTO_UPDATE
        if (menuItemID == checkForUpdatesID)
            AutoUpdater::getInstance().checkForUpdates();
       #else
        juce::ignoreUnused (menuItemID);
       #endif
    }
};

//==============================================================================
class StandaloneFilterApp : public juce::JUCEApplication
{
public:
    StandaloneFilterApp() = default;

    const juce::String getApplicationName() override    { return JucePlugin_Name; }
    const juce::String getApplicationVersion() override { return JucePlugin_VersionString; }
    bool moreThanOneInstanceAllowed() override           { return true; }

    void initialise (const juce::String&) override
    {
        mainWindow.reset (new juce::StandaloneFilterWindow (
            getApplicationName(),
            juce::LookAndFeel::getDefaultLookAndFeel().findColour (
                juce::ResizableWindow::backgroundColourId),
            nullptr, true));

        mainWindow->setVisible (true);

       #if ENABLE_AUTO_UPDATE
        menuBarModel = std::make_unique<UpdateMenuBarModel>();

       #if JUCE_MAC
        appleMenuItems = std::make_unique<juce::PopupMenu>();
        appleMenuItems->addItem (UpdateMenuBarModel::checkForUpdatesID,
                                 "Check for Updates...");
        appleMenuItems->addSeparator();
        juce::MenuBarModel::setMacMainMenu (menuBarModel.get(), appleMenuItems.get());
       #endif

        // Initialize auto-updater after main window is shown (not during static init)
        juce::Timer::callAfterDelay (500, []()
        {
            AutoUpdater::getInstance().initialize();
        });
       #endif
    }

    void shutdown() override
    {
       #if ENABLE_AUTO_UPDATE
       #if JUCE_MAC
        juce::MenuBarModel::setMacMainMenu (nullptr);
       #endif
        AutoUpdater::getInstance().shutdown();
       #endif

        mainWindow = nullptr;
    }

    void systemRequestedQuit() override
    {
        if (mainWindow != nullptr)
            mainWindow->closeButtonPressed();

        quit();
    }

    void anotherInstanceStarted (const juce::String&) override {}

private:
    std::unique_ptr<juce::StandaloneFilterWindow> mainWindow;

   #if ENABLE_AUTO_UPDATE
    std::unique_ptr<UpdateMenuBarModel> menuBarModel;
   #if JUCE_MAC
    std::unique_ptr<juce::PopupMenu> appleMenuItems;
   #endif
   #endif
};

START_JUCE_APPLICATION (StandaloneFilterApp)
