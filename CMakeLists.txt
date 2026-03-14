cmake_minimum_required(VERSION 3.15)

# ==============================================================================
# IDE and Compiler Defaults
# ==============================================================================

# Show all JUCE module sources in IDE project tree
set_property(GLOBAL PROPERTY USE_FOLDERS YES)
option(JUCE_ENABLE_MODULE_SOURCE_GROUPS "Show all module sources in IDE projects" ON)

# Platform-specific configuration
if(APPLE)
    # Set minimum macOS version before defining the project
    set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum macOS version")
    # Don't generate Xcode schemes for every target (we enable selectively below)
    set(CMAKE_XCODE_GENERATE_SCHEME OFF)
elseif(MSVC)
    # Embed debug info in object files instead of separate .pdb (required for sccache)
    cmake_policy(SET CMP0141 NEW)
    set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT Embedded CACHE STRING "" FORCE)
    # Static runtime — avoids VC++ redistributable dependency
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>" CACHE INTERNAL "")
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

# Colored compiler diagnostics
if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    add_compile_options(-fdiagnostics-color=always)
elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    add_compile_options(-fcolor-diagnostics)
endif()

# Tell MSVC to properly report what C++ version is being used
if(MSVC)
    add_compile_options(/Zc:__cplusplus)
endif()

# ==============================================================================
# Sanitizers (opt-in via USE_SANITIZER in .env or -DWITH_ADDRESS_SANITIZER=ON)
# ==============================================================================

option(WITH_ADDRESS_SANITIZER "Enable Address + UndefinedBehavior Sanitizer" OFF)
option(WITH_THREAD_SANITIZER "Enable Thread Sanitizer" OFF)

# Wire .env USE_SANITIZER flag to CMake options
if(DEFINED ENV{USE_SANITIZER} AND "$ENV{USE_SANITIZER}" STREQUAL "TRUE")
    set(WITH_ADDRESS_SANITIZER ON)
endif()

if(WITH_ADDRESS_SANITIZER)
    if(MSVC)
        add_compile_options(/fsanitize=address)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
        link_libraries(-fsanitize=address)
    endif()
    message(WARNING "Address + UndefinedBehavior Sanitizer enabled")
endif()

if(WITH_THREAD_SANITIZER)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        add_compile_options(-fsanitize=thread -g -fno-omit-frame-pointer)
        link_libraries(-fsanitize=thread)
        message(WARNING "Thread Sanitizer enabled")
    endif()
endif()

# ==============================================================================
# Project Configuration
# ==============================================================================

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

# Enable Objective-C/C++ on Apple platforms (needed for Visage + Ninja builds)
if(APPLE)
    enable_language(OBJC)
    enable_language(OBJCXX)
endif()

# ==============================================================================
# Dependencies (FetchContent)
# ==============================================================================

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
    GIT_TAG 0.26.0
    GIT_SHALLOW ON
)

# Fetch Catch2 v3 for unit testing and benchmarks
FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.7.1
    GIT_SHALLOW ON
)

# Melatonin Inspector (opt-in via ENABLE_MELATONIN_INSPECTOR=true in .env)
if(DEFINED ENV{ENABLE_MELATONIN_INSPECTOR} AND "$ENV{ENABLE_MELATONIN_INSPECTOR}" STREQUAL "true")
    FetchContent_Declare(
        melatonin_inspector
        GIT_REPOSITORY https://github.com/sudara/melatonin_inspector.git
        GIT_TAG main
        GIT_SHALLOW ON
    )
    FetchContent_MakeAvailable(JUCE clap-juce-extensions Catch2 melatonin_inspector)
    set(MELATONIN_AVAILABLE TRUE)
    message(STATUS "Melatonin Inspector enabled")
else()
    FetchContent_MakeAvailable(JUCE clap-juce-extensions Catch2)
    set(MELATONIN_AVAILABLE FALSE)
endif()

