#include "helpers/test_helpers.h"
#include <PluginProcessor.h>
#include <catch2/catch_test_macros.hpp>

TEST_CASE ("Plugin instance name", "[plugin]")
{
    CLASS_NAME_PLACEHOLDERAudioProcessor testPlugin;
    // The plugin name comes from CMake's PRODUCT_NAME
    CHECK (testPlugin.getName().isNotEmpty());
}

TEST_CASE ("Plugin default bus layout", "[plugin]")
{
    CLASS_NAME_PLACEHOLDERAudioProcessor testPlugin;
    auto layout = testPlugin.getBusesLayout();

    // Verify the plugin has at least one input or output bus
    CHECK ((layout.getMainInputChannels() > 0 || layout.getMainOutputChannels() > 0 || testPlugin.isMidiEffect()));
}

TEST_CASE ("Plugin produces editor", "[editor]")
{
    runWithinPluginEditor ([] (CLASS_NAME_PLACEHOLDERAudioProcessor& plugin) {
        REQUIRE (plugin.getActiveEditor() != nullptr);
    });
}
