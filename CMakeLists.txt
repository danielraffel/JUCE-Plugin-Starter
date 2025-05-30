cmake_minimum_required(VERSION 3.15)

# Get environment variables
set(PROJECT_NAME $ENV{PROJECT_NAME})
set(PROJECT_BUNDLE_ID $ENV{PROJECT_BUNDLE_ID})
set(JUCE_REPO $ENV{JUCE_REPO})
set(JUCE_TAG $ENV{JUCE_TAG})

# Fallback defaults if env vars not set
if(NOT PROJECT_NAME)
    set(PROJECT_NAME "MyCoolPlugin")
endif()
if(NOT PROJECT_BUNDLE_ID)
    set(PROJECT_BUNDLE_ID "com.myname.mycoolplugin")
endif()
if(NOT JUCE_REPO)
    set(JUCE_REPO "https://github.com/juce-framework/JUCE.git")
endif()
if(NOT JUCE_TAG)
    set(JUCE_TAG "8.0.7")
endif()

project(${PROJECT_NAME} VERSION 0.1.0)

# Fetch JUCE using FetchContent
include(FetchContent)

# Use shared JUCE cache to avoid re-downloading across projects
set(FETCHCONTENT_BASE_DIR "$ENV{HOME}/.juce_cache")

FetchContent_Declare(
    JUCE 
    GIT_REPOSITORY ${JUCE_REPO}
    GIT_TAG ${JUCE_TAG}
    GIT_SHALLOW ON
)
FetchContent_MakeAvailable(JUCE)

# Create the plugin
juce_add_plugin(${PROJECT_NAME}
    COMPANY_NAME "Your Company Name"
    BUNDLE_ID ${PROJECT_BUNDLE_ID}
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    COPY_PLUGIN_AFTER_BUILD FALSE
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

# Post-build step for the Audio Unit target: Update Info.plist version string
# The actual copying to the system Components folder is handled by JUCE's CMake scripts when COPY_PLUGIN_AFTER_BUILD is TRUE.
add_custom_command(TARGET ${PROJECT_NAME}_AU
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Running post_build.sh for ${PROJECT_NAME}_AU..."
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/post_build.sh" "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_AU>"
    COMMENT "Updating Info.plist version for ${PROJECT_NAME}_AU"
    VERBATIM
)
