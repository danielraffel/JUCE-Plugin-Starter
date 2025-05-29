cmake_minimum_required(VERSION 3.15)

project(${PROJECT_NAME} VERSION 0.1.0)

add_subdirectory(${JUCE_PATH} JUCE)

juce_add_plugin(${PROJECT_NAME}
    COMPANY_NAME "Your Company Name"
    BUNDLE_ID ${PROJECT_BUNDLE_ID}
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    COPY_PLUGIN_AFTER_BUILD TRUE
    PLUGIN_MANUFACTURER_CODE Juce
    PLUGIN_CODE MYPL
    FORMATS AU VST3 Standalone
    PRODUCT_NAME ${PROJECT_NAME}
    AU_MAIN_TYPE "kAudioUnitType_MusicEffect"
    AU_EXPORT_PREFIX "${PROJECT_NAME}AU"
    VST3_CATEGORIES "Fx|Tools"
)

juce_generate_juce_header(${PROJECT_NAME})

target_sources(${PROJECT_NAME} PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

target_link_libraries(${PROJECT_NAME} PRIVATE
    juce::juce_audio_basics
    juce::juce_audio_devices
    juce::juce_audio_formats
    juce::juce_audio_processors
    juce::juce_audio_utils
    juce::juce_core
    juce::juce_data_structures
    juce::juce_dsp
    juce::juce_events
    juce::juce_graphics
    juce::juce_gui_basics
    juce::juce_gui_extra
)
