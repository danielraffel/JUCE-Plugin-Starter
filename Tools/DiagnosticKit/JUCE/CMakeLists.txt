cmake_minimum_required(VERSION 3.22)
project(DiagnosticKit VERSION 1.0.0)

# ============================================================================
# Development-only guard: DiagnosticKit is NOT a production release artifact.
# It must be explicitly opted in via -DBUILD_DIAGNOSTICS=ON.
# This prevents accidental inclusion in production installers.
# ============================================================================
option(BUILD_DIAGNOSTICS "Build DiagnosticKit (development/testing only)" OFF)
if(NOT BUILD_DIAGNOSTICS)
    message(STATUS "DiagnosticKit: Skipped (pass -DBUILD_DIAGNOSTICS=ON to build)")
    return()
endif()

# ============================================================================
# macOS uses the native Swift DiagnosticKit — this JUCE app is Windows/Linux only
# ============================================================================
if(APPLE)
    message(STATUS "DiagnosticKit: macOS uses the native Swift app. Skipping JUCE build.")
    return()
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================================
# Platform detection
# ============================================================================
if(MSVC)
    # Use static runtime on Windows for standalone distribution
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

# ============================================================================
# JUCE (shared cache with parent project)
# ============================================================================
include(FetchContent)

# Use same JUCE cache as the parent plugin project
if(DEFINED ENV{HOME})
    set(JUCE_CACHE_DIR "$ENV{HOME}/.juce_cache")
elseif(DEFINED ENV{USERPROFILE})
    set(JUCE_CACHE_DIR "$ENV{USERPROFILE}/.juce_cache")
else()
    set(JUCE_CACHE_DIR "${CMAKE_BINARY_DIR}/_deps")
endif()
file(TO_CMAKE_PATH "${JUCE_CACHE_DIR}" JUCE_CACHE_DIR)
set(FETCHCONTENT_BASE_DIR "${JUCE_CACHE_DIR}")

# Read JUCE_TAG from parent project .env if available
if(EXISTS "${CMAKE_SOURCE_DIR}/../../../.env")
    file(READ "${CMAKE_SOURCE_DIR}/../../../.env" ENV_CONTENT)
    # Match only uncommented JUCE_TAG lines
    string(REGEX MATCH "\nJUCE_TAG=([A-Za-z0-9._-]+)" _ "${ENV_CONTENT}")
    if(CMAKE_MATCH_1)
        string(STRIP "${CMAKE_MATCH_1}" JUCE_TAG)
        string(REPLACE "\"" "" JUCE_TAG "${JUCE_TAG}")
    endif()
endif()
if(NOT JUCE_TAG)
    set(JUCE_TAG "8.0.12")
endif()

FetchContent_Declare(
    juce
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG ${JUCE_TAG}
    GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(juce)

# ============================================================================
# Read config from .env
# ============================================================================
# These get baked into the binary at compile time
if(EXISTS "${CMAKE_SOURCE_DIR}/../.env")
    file(READ "${CMAKE_SOURCE_DIR}/../.env" DIAG_ENV_CONTENT)

    # Normalize line endings for cross-platform regex
    string(REPLACE "\r\n" "\n" DIAG_ENV_CONTENT "${DIAG_ENV_CONTENT}")
    string(REPLACE "\r" "\n" DIAG_ENV_CONTENT "${DIAG_ENV_CONTENT}")

    # Extract values
    string(REGEX MATCH "\nAPP_NAME=\"([^\"\n]+)\"" _ "${DIAG_ENV_CONTENT}")
    if(CMAKE_MATCH_1)
        set(DIAG_APP_NAME "${CMAKE_MATCH_1}")
    else()
        # Try without quotes
        string(REGEX MATCH "\nAPP_NAME=([^\n]+)" _ "${DIAG_ENV_CONTENT}")
        if(CMAKE_MATCH_1)
            string(STRIP "${CMAKE_MATCH_1}" DIAG_APP_NAME)
        else()
            set(DIAG_APP_NAME "Diagnostics")
        endif()
    endif()

    string(REGEX MATCH "\nAPP_IDENTIFIER=\"([^\"\n]+)\"" _ "${DIAG_ENV_CONTENT}")
    if(CMAKE_MATCH_1)
        set(DIAG_BUNDLE_ID "${CMAKE_MATCH_1}")
    else()
        string(REGEX MATCH "\nAPP_IDENTIFIER=([^\n]+)" _ "${DIAG_ENV_CONTENT}")
        if(CMAKE_MATCH_1)
            string(STRIP "${CMAKE_MATCH_1}" DIAG_BUNDLE_ID)
        else()
            set(DIAG_BUNDLE_ID "com.unknown.diagnostics")
        endif()
    endif()
else()
    set(DIAG_APP_NAME "Diagnostics")
    set(DIAG_BUNDLE_ID "com.unknown.diagnostics")
endif()

# ============================================================================
# Application target
# ============================================================================
juce_add_gui_app(DiagnosticKit
    PRODUCT_NAME "${DIAG_APP_NAME}"
    BUNDLE_ID "${DIAG_BUNDLE_ID}"
    COMPANY_NAME "DiagnosticKit"
)

target_sources(DiagnosticKit PRIVATE
    Source/Main.cpp
    Source/MainComponent.cpp
    Source/MainComponent.h
    Source/AppConfig.cpp
    Source/AppConfig.h
    Source/DiagnosticCollector.cpp
    Source/DiagnosticCollector.h
    Source/GitHubUploader.cpp
    Source/GitHubUploader.h
    Source/PlatformDiagnostics.h
    Source/PlatformDiagnostics_Win.cpp
    Source/PlatformDiagnostics_Linux.cpp
)

# Only compile platform-specific files on their platform
if(MSVC)
    set_source_files_properties(
        Source/PlatformDiagnostics_Linux.cpp
        PROPERTIES HEADER_FILE_ONLY TRUE
    )
elseif(UNIX AND NOT APPLE)
    set_source_files_properties(
        Source/PlatformDiagnostics_Win.cpp
        PROPERTIES HEADER_FILE_ONLY TRUE
    )
endif()

target_compile_definitions(DiagnosticKit PRIVATE
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=1
)

target_link_libraries(DiagnosticKit PRIVATE
    juce::juce_gui_extra
    juce::juce_core
    juce::juce_audio_devices
)

# Copy .env next to the executable (Windows/Linux)
if(EXISTS "${CMAKE_SOURCE_DIR}/../.env")
    add_custom_command(TARGET DiagnosticKit POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
            "${CMAKE_SOURCE_DIR}/../.env"
            "$<TARGET_FILE_DIR:DiagnosticKit>/.env"
        COMMENT "Copying .env next to DiagnosticKit executable"
    )
endif()
