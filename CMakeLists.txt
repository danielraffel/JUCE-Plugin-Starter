cmake_minimum_required(VERSION 3.15)

# Set minimum macOS version before defining the project
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.5" CACHE STRING "Minimum macOS version")

# Get environment variables
set(PROJECT_NAME $ENV{PROJECT_NAME})
set(PROJECT_BUNDLE_ID $ENV{PROJECT_BUNDLE_ID})
set(JUCE_REPO $ENV{JUCE_REPO})
set(JUCE_TAG $ENV{JUCE_TAG})
set(COMPANY_NAME $ENV{COMPANY_NAME})

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
    set(JUCE_TAG "8.0.8")
endif()
if(NOT COMPANY_NAME)
    set(COMPANY_NAME "Default Company Name")
endif()

# Get timestamp for unique version
string(TIMESTAMP VERSION_TIMESTAMP "%y%m%d%H%M" UTC)

# Read version base from env or fallback
set(BASE_PROJECT_VERSION $ENV{BASE_PROJECT_VERSION})
if(NOT BASE_PROJECT_VERSION)
    set(BASE_PROJECT_VERSION "1.1.")
endif()

set(PLUGIN_VERSION "${BASE_PROJECT_VERSION}${VERSION_TIMESTAMP}")

project(${PROJECT_NAME} VERSION ${PLUGIN_VERSION})

# === Configuration Summary ===
message(STATUS "🎛️  Plugin Configuration Summary:")
message(STATUS "   Project Name: ${PROJECT_NAME}")
message(STATUS "   Bundle ID: ${PROJECT_BUNDLE_ID}")
message(STATUS "   Company: ${COMPANY_NAME}")
message(STATUS "   Version: ${PLUGIN_VERSION}")
message(STATUS "   JUCE Version: ${JUCE_TAG}")

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

# === Plugin Configuration Categories ===

# 🎵 Audio Plugin Type Configuration - Read from Environment
set(PLUGIN_IS_SYNTH $ENV{PLUGIN_IS_SYNTH})
set(PLUGIN_NEEDS_MIDI_INPUT $ENV{PLUGIN_NEEDS_MIDI_INPUT})
set(PLUGIN_NEEDS_MIDI_OUTPUT $ENV{PLUGIN_NEEDS_MIDI_OUTPUT})
set(PLUGIN_IS_MIDI_EFFECT $ENV{PLUGIN_IS_MIDI_EFFECT})

# Fallback defaults if env vars not set
if(NOT PLUGIN_IS_SYNTH)
    set(PLUGIN_IS_SYNTH TRUE)
endif()
if(NOT PLUGIN_NEEDS_MIDI_INPUT)
    set(PLUGIN_NEEDS_MIDI_INPUT TRUE)
endif()
if(NOT PLUGIN_NEEDS_MIDI_OUTPUT)
    set(PLUGIN_NEEDS_MIDI_OUTPUT FALSE)
endif()
if(NOT PLUGIN_IS_MIDI_EFFECT)
    set(PLUGIN_IS_MIDI_EFFECT FALSE)
endif()

# 🎹 Editor Configuration
set(PLUGIN_EDITOR_WANTS_KEYBOARD_FOCUS $ENV{PLUGIN_EDITOR_WANTS_KEYBOARD_FOCUS})
if(NOT PLUGIN_EDITOR_WANTS_KEYBOARD_FOCUS)
    set(PLUGIN_EDITOR_WANTS_KEYBOARD_FOCUS TRUE)
endif()

# 📦 Build Configuration
set(PLUGIN_COPY_AFTER_BUILD $ENV{PLUGIN_COPY_AFTER_BUILD})
if(NOT PLUGIN_COPY_AFTER_BUILD)
    set(PLUGIN_COPY_AFTER_BUILD TRUE)
endif()

# 🏷️ Plugin Identification - Read from Environment
set(PLUGIN_MANUFACTURER_CODE $ENV{PLUGIN_MANUFACTURER_CODE})
set(PLUGIN_CODE $ENV{PLUGIN_CODE})

if(NOT PLUGIN_MANUFACTURER_CODE)
    set(PLUGIN_MANUFACTURER_CODE "Juce")
endif()
if(NOT PLUGIN_CODE)
    set(PLUGIN_CODE "MYPL")
endif()

# 🎯 Plugin Formats - Read from Environment
set(PLUGIN_FORMATS $ENV{PLUGIN_FORMATS})
if(NOT PLUGIN_FORMATS)
    set(PLUGIN_FORMATS "AU;VST3;Standalone")
endif()

# 🎼 Audio Unit Specific Configuration
set(PLUGIN_AU_MAIN_TYPE $ENV{PLUGIN_AU_MAIN_TYPE})
if(NOT PLUGIN_AU_MAIN_TYPE)
    set(PLUGIN_AU_MAIN_TYPE "kAudioUnitType_MusicDevice")
endif()

set(PLUGIN_AU_EXPORT_PREFIX $ENV{PLUGIN_AU_EXPORT_PREFIX})
if(NOT PLUGIN_AU_EXPORT_PREFIX)
    set(PLUGIN_AU_EXPORT_PREFIX "${PROJECT_NAME}AU")
endif()

