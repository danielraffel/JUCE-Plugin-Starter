cmake_minimum_required(VERSION 3.15)

# Set minimum macOS version before defining the project
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum macOS version")

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

# Use semantic versioning (major.minor.patch)
# Read from environment or use defaults
set(VERSION_MAJOR $ENV{VERSION_MAJOR})
set(VERSION_MINOR $ENV{VERSION_MINOR})
set(VERSION_PATCH $ENV{VERSION_PATCH})

if(NOT VERSION_MAJOR)
    set(VERSION_MAJOR 1)
endif()
if(NOT VERSION_MINOR)
    set(VERSION_MINOR 0)
endif()
if(NOT VERSION_PATCH)
    set(VERSION_PATCH 0)
endif()

set(PLUGIN_VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

project(${PROJECT_NAME} VERSION ${PLUGIN_VERSION})

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

# Get AU version from environment or calculate it
set(AU_VERSION_INT $ENV{AU_VERSION_INT})
if(NOT AU_VERSION_INT)
    # Calculate from version components: (major << 16) | (minor << 8) | patch
    math(EXPR AU_VERSION_INT "(${VERSION_MAJOR} << 16) | (${VERSION_MINOR} << 8) | ${VERSION_PATCH}")
endif()

# Create the plugin
juce_add_plugin(${PROJECT_NAME}
    COMPANY_NAME ${COMPANY_NAME}
    BUNDLE_ID ${PROJECT_BUNDLE_ID}
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT TRUE
    IS_MIDI_EFFECT TRUE  # This is a MIDI effect plugin
    NEEDS_EDITOR TRUE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    COPY_PLUGIN_AFTER_BUILD TRUE
    PLUGIN_MANUFACTURER_CODE Juce
    PLUGIN_CODE Mrbl
    FORMATS AU VST3 Standalone
    PRODUCT_NAME ${PROJECT_NAME}
    VERSION ${PLUGIN_VERSION}
    AU_MAIN_TYPE kAudioUnitType_MIDIProcessor
    AU_EXPORT_PREFIX "${PROJECT_NAME}AU"
    AU_SANDBOX_SAFE TRUE
    VST3_CATEGORIES "Drum|Tools"
    ICON_BIG Resources/Images/app_icon_1024.png
)

juce_generate_juce_header(${PROJECT_NAME})

target_sources(${PROJECT_NAME} PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
    Source/Marbly/RandomStream.cpp
    Source/Marbly/RandomStream.h
    Source/Marbly/TGenerator.cpp
    Source/Marbly/TGenerator.h
    Source/Marbly/XYGenerator.cpp
    Source/Marbly/XYGenerator.h
    Source/Marbly/LFOModulator.h
    Source/PluginEditor_ModulationTab.cpp
    Source/Visage/VisageStyle.cpp
    Source/Visage/VisageStyle.h
)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

# No additional include directories needed

# Feature flags
option(ENABLE_VELOCITY_SYSTEM "Enable velocity/accent system for dynamics" ON)
option(ENABLE_EUCLIDEAN_MODE "Enable Euclidean rhythm generation" ON)
option(ENABLE_PATTERN_CHAIN "Enable pattern chaining system" ON)
option(ENABLE_MODULATION_MATRIX "Enable LFO modulation matrix" ON)

target_compile_definitions(${PROJECT_NAME} PUBLIC
    JUCE_VST3_CAN_REPLACE_VST2=0
    JUCE_USE_CURL=0
    JUCE_WEB_BROWSER=0
    JUCE_DISPLAY_SPLASH_SCREEN=0
)

# Add feature flags
if(ENABLE_VELOCITY_SYSTEM)
    target_compile_definitions(${PROJECT_NAME} PUBLIC ENABLE_VELOCITY_SYSTEM=1)
endif()

if(ENABLE_EUCLIDEAN_MODE)
    target_compile_definitions(${PROJECT_NAME} PUBLIC ENABLE_EUCLIDEAN_MODE=1)
endif()

if(ENABLE_PATTERN_CHAIN)
    target_compile_definitions(${PROJECT_NAME} PUBLIC ENABLE_PATTERN_CHAIN=1)
endif()

if(ENABLE_MODULATION_MATRIX)
    target_compile_definitions(${PROJECT_NAME} PUBLIC ENABLE_MODULATION_MATRIX=1)
endif()

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
    ${PROJECT_NAME}_Resources
)

# Add font resources
set(FONT_RESOURCES
    Resources/Fonts/Material_Symbols_Outlined/MaterialSymbolsOutlined-VariableFont_FILL,GRAD,opsz,wght.ttf
)

# Add binary data for resources including fonts
juce_add_binary_data(${PROJECT_NAME}_Resources SOURCES ${FONT_RESOURCES})

add_custom_command(TARGET ${PROJECT_NAME}_AU
    POST_BUILD
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/post_build.sh" "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_AU>"
    COMMENT "Updating Info.plist version for ${PROJECT_NAME}_AU"
    VERBATIM
)

# Add post-build for VST3 if it's being built
if(TARGET ${PROJECT_NAME}_VST3)
    add_custom_command(TARGET ${PROJECT_NAME}_VST3
        POST_BUILD
        COMMAND "${CMAKE_SOURCE_DIR}/scripts/post_build.sh" "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_VST3>"
        COMMENT "Updating Info.plist version for ${PROJECT_NAME}_VST3"
        VERBATIM
    )
endif()

# Set global C++ standard for all targets
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fix code signing and C++ standard for VST3 helper tool (must be after JUCE targets are created)
if(TARGET juce_vst3_helper)
    set_target_properties(juce_vst3_helper PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
        XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "-"
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED YES
        XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD "c++17"
        XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY "libc++"
    )
    target_compile_features(juce_vst3_helper PRIVATE cxx_std_17)
    # Explicitly set compile options
    target_compile_options(juce_vst3_helper PRIVATE -std=c++17)
endif()