# ==============================================================================
# Intel IPP (opt-in via ENABLE_IPP=true in .env)
# ==============================================================================
# Provides optimized FFT, FIR/IIR filters, convolution, resampling, vector math.
# Benefits DSP-heavy plugins: convolution reverbs, multi-band EQs, spectral processors.

if(DEFINED ENV{ENABLE_IPP} AND "$ENV{ENABLE_IPP}" STREQUAL "true")
    if(WIN32)
        set(IPP_ROOT "$ENV{USERPROFILE}/.nuget/packages/intelipp.static.win-x64/2022.3.0.387")
        set(IPP_INC "${IPP_ROOT}/build/native/include/ipp")
        set(IPP_LIB "${IPP_ROOT}/build/native/win-x64/")
        set(IPP_LIBS ippsmt ippcoremt ippimt ippcvmt ippvmmt)
    elseif(APPLE)
        # IPP is x86_64 only. For universal builds, use -Xarch_x86_64 to conditionally
        # compile and link IPP only for the x86_64 slice.
        if(CMAKE_OSX_ARCHITECTURES MATCHES "x86_64" OR
           (NOT CMAKE_OSX_ARCHITECTURES AND CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64"))
            FetchContent_Declare(ipp_include
                URL https://files.pythonhosted.org/packages/f0/a0/3b0329735b28f05cbb87ce86be09567a2ecdf9bcd92c50b05fd0a30b34b9/ipp_include-2021.9.1-py2.py3-none-macosx_10_15_x86_64.macosx_11_0_x86_64.whl
                URL_HASH SHA256=5d01a621a9ca758180dffac9677d37ad23759e3c606a376c4bc85adc79a86e6c
            )
            FetchContent_Declare(ipp_static
                URL https://files.pythonhosted.org/packages/fa/19/8b5d54390389b5a9910a111bc033cb0045dc2e1614745c2c98dc54061370/ipp_static-2021.9.1-py2.py3-none-macosx_10_15_x86_64.macosx_11_0_x86_64.whl
                URL_HASH SHA256=d0e1f6643c1e1cf64722dd57b71aaa2692e40406abcecc3c3d575c519326390f
            )
            FetchContent_MakeAvailable(ipp_include ipp_static)

            set(IPP_ROOT "${ipp_include_SOURCE_DIR}")
            set(IPP_INC "${ipp_include_SOURCE_DIR}/ipp_include-2021.9.1.data/data/include")
            set(IPP_LIB "${ipp_static_SOURCE_DIR}/ipp_static-2021.9.1.data/data/lib")
            set(IPP_MACOS TRUE)
        endif()
    elseif(UNIX)
        # Installed via intel-oneapi-ipp-devel package
        set(IPP_ROOT "/opt/intel/oneapi/ipp/latest")
        set(IPP_INC "${IPP_ROOT}/include")
        set(IPP_LIB "${IPP_ROOT}/lib")
        set(IPP_LIBS ipps ippcore ippi ippcv ippvm)
    endif()

    if(DEFINED IPP_ROOT AND IS_DIRECTORY "${IPP_ROOT}")
        message(STATUS "Intel IPP found at ${IPP_ROOT}")
        set(IPP_AVAILABLE TRUE)
    else()
        if(DEFINED IPP_ROOT)
            message(STATUS "Intel IPP not found at ${IPP_ROOT} — skipping")
        endif()
        set(IPP_AVAILABLE FALSE)
    endif()
else()
    set(IPP_AVAILABLE FALSE)
endif()

# ==============================================================================
# Plugin Target
# ==============================================================================

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

# App icon (optional — place a 512x512 or 1024x1024 PNG at Resources/Images/app_icon.png)
set(APP_ICON_PATH "${CMAKE_SOURCE_DIR}/Resources/Images/app_icon.png")
if(NOT EXISTS "${APP_ICON_PATH}")
    set(APP_ICON_PATH "")
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
    ICON_BIG "${APP_ICON_PATH}"
)

juce_generate_juce_header(${PROJECT_NAME})

target_sources(${PROJECT_NAME} PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
)

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_17)

