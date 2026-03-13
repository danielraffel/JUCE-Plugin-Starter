cmake_minimum_required(VERSION 3.15)

# Platform-specific configuration
if(APPLE)
    # Set minimum macOS version before defining the project
    set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum macOS version")
elseif(MSVC)
    # Embed debug info in object files instead of separate .pdb
    set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded CACHE STRING "" FORCE)
elseif(UNIX AND NOT APPLE)
    # Linux: prefer Clang for consistency with macOS/Windows (both use Clang/MSVC)
    # This is a suggestion — the user can override via -DCMAKE_C_COMPILER / -DCMAKE_CXX_COMPILER
    if(NOT DEFINED CMAKE_C_COMPILER)
        find_program(CLANG_C_COMPILER clang)
        if(CLANG_C_COMPILER)
            set(CMAKE_C_COMPILER "${CLANG_C_COMPILER}" CACHE STRING "")
        endif()
    endif()
    if(NOT DEFINED CMAKE_CXX_COMPILER)
        find_program(CLANG_CXX_COMPILER clang++)
        if(CLANG_CXX_COMPILER)
            set(CMAKE_CXX_COMPILER "${CLANG_CXX_COMPILER}" CACHE STRING "")
        endif()
    endif()
endif()

# Get environment variables
set(PROJECT_NAME $ENV{PROJECT_NAME})
set(PROJECT_BUNDLE_ID $ENV{PROJECT_BUNDLE_ID})
set(JUCE_REPO $ENV{JUCE_REPO})
set(JUCE_TAG $ENV{JUCE_TAG})
set(COMPANY_NAME $ENV{COMPANY_NAME})

# Fallback defaults if env vars not set
if(NOT PROJECT_NAME)
    set(PROJECT_NAME "PROJECT_FOLDER_PLACEHOLDER")
endif()
if(NOT PROJECT_BUNDLE_ID)
    set(PROJECT_BUNDLE_ID "BUNDLE_ID_PLACEHOLDER")
endif()
if(NOT JUCE_REPO)
    set(JUCE_REPO "https://github.com/juce-framework/JUCE.git")
endif()
if(NOT JUCE_TAG)
    set(JUCE_TAG "8.0.12")
endif()
if(NOT COMPANY_NAME)
    set(COMPANY_NAME "DEVELOPER_NAME_PLACEHOLDER")
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
# Use HOME on macOS/Linux, USERPROFILE on Windows; convert to forward slashes
if(DEFINED ENV{HOME})
    set(_HOME_DIR "$ENV{HOME}")
else()
    set(_HOME_DIR "$ENV{USERPROFILE}")
endif()
file(TO_CMAKE_PATH "${_HOME_DIR}/.juce_cache" FETCHCONTENT_BASE_DIR)

FetchContent_Declare(
    JUCE
    GIT_REPOSITORY ${JUCE_REPO}
    GIT_TAG ${JUCE_TAG}
    GIT_SHALLOW ON
)

# Fetch clap-juce-extensions for CLAP plugin format support
FetchContent_Declare(
    clap-juce-extensions
    GIT_REPOSITORY https://github.com/free-audio/clap-juce-extensions.git
    GIT_TAG main
    GIT_SHALLOW ON
)

# Fetch Catch2 v3 for unit testing
FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.7.1
    GIT_SHALLOW ON
)

FetchContent_MakeAvailable(JUCE clap-juce-extensions Catch2)

# Get AU version from environment or calculate it
set(AU_VERSION_INT $ENV{AU_VERSION_INT})
if(NOT AU_VERSION_INT)
    # Calculate from version components: (major << 16) | (minor << 8) | patch
    math(EXPR AU_VERSION_INT "(${VERSION_MAJOR} << 16) | (${VERSION_MINOR} << 8) | ${VERSION_PATCH}")
endif()

# Determine plugin formats based on platform
# AU and AUv3 are macOS/iOS only
if(APPLE)
    set(PLUGIN_FORMATS AU AUv3 VST3 Standalone)
else()
    set(PLUGIN_FORMATS VST3 Standalone)
