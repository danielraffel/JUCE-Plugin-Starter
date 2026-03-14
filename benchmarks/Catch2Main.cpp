// Custom Catch2 main for benchmarks with JUCE MessageManager initialization

#include "juce_gui_basics/juce_gui_basics.h"
#include <catch2/catch_session.hpp>

int main (int argc, char* argv[])
{
    juce::ScopedJuceInitialiser_GUI gui;
    return Catch::Session().run (argc, argv);
}