# ==============================================================================
# BinaryData / Assets (opt-in)
# ==============================================================================
# To embed images, fonts, presets, or other assets into your plugin binary,
# uncomment the block below and place files in the assets/ directory.
# Everything in assets/ will be embedded — don't include unused files.
#
# file(GLOB_RECURSE AssetFiles CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/assets/*")
# list(FILTER AssetFiles EXCLUDE REGEX "/\\.DS_Store$")
# juce_add_binary_data(Assets SOURCES ${AssetFiles})
# set_target_properties(Assets PROPERTIES POSITION_INDEPENDENT_CODE TRUE)
#
# Then add "Assets" to the target_link_libraries call below.
# Access in code: BinaryData::filename_ext, BinaryData::filename_extSize

# Plugin compile definitions
target_compile_definitions(${PROJECT_NAME} PUBLIC
    JUCE_VST3_CAN_REPLACE_VST2=0
    JUCE_USE_CURL=0
    JUCE_WEB_BROWSER=0
    JUCE_DISPLAY_SPLASH_SCREEN=0
    # Expose build type to plugin code (e.g., for debug overlays)
    CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}"
    VERSION="${PLUGIN_VERSION}"
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
    # JUCE recommended flags — better warnings, LTO in Release, platform-appropriate config
    juce::juce_recommended_config_flags
    juce::juce_recommended_lto_flags
    juce::juce_recommended_warning_flags
    $<TARGET_NAME_IF_EXISTS:${PROJECT_NAME}_Resources>
)

# Link Melatonin Inspector if enabled
if(MELATONIN_AVAILABLE)
    target_link_libraries(${PROJECT_NAME} PRIVATE melatonin_inspector)
    target_compile_definitions(${PROJECT_NAME} PRIVATE ENABLE_MELATONIN_INSPECTOR=1)
endif()

# Link Intel IPP if available
if(IPP_AVAILABLE)
    target_include_directories(${PROJECT_NAME} PRIVATE "${IPP_INC}")
    if(IPP_MACOS)
        # For universal builds, apply IPP only to x86_64 slice
        target_compile_options(${PROJECT_NAME} PRIVATE "SHELL:-Xarch_x86_64 -DIPP_ENABLED=1")
        target_link_options(${PROJECT_NAME} PRIVATE
            "SHELL:-Xarch_x86_64 -Wl,-L${IPP_LIB},-lipps,-lippi,-lippcv,-lippvm,-lippcore"
        )
    else()
        target_link_directories(${PROJECT_NAME} PRIVATE "${IPP_LIB}")
        target_link_libraries(${PROJECT_NAME} PRIVATE ${IPP_LIBS})
        target_compile_definitions(${PROJECT_NAME} PRIVATE IPP_ENABLED=1)
    endif()
endif()

# Fast math flags (opt-in via ENABLE_FAST_MATH=true in .env)
# WARNING: breaks IEEE 754 compliance. May cause subtle audio artifacts in some algorithms.
if(DEFINED ENV{ENABLE_FAST_MATH} AND "$ENV{ENABLE_FAST_MATH}" STREQUAL "true")
    if(MSVC)
        target_compile_options(${PROJECT_NAME} PRIVATE $<$<CONFIG:RELEASE>:/fp:fast /Ox>)
    else()
        target_compile_options(${PROJECT_NAME} PRIVATE $<$<CONFIG:RELEASE>:-Ofast>)
    endif()
    message(STATUS "Fast math enabled for Release builds")
endif()

# Add CLAP plugin format
clap_juce_extensions_plugin(TARGET "${PROJECT_NAME}"
    CLAP_ID "${PROJECT_BUNDLE_ID}"
    CLAP_FEATURES audio-effect)