endif()

# Create the plugin
juce_add_plugin(${PROJECT_NAME}
    COMPANY_NAME ${COMPANY_NAME}
    BUNDLE_ID ${PROJECT_BUNDLE_ID}
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT TRUE
    IS_MIDI_EFFECT TRUE
    NEEDS_EDITOR TRUE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    COPY_PLUGIN_AFTER_BUILD TRUE
    PLUGIN_MANUFACTURER_CODE Juce
    PLUGIN_CODE Mrbl
    FORMATS ${PLUGIN_FORMATS}
    # Note: CLAP format is added separately via clap-juce-extensions below
    PRODUCT_NAME ${PROJECT_NAME}
    VERSION ${PLUGIN_VERSION}
    AU_MAIN_TYPE kAudioUnitType_MIDIProcessor
    AU_EXPORT_PREFIX "${PROJECT_NAME}AU"
    AU_SANDBOX_SAFE TRUE
    VST3_CATEGORIES "Drum|Tools"
)

juce_generate_juce_header(${PROJECT_NAME})

target_sources(${PROJECT_NAME} PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

# No additional include directories needed

target_compile_definitions(${PROJECT_NAME} PUBLIC
    JUCE_VST3_CAN_REPLACE_VST2=0
    JUCE_USE_CURL=0
    JUCE_WEB_BROWSER=0
    JUCE_DISPLAY_SPLASH_SCREEN=0
)

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
    $<TARGET_NAME_IF_EXISTS:${PROJECT_NAME}_Resources>
)

# Add CLAP plugin format
clap_juce_extensions_plugin(TARGET "${PROJECT_NAME}"
    CLAP_ID "${PROJECT_BUNDLE_ID}"
    CLAP_FEATURES audio-effect)

# ==============================================================================
# Auto-Update Support (Standalone target only)
# ==============================================================================
# Enabled via ENABLE_AUTO_UPDATE=true in .env
# macOS: Sparkle 2.x framework (downloaded by scripts/setup_sparkle.sh)
# Windows: WinSparkle (downloaded by scripts/setup_winsparkle.sh)

if(DEFINED ENV{ENABLE_AUTO_UPDATE} AND "$ENV{ENABLE_AUTO_UPDATE}" STREQUAL "true")
    if(TARGET ${PROJECT_NAME}_Standalone)
        target_compile_definitions(${PROJECT_NAME}_Standalone PRIVATE
            ENABLE_AUTO_UPDATE=1
            JUCE_USE_CUSTOM_PLUGIN_STANDALONE_APP=1
        )

        # Custom standalone app with "Check for Updates..." menu
        target_sources(${PROJECT_NAME}_Standalone PRIVATE
            Source/AutoUpdater.h
            Source/StandaloneApp.cpp
        )

        if(APPLE)
            set(SPARKLE_FRAMEWORK_PATH "${CMAKE_SOURCE_DIR}/external/Sparkle.framework")
            if(EXISTS "${SPARKLE_FRAMEWORK_PATH}")
                target_compile_definitions(${PROJECT_NAME}_Standalone PRIVATE ENABLE_SPARKLE=1)

                # Add macOS Sparkle implementation
                target_sources(${PROJECT_NAME}_Standalone PRIVATE
                    Source/AutoUpdater_Mac.mm
                )

                target_include_directories(${PROJECT_NAME}_Standalone PRIVATE
                    "${CMAKE_SOURCE_DIR}/external"
                )

                target_link_libraries(${PROJECT_NAME}_Standalone PRIVATE
                    "${SPARKLE_FRAMEWORK_PATH}"
                )

                # Embed Sparkle.framework in the Standalone app bundle
                add_custom_command(TARGET ${PROJECT_NAME}_Standalone POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E make_directory
                        "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_Standalone>/Contents/Frameworks"
                    COMMAND ditto
                        "${SPARKLE_FRAMEWORK_PATH}"
                        "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_Standalone>/Contents/Frameworks/Sparkle.framework"
                    COMMAND ${CMAKE_COMMAND} -E remove_directory
                        "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_Standalone>/Contents/Frameworks/Sparkle.framework/Headers"
                    COMMENT "Embedding Sparkle.framework in ${PROJECT_NAME} Standalone"
                    VERBATIM
                )

                # Run post_build.sh on Standalone to set Sparkle Info.plist entries
                add_custom_command(TARGET ${PROJECT_NAME}_Standalone POST_BUILD
                    COMMAND "${CMAKE_SOURCE_DIR}/scripts/post_build.sh"
                        "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_Standalone>"
                    COMMENT "Updating Info.plist (version + Sparkle) for ${PROJECT_NAME}_Standalone"
                    VERBATIM
                )
            else()
                message(WARNING "ENABLE_AUTO_UPDATE is true but Sparkle.framework not found at ${SPARKLE_FRAMEWORK_PATH}. Run scripts/setup_sparkle.sh first.")
            endif()
        elseif(WIN32)
            # WinSparkle support added in Phase A2
        endif()
    endif()
