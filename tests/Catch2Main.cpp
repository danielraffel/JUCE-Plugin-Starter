// Custom Catch2 main that initializes JUCE's MessageManager
// This is needed because PluginProcessor and PluginEditor may use JUCE GUI internals

#include "juce_gui_basics/juce_gui_basics.h"
#include <catch2/catch_session.hpp>

int main (int argc, char* argv[])
{
    // Initialize JUCE's GUI system for tests that need MessageManager
    // (e.g., AudioProcessorValueTreeState, Timer-based code, Editor tests)
    juce::ScopedJuceInitialiser_GUI gui;

    return Catch::Session().run (argc, argv);
}