# ==============================================================================
# Xcode IDE Organization (macOS only)
# ==============================================================================
if(APPLE)
    # Organize source tree to match filesystem
    file(GLOB_RECURSE AllSourceFiles CONFIGURE_DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/Source/*.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/Source/*.h"
        "${CMAKE_CURRENT_SOURCE_DIR}/Source/*.mm"
    )
    source_group(TREE ${CMAKE_CURRENT_SOURCE_DIR}/Source PREFIX "" FILES ${AllSourceFiles})

    # Tuck plugin format targets into a "Targets" folder and enable Xcode schemes
    foreach(target ${PLUGIN_FORMATS} "All")
        if(TARGET ${PROJECT_NAME}_${target})
            set_target_properties(${PROJECT_NAME}_${target} PROPERTIES
                FOLDER "Targets"
                XCODE_GENERATE_SCHEME ON
            )
        endif()
    endforeach()
endif()

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

                # Phase B: Embed PAT for private repo access (appcast + download auth)
                if(DEFINED ENV{SPARKLE_EMBED_UPDATE_PAT} AND "$ENV{SPARKLE_EMBED_UPDATE_PAT}" STREQUAL "true")
                    if(DEFINED ENV{AUTO_UPDATE_DOWNLOAD_PAT})
                        target_compile_definitions(${PROJECT_NAME}_Standalone PRIVATE
                            AUTO_UPDATE_DOWNLOAD_PAT="$ENV{AUTO_UPDATE_DOWNLOAD_PAT}"
                        )
                        message(STATUS "Auto-update PAT embedded for private repo access")
                    else()
                        message(WARNING "SPARKLE_EMBED_UPDATE_PAT=true but AUTO_UPDATE_DOWNLOAD_PAT not set in .env")
                    endif()
                endif()

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
            set(WINSPARKLE_DIR "${CMAKE_SOURCE_DIR}/external/WinSparkle")

            # Auto-detect architecture for WinSparkle lib path
            if(CMAKE_SIZEOF_VOID_P EQUAL 8)
                if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|aarch64")
                    set(WINSPARKLE_ARCH "arm64")
                else()
                    set(WINSPARKLE_ARCH "x64")
                endif()
            else()
                set(WINSPARKLE_ARCH "x64")
            endif()

            set(WINSPARKLE_LIB "${WINSPARKLE_DIR}/${WINSPARKLE_ARCH}/WinSparkle.lib")

            if(EXISTS "${WINSPARKLE_LIB}")
                message(STATUS "Found WinSparkle at ${WINSPARKLE_DIR} (${WINSPARKLE_ARCH})")

                target_compile_definitions(${PROJECT_NAME}_Standalone PRIVATE ENABLE_WINSPARKLE=1)

                # Pass auto-update config as compile definitions (Windows has no Info.plist)
                if(DEFINED ENV{AUTO_UPDATE_FEED_URL_WINDOWS})
                    target_compile_definitions(${PROJECT_NAME}_Standalone PRIVATE
                        AUTO_UPDATE_FEED_URL="$ENV{AUTO_UPDATE_FEED_URL_WINDOWS}"
                    )
                endif()
                if(DEFINED ENV{AUTO_UPDATE_EDDSA_PUBLIC_KEY})
                    target_compile_definitions(${PROJECT_NAME}_Standalone PRIVATE
                        AUTO_UPDATE_EDDSA_KEY="$ENV{AUTO_UPDATE_EDDSA_PUBLIC_KEY}"
                    )
                endif()

                # Add Windows WinSparkle implementation
                target_sources(${PROJECT_NAME}_Standalone PRIVATE
                    Source/AutoUpdater_Win.cpp
                )

                target_include_directories(${PROJECT_NAME}_Standalone PRIVATE
                    "${WINSPARKLE_DIR}/include"
                )

                target_link_libraries(${PROJECT_NAME}_Standalone PRIVATE
                    "${WINSPARKLE_LIB}"
                )

                # Copy WinSparkle.dll to standalone output directory
                add_custom_command(TARGET ${PROJECT_NAME}_Standalone POST_BUILD
                    COMMAND ${CMAKE_COMMAND} -E copy_if_different
                        "${WINSPARKLE_DIR}/${WINSPARKLE_ARCH}/WinSparkle.dll"
                        "$<TARGET_FILE_DIR:${PROJECT_NAME}_Standalone>/WinSparkle.dll"
                    COMMENT "Copying WinSparkle.dll to ${PROJECT_NAME} Standalone output"
                    VERBATIM
                )
            else()
                message(WARNING "ENABLE_AUTO_UPDATE is true but WinSparkle not found at ${WINSPARKLE_LIB}. Run scripts/setup_winsparkle.sh first.")
            endif()
        elseif(UNIX AND NOT APPLE)
            # Linux: custom appcast polling (no external library needed)
            # Uses JUCE HTTP + XML to check for updates, shows AlertWindow with download link
            target_sources(${PROJECT_NAME}_Standalone PRIVATE
                Source/AutoUpdater_Linux.cpp
            )

            # Pass feed URL as compile definition
            if(DEFINED ENV{AUTO_UPDATE_FEED_URL_LINUX})
                target_compile_definitions(${PROJECT_NAME}_Standalone PRIVATE
                    AUTO_UPDATE_FEED_URL="$ENV{AUTO_UPDATE_FEED_URL_LINUX}"
                )
            elseif(DEFINED ENV{AUTO_UPDATE_FEED_URL})
                target_compile_definitions(${PROJECT_NAME}_Standalone PRIVATE
                    AUTO_UPDATE_FEED_URL="$ENV{AUTO_UPDATE_FEED_URL}"
                )
            endif()
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
# Run tests with:   ctest --test-dir build --verbose
# Or via build.sh:  ./scripts/build.sh all test

# Required for ctest
enable_testing()
set(CTEST_OUTPUT_ON_FAILURE ON)

file(GLOB_RECURSE TestFiles CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/tests/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/tests/*.h"
)

# Organize test sources in IDE
source_group(TREE ${CMAKE_CURRENT_SOURCE_DIR}/tests PREFIX "" FILES ${TestFiles})

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
    JUCE_MODAL_LOOPS_PERMITTED=1
)

# Let test code know if running in CI
if(DEFINED ENV{CI})
    target_compile_definitions(Tests PRIVATE CI=1)
endif()

# Make Tests runnable from Xcode
set_target_properties(Tests PROPERTIES XCODE_GENERATE_SCHEME ON)

# Use the Catch2 CMake module for proper CTest discovery
# PRE_TEST discovery mode fixes Xcode ARM64 issues
include(${Catch2_SOURCE_DIR}/extras/Catch.cmake)
catch_discover_tests(Tests DISCOVERY_MODE PRE_TEST)

# ==============================================================================
# Benchmarks (Catch2 v3)
# ==============================================================================
# Separate from Tests to keep test runs fast.
# Run benchmarks: ctest --test-dir build --verbose -R Benchmark
# Or directly:    ./build/Benchmarks_artefacts/Release/Benchmarks

file(GLOB_RECURSE BenchmarkFiles CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/benchmarks/*.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/benchmarks/*.h"
)

if(BenchmarkFiles)
    source_group(TREE ${CMAKE_CURRENT_SOURCE_DIR}/benchmarks PREFIX "" FILES ${BenchmarkFiles})

    add_executable(Benchmarks ${BenchmarkFiles})
    target_compile_features(Benchmarks PRIVATE cxx_std_17)

    target_include_directories(Benchmarks PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/Source
    )

    target_compile_definitions(Benchmarks PRIVATE
        $<TARGET_PROPERTY:${PROJECT_NAME},COMPILE_DEFINITIONS>
        JUCE_MODAL_LOOPS_PERMITTED=1
    )

    target_link_libraries(Benchmarks PRIVATE
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

    set_target_properties(Benchmarks PROPERTIES XCODE_GENERATE_SCHEME ON)
    catch_discover_tests(Benchmarks DISCOVERY_MODE PRE_TEST)
endif()