# VST3 Categories - Read from Environment
set(PLUGIN_VST3_CATEGORIES $ENV{PLUGIN_VST3_CATEGORIES})
if(NOT PLUGIN_VST3_CATEGORIES)
    set(PLUGIN_VST3_CATEGORIES "Synth")
endif()

# === Optional JUCE Modules - Read from Environment ===
set(ENABLE_JUCE_DSP $ENV{ENABLE_JUCE_DSP})
set(ENABLE_JUCE_OPENGL $ENV{ENABLE_JUCE_OPENGL})
set(ENABLE_JUCE_CRYPTOGRAPHY $ENV{ENABLE_JUCE_CRYPTOGRAPHY})

# Default to ON for DSP, OFF for others
if(NOT ENABLE_JUCE_DSP)
    set(ENABLE_JUCE_DSP ON)
endif()
if(NOT ENABLE_JUCE_OPENGL)
    set(ENABLE_JUCE_OPENGL OFF)
endif()
if(NOT ENABLE_JUCE_CRYPTOGRAPHY)
    set(ENABLE_JUCE_CRYPTOGRAPHY OFF)
endif()

# Create the plugin with organized configuration
juce_add_plugin(${PROJECT_NAME}
    # Basic Information
    COMPANY_NAME ${COMPANY_NAME}
    BUNDLE_ID ${PROJECT_BUNDLE_ID}
    PRODUCT_NAME ${PROJECT_NAME}
    
    # Plugin Type Configuration
    IS_SYNTH ${PLUGIN_IS_SYNTH}
    NEEDS_MIDI_INPUT ${PLUGIN_NEEDS_MIDI_INPUT}
    NEEDS_MIDI_OUTPUT ${PLUGIN_NEEDS_MIDI_OUTPUT}
    IS_MIDI_EFFECT ${PLUGIN_IS_MIDI_EFFECT}
    
    # Editor Configuration
    EDITOR_WANTS_KEYBOARD_FOCUS ${PLUGIN_EDITOR_WANTS_KEYBOARD_FOCUS}
    
    # Build Configuration
    COPY_PLUGIN_AFTER_BUILD ${PLUGIN_COPY_AFTER_BUILD}
    
    # Plugin Identification
    PLUGIN_MANUFACTURER_CODE ${PLUGIN_MANUFACTURER_CODE}
    PLUGIN_CODE ${PLUGIN_CODE}
    
    # Supported Formats
    FORMATS ${PLUGIN_FORMATS}
    
    # Format-Specific Configuration
    AU_MAIN_TYPE ${PLUGIN_AU_MAIN_TYPE}
    AU_EXPORT_PREFIX ${PLUGIN_AU_EXPORT_PREFIX}
    VST3_CATEGORIES ${PLUGIN_VST3_CATEGORIES}
)

# Display enhanced plugin configuration summary
message(STATUS "🎵 Plugin Type: ${PLUGIN_IS_SYNTH}")
message(STATUS "🎹 MIDI Input: ${PLUGIN_NEEDS_MIDI_INPUT}")
message(STATUS "📦 Formats: ${PLUGIN_FORMATS}")
message(STATUS "🎼 AU Type: ${PLUGIN_AU_MAIN_TYPE}")
message(STATUS "🎛️  VST3 Category: ${PLUGIN_VST3_CATEGORIES}")
message(STATUS "🔧 Optional Modules:")
message(STATUS "   DSP: ${ENABLE_JUCE_DSP}")
message(STATUS "   OpenGL: ${ENABLE_JUCE_OPENGL}")
message(STATUS "   Cryptography: ${ENABLE_JUCE_CRYPTOGRAPHY}")

juce_generate_juce_header(${PROJECT_NAME})

target_sources(${PROJECT_NAME} PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
 )

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

# === Conditional JUCE Module Linking ===
set(JUCE_MODULES
    juce::juce_audio_basics
    juce::juce_audio_devices
    juce::juce_audio_formats
    juce::juce_audio_processors
    juce::juce_audio_utils
    juce::juce_core
    juce::juce_data_structures
    juce::juce_events
    juce::juce_graphics
    juce::juce_gui_basics
    juce::juce_gui_extra
)

# Add optional modules based on environment variables
if(ENABLE_JUCE_DSP)
    list(APPEND JUCE_MODULES juce::juce_dsp)
    message(STATUS "✅ Including JUCE DSP module")
endif()

if(ENABLE_JUCE_OPENGL)
    list(APPEND JUCE_MODULES juce::juce_opengl)
    message(STATUS "✅ Including JUCE OpenGL module")
endif()

if(ENABLE_JUCE_CRYPTOGRAPHY)
    list(APPEND JUCE_MODULES juce::juce_cryptography)
    message(STATUS "✅ Including JUCE Cryptography module")
endif()

target_link_libraries(${PROJECT_NAME} PRIVATE
    ${JUCE_MODULES}
    ${PROJECT_NAME}_Resources
)

# Bundle the script with the plugin
set(RESOURCE_FILES
    Resources/original_sonicgarbage_script.sh
)

juce_add_binary_data(${PROJECT_NAME}_Resources SOURCES ${RESOURCE_FILES})

add_custom_command(TARGET ${PROJECT_NAME}_AU
    POST_BUILD
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/post_build.sh" "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_AU>"
    COMMENT "Updating Info.plist version for ${PROJECT_NAME}_AU"
    VERBATIM
)