endif()

# ==============================================================================
# Standard macOS Paths (no permission prompts)
# ==============================================================================
# This plugin uses Apple-recommended Application Support paths:
#
# ~/Library/Application Support/${PROJECT_NAME}/
#   ├── Samples/    - Sample files
#   ├── Presets/    - User presets
#   └── UserData/   - Other user data
#
# ~/Library/Logs/${PROJECT_NAME}/
#   └── *.log       - Log files
#
# ~/Library/Caches/${PROJECT_BUNDLE_ID}/
#   └── *           - Temporary cache files
#
# These paths follow Apple's Human Interface Guidelines and do not trigger
# permission dialogs during installation. Helper functions are provided in
# PluginProcessor.cpp for accessing these paths.
# ==============================================================================

# Post-build scripts for macOS (Info.plist versioning)
if(APPLE)
    if(TARGET ${PROJECT_NAME}_AU)
        add_custom_command(TARGET ${PROJECT_NAME}_AU
            POST_BUILD
            COMMAND "${CMAKE_SOURCE_DIR}/scripts/post_build.sh" "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_AU>"
            COMMENT "Updating Info.plist version for ${PROJECT_NAME}_AU"
            VERBATIM
        )
    endif()

    if(TARGET ${PROJECT_NAME}_VST3)
        add_custom_command(TARGET ${PROJECT_NAME}_VST3
            POST_BUILD
            COMMAND "${CMAKE_SOURCE_DIR}/scripts/post_build.sh" "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_VST3>"
            COMMENT "Updating Info.plist version for ${PROJECT_NAME}_VST3"
        VERBATIM
    )
    endif()
endif() # APPLE

# Set global C++ standard for all targets
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fix code signing and C++ standard for VST3 helper tool (macOS Xcode only)
if(APPLE AND TARGET juce_vst3_helper)
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
    target_compile_options(juce_vst3_helper PRIVATE -std=c++17)
endif()

# ==============================================================================
# Unit Tests (Catch2 v3)
# ==============================================================================
# Build tests with: cmake --build build --target Tests
# Run tests with:   ./build/Tests_artefacts/Release/Tests
# Or via build.sh:  ./scripts/build.sh all test

file(GLOB_RECURSE TestFiles CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/tests/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/tests/*.h"
)

add_executable(Tests ${TestFiles})

target_compile_features(Tests PRIVATE cxx_std_17)

target_include_directories(Tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/Source
    ${CMAKE_CURRENT_SOURCE_DIR}/tests
)

# Link against the plugin's shared code and Catch2
target_link_libraries(Tests PRIVATE
    ${PROJECT_NAME}
    Catch2::Catch2
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

target_compile_definitions(Tests PRIVATE
    JUCE_VST3_CAN_REPLACE_VST2=0
    JUCE_USE_CURL=0
    JUCE_WEB_BROWSER=0
    JUCE_DISPLAY_SPLASH_SCREEN=0
)

# Register tests with CTest
include(CTest)
include(Catch2::Catch2WithMain OPTIONAL)
if(COMMAND catch_discover_tests)
    catch_discover_tests(Tests)
endif()
