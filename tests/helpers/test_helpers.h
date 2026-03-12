#pragma once
#include <PluginProcessor.h>

// Helper to run test code within the context of a plugin editor.
// Creates a processor, opens its editor, runs the test, then cleans up.
//
// Example usage:
//   runWithinPluginEditor ([&] (CLASS_NAME_PLACEHOLDERAudioProcessor& plugin) {
//       auto* editor = plugin.getActiveEditor();
//       REQUIRE (editor != nullptr);
//   });
[[maybe_unused]] static void runWithinPluginEditor (const std::function<void (CLASS_NAME_PLACEHOLDERAudioProcessor& plugin)>& testCode)
{
    CLASS_NAME_PLACEHOLDERAudioProcessor plugin;
    const auto editor = plugin.createEditorIfNeeded();

    testCode (plugin);

    plugin.editorBeingDeleted (editor);
    delete editor;
}
