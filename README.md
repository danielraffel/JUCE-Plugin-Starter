# JUCE Plugin Starter

## ℹ️ Overview

This is a JUCE plugin starter template using CMake and environment-based configuration for folks new to audio plugin development on macOS. It allows you to create standalone apps and audio plugins (AU, AUv3, VST3, CLAP) for macOS using Xcode. It’s designed for quick setup, ease of customization, and modern JUCE development workflows.

---

### How to Just Give This a Try (Without Reading the Full README)

> This is the fastest way to test-drive the JUCE Plugin Starter. It assumes you have [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12) installed and will:

* ✅ Install all required dependencies (doesn't assume you have git)
* ✅ Clone this repo and set up your environment
* ✅ Run a guided script to create your new plugin repo and push it to GitHub
* ✅ Download JUCE and generate an Xcode project
  
> **Heads up:** This command runs several scripts and installs multiple components. To avoid surprises, it’s a good idea to read through the full README before running it in your terminal. And, to watch the output in the event you're asked to take manual actions.

**Setup Instructions:** Paste the entire section below directly into your terminal.

```bash
# Install required tools (Xcode CLT, Homebrew, CMake, PluginVal, etc.)
bash <(curl -fsSL https://raw.githubusercontent.com/danielraffel/JUCE-Plugin-Starter/main/scripts/dependencies.sh)

# The commands above install software like Homebrew.
# During installation, you may be prompted to add Homebrew to your PATH manually:
# echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
# eval "$(/opt/homebrew/bin/brew shellenv)"

# Clone the starter template
git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter

# Run the interactive setup to create your new plugin project
./scripts/init_plugin_project.sh
```

🎉 **That's it!** The script will:
- Create a **new project folder** with your plugin name
- Copy all template files and customize them
- Initialize a fresh Git repo in your new project
- Optionally create a GitHub repository
- Leave this template untouched for future use

* 👨‍💻 You can now open your **new project folder** in your favorite IDE (Xcode, VS Code, Cursor, Windsurf, etc) and start building your JUCE plugin.

* 🔨 **Build your plugin** using either:
  - **AI Tools**: If you're using Claude Code, it will automatically know how to build and test your plugin
  - **Manual**: Use `./scripts/build.sh standalone local` to quickly test the standalone app
  - **Xcode**: Use `./scripts/generate_and_open_xcode.sh` to generate the Xcode project

* 📖 **See [Enhanced Build System](#-enhanced-build-system) for quick build tips and commands**

> ✅ **Note:** This setup gives you a fully working plugin on your local machine for development and testing.<br>
> 🧳 To share or distribute your plugin to others, you'll need to configure code signing and notarization — when ready see [📦 How to Distribute Your Plugin](#-how-to-distribute-your-plugin) for full instructions.


[📖 Skip to Full Quick Start →](#-quick-start)

---

## 📑 Table of Contents

- [ℹ️ Overview](#ℹ%EF%B8%8F-overview)
  - [How to Just Give This a Try (Without Reading the Full README)](#how-to-just-give-this-a-try-without-reading-the-full-readme)
- [🧰 Prerequisites](#-prerequisites)
  - [System Requirements](#system-requirements)
  - [Additional Dependencies](#additional-dependencies)
    - [Automated Dependency Setup](#automated-dependency-setup)
    - [Manual Dependency Setup](#manual-dependency-setup)
- [🚀 Quick Start](#-quick-start)
  - [1. Clone the JUCE Plugin Starter Template](#1-clone-the-juce-plugin-starter-template)
  - [2. Create Your Plugin Project](#2-create-your-plugin-project)
  - [3. Build Your Plugin](#3-build-your-plugin)
- [🔧 Advanced: Manual Environment Configuration](#-advanced-manual-environment-configuration)
  - [🔄 Auto-Loaded Settings](#-auto-loaded-settings)
  - [📝 How It Works](#-how-it-works)
  - [⚙️ Manual Setup (Optional)](#️-manual-setup-optional)
- [🧱 Build Targets](#-build-targets)
- [📍 Where Files Are Generated (Plugins + App)](#where-files-are-generated-plugins--app)
  - [Where Plugin Files Are Installed](#where-plugin-files-are-installed)
- [🔄 Auto-Versioning Plugin Builds in Logic Pro](#auto-versioning-plugin-builds-in-logic-pro)
- [📁 Customize Your Plugin](#-customize-your-plugin)
- [🛠️ How to Edit `CMakeLists.txt`](#️-how-to-edit-cmakeliststxt)
  - [🔧 Common Edits](#-common-edits)
    - [✅ Add Source Files](#-add-source-files)
    - [✅ Add JUCE Modules](#-add-juce-modules)
    - [✅ Change Output Formats](#-change-output-formats)
    - [✅ Add Preprocessor Macros](#-add-preprocessor-macros)
    - [✅ Set Minimum macOS Deployment Target](#-set-minimum-macos-deployment-target)
- [📦 Project File Structure](#-project-file-structure)
  - [About the JUCE cache location](#about-the-juce-cache-location)
- [🧪 Unit Testing with Catch2](#-unit-testing-with-catch2)
- [🎨 Code Style](#-code-style)
- [💡 Tips](#-tips)
  - [🔁 Building with AI Tools](#-building-with-ai-tools)
    - [Using with Cursor](#using-with-cursor)
    - [Using with Alex Sidebar](#using-with-alex-sidebar)
    - [Using with Claude Code](#using-with-claude-code)
- [📦 How to Distribute Your Plugin](#-how-to-distribute-your-plugin)
  - [🛠️ Requirements](#️-requirements)
    - [✅ Apple Developer Program Membership](#-apple-developer-program-membership)
    - [✅ Code Signing Certificates](#-code-signing-certificates)
    - [📥 How to Generate and Install Certificates](#-how-to-generate-and-install-certificates)
    - [🔍 How to Verify They're Installed](#-how-to-verify-theyre-installed)
    - [✅ App-Specific Password for Notarization](#-app-specific-password-for-notarization)
  - [⚙️ Distribution-Specific Environment Variables](#️-distribution-specific-environment-variables)
  - [🎛️ What Gets Packaged](#️-what-gets-packaged)
  - [🚀 Run the Distribution Script](#-run-the-distribution-script)
- [🤖 AI-Assisted Development Prompts](#-ai-assisted-development-prompts)
  - [What's Included](#whats-included)
  - [How to Use](#how-to-use)
  - [Why Use Prompts?](#why-use-prompts)
  - [Contributing Prompts](#contributing-prompts)
- [📚 Resources](#-resources)

---

## 🧰 Prerequisites

To build and develop plugins with this template, you’ll need:

### System Requirements
- macOS 15.0 or later
- [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12) (latest version)
- Recommended: Additional IDE with Support for 3rd Party AI Models ([Alex Sidebar](http://alexcodes.app), [Cursor](http://cursor.com), [Windsurf](http://windsurf.com), [Trae](http://trae.ai), or [VSCode](https://code.visualstudio.com))

---

### Additional Dependencies

Before building the project, you need to install several development tools.

You can choose **one of the following setup methods**:

- [Automated Dependency Setup](#automated-dependency-setup) — Recommended for most users.
- [Manual Dependency Setup](#manual-dependency-setup) — For those who prefer full control.

---

#### Automated Dependency Setup

Use the included [`dependencies.sh`](./scripts/dependencies.sh) script. It **checks for each required tool** and **installs it automatically if missing**. This is typically needed only for a **first-time setup**.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/danielraffel/JUCE-Plugin-Starter/main/scripts/dependencies.sh)
```

The script handles:

* ✅ **Xcode Command Line Tools**
* ✅ **Homebrew**
* ✅ **CMake**
* ✅ **PluginVal**

It also includes **optional installs**, commented out by default:

* **Faust** – DSP prototyping compiler
* **GoogleTest** – C++ unit testing
* **Python 3**, **pip3**, and **behave** – for behavior-driven development (BDD)

> ✏️ When you run `dependencies.sh` software like Homebrew may ask you to do additonal configurations to complete your setup:
```
# During installation, you may be prompted to add Homebrew to your PATH manually:
# echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
# eval "$(/opt/homebrew/bin/brew shellenv)"
```

> ✏️ To enable optional tools, simply **uncomment** the relevant lines in the script.

---

#### Manual Dependency Setup

If you prefer, you can install all required tools manually:

| Tool                                      | Purpose                          | Manual Install Command                                                                            |
| ----------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Xcode Command Line Tools**              | Xcode compiler & tools           | `xcode-select --install`                                                                          |
| **CMake**                                 | Build system configuration       | `brew install cmake`                                                                              |
| **Homebrew**                              | macOS package manager            | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| **PluginVal**                             | Plugin validation & testing      | `brew install --cask pluginval`                                                                   |
| **Faust** *(optional)*                    | DSP prototyping compiler         | `brew install faust`                                                                              |
| **Catch2** *(built-in)*                   | C++ unit testing (included via FetchContent) | No install needed — fetched automatically by CMake                                                |
| **Python 3 + behave** *(optional)*        | Natural language test automation | `brew install python && pip3 install behave`                                                      |
| **[JUCE](https://juce.com)**              | Audio plugin framework (AU/AUv3/VST3/CLAP) | No install needed — fetched automatically by CMake                                                          |

---

## 🚀 Quick Start

### 1. Clone the JUCE Plugin Starter Template

```bash
git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter
```

> 💡 This is just the template - you'll create your actual project in the next step!

---

### 2. Create Your Plugin Project

Run the interactive setup script to create your new plugin project:
```bash
./scripts/init_plugin_project.sh
```

The script will guide you through:
* 🎵 **Plugin name** - What your plugin will be called
* 🏢 **Developer info** - Your name/company details  
* 📦 **Bundle ID** - Smart generation from your developer name
* 🐙 **GitHub integration** - Optional repository creation
* 🍎 **Apple Developer settings** - For future code signing (optional)

**What happens:**
* 📁 **Creates new project folder** - `../your-plugin-name/` with all template files
* 🎨 **Customizes all code** - Replaces placeholders with your actual plugin name and details
* 🔧 **Sets up build system** - Makes all scripts executable and ready to use
* 🗂️ **Fresh Git repository** - Initializes clean git history in your new project
* 🐙 **GitHub integration** - Optionally creates and pushes to a new GitHub repo
* ✨ **Template preserved** - Original template stays intact for future projects

**Result:** You'll have a complete, buildable JUCE plugin in a new folder, ready to customize!

---

### 3. Build Your Plugin

**Change to your new project directory first:**
```bash
cd ../your-plugin-name  # Use the actual folder name created in step 2
```

Then build using one of these methods:

**🤖 AI Tools (Recommended):**
If using Claude Code, it automatically knows how to build and test your plugin.

**🔨 Quick Build & Test:**
```bash
./scripts/build.sh standalone local  # Build and launch standalone app
```

**🎯 Xcode Development:**
```bash
./scripts/generate_and_open_xcode.sh  # Generate and open Xcode project
```

> 💡 **First time setup**: When you first build, CMake will automatically download JUCE. This may take a few minutes on the first run.

---

## 🔧 Advanced: Manual Environment Configuration

The `init_plugin_project.sh` script automatically loads certain developer settings from your template's `.env` file to speed up project creation. 

### 🔄 Auto-Loaded Settings

If you have a `.env` file in your template directory, the script will automatically load these **reusable developer settings**:

| Setting | Purpose | Auto-Loaded |
|---------|---------|-------------|
| `DEVELOPER_NAME` | Your name/company | ✅ |
| `APPLE_ID` | Apple Developer account | ✅ |  
| `TEAM_ID` | Apple Developer Team ID | ✅ |
| `APP_CERT` | Code signing certificate | ✅ |
| `INSTALLER_CERT` | Installer signing certificate | ✅ |
| `APP_SPECIFIC_PASSWORD` | Notarization password | ✅ |
| `GITHUB_USER` | GitHub username | ✅ |

### 📝 How It Works

1. **Smart Loading**: Only loads values that differ from defaults
2. **Placeholder Filtering**: Skips placeholder values like "Your Name" or "yourusername"  
3. **Confirmation Only When Needed**: You'll only see "Is this correct?" if the loaded value differs from the template default
4. **Project-Specific Settings**: Things like `PROJECT_NAME` and `PROJECT_BUNDLE_ID` are always configured fresh for each project

### ⚙️ Manual Setup (Optional)

Want to pre-configure your developer settings? 

1. **Copy the template**: `cp .env.example .env` in your template directory
2. **Edit your settings**: Update `DEVELOPER_NAME`, `GITHUB_USER`, Apple Developer info, etc.
3. **Keep placeholders**: Leave project-specific settings as placeholders
4. **Run script**: `./scripts/init_plugin_project.sh` will now use your settings

> 💡 **Tip**: Check `.env.example` - it has clear sections showing which settings are auto-loaded vs. project-specific!

---

## 🧱 Build Targets

Once the project is open in Xcode, you can build:

* ✅ **Standalone App**
* ✅ **Audio Unit v2 (AU)** – for Logic Pro, GarageBand
* ✅ **Audio Unit v3 (AUv3)** – app extension format, also works on iOS
* ✅ **VST3 Plugin** – for Reaper, Ableton Live, etc.
* ✅ **CLAP Plugin** – for Bitwig, Reaper, and other CLAP-compatible DAWs

> Switch targets using the Xcode scheme selector.
>
<img width="352" alt="image" src="https://github.com/user-attachments/assets/4c3c3ac7-0613-46dc-a6b0-286743b858be" />

> Make sure the `FORMATS AU AUv3 VST3 Standalone` line is present in `CMakeLists.txt`. CLAP is added separately via `clap-juce-extensions`.

---
## Where Files Are Generated (Plugins + App)

### Where Plugin Files Are Installed

When you build your plugin from Xcode, the following file types are generated and installed in the standard macOS plugin locations:
- Audio Unit (AU) Component:
```
~/Library/Audio/Plug-Ins/Components/YourPlugin.component
```
- VST3 Plugin:
```
~/Library/Audio/Plug-Ins/VST3/YourPlugin.vst3
```
- CLAP Plugin:
```
~/Library/Audio/Plug-Ins/CLAP/YourPlugin.clap
```
- AUv3 App Extension:
```
Found inside your build folder in PROJECT_NAME_artefacts/AUv3/YourPlugin.appex
```
- Standalone App:
```
Found inside your build folder in your `PROJECT_NAME_artefacts` debug or release folder.
```

These paths are standard for macOS plugin development and are used by DAWs like Logic Pro, Ableton Live, Reaper, etc.

---

## Auto-Versioning Plugin Builds in Logic Pro

This template includes a post-build script (`scripts/post_build.sh`) that automatically versions your plugin bundle after each build, ensuring Logic Pro correctly reloads the updated component.

**How Versioning Works:**

- The base version is set in your `.env` file with `BASE_PROJECT_VERSION`. By default, it's:
  ```
  BASE_PROJECT_VERSION="1.0."
  ```
  You can edit this value to manage your major/minor version. The script will always append a build timestamp to ensure each build is unique.

- After each build, the script:
  - Reads `BASE_PROJECT_VERSION` from `.env` (or uses a default if not found).
  - Appends a timestamp to generate a unique version (e.g., `1.0.2505302321`).
  - Updates your plugin’s `Info.plist` with:
    - `CFBundleShortVersionString` = base version (e.g., `1.0.`)
    - `CFBundleVersion` = base version + timestamp (e.g., `1.0.2505302321`)
  - Only the full (timestamped) version is visible in the `Info.plist`, not in the plugin UI.

- The script is triggered from your CMake build with:
  ```cmake
  add_custom_command(TARGET ${PROJECT_NAME}_AU
      POST_BUILD
      COMMAND "${CMAKE_SOURCE_DIR}/scripts/post_build.sh" "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}_AU>"
      COMMENT "Updating Info.plist version for ${PROJECT_NAME}_AU"
      VERBATIM
  )
  ```

**What This Solves:**
- Ensures Logic Pro re-recognizes your Audio Unit after every build
- Prevents stale cache/version issues
- Keeps development iterative and frustration-free

**How to Manage Versions:**
- Edit `.env` and change `BASE_PROJECT_VERSION` (e.g., bump from `1.0.` to `1.1.` for a new feature).
- The timestamp is always unique per build, so you don't have to manage patch versions manually.
- The timestamped build version is only visible in the plugin's `Info.plist`, not in the UI.

**Customization:**
- You can modify `scripts/post_build.sh` to change how versions are generated or update which fields are set in `Info.plist`.

---

## 📁 Customize Your Plugin

Edit the files in `Source/`:

* `PluginProcessor.cpp / .h` – DSP and audio engine
* `PluginEditor.cpp / .h` – UI layout and interaction

Add more `.cpp/.h` files as needed for a modular architecture.

---

## 🛠️ How to Edit `CMakeLists.txt`

Your `CMakeLists.txt` is where the plugin’s structure and build config live. Open it with any code editor.

All CMake configuration is centralized in the top-level `CMakeLists.txt` file. If you need to:

* Add source files
* Link dependencies
* Define feature flags
* Toggle plugin modes
* Set test builds

Then this is where to do it.

🕒 **Tip**: If you only modified non-CMake files and want a quicker build, you can skip regeneration using:

```bash
SKIP_CMAKE_REGEN=1 ./scripts/generate_and_open_xcode.sh
```

Otherwise, always use:

```bash
./scripts/generate_and_open_xcode.sh
```

If you're [developing using an agent like Claude Code](#using-with-claude-code) it will determine which build approach is best using instructions in the `CLAUDE.md` in this repository.

### 🔧 Common Edits

#### ✅ Add Source Files

```cmake
target_sources(${PROJECT_NAME} PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginEditor.cpp
    Source/MyFilter.cpp
    Source/MyFilter.h
)
```

#### ✅ Add JUCE Modules

```cmake
target_link_libraries(${PROJECT_NAME} PRIVATE
    juce::juce_audio_utils
    juce::juce_graphics
    juce::juce_osc       # <-- newly added module
)
```

#### ✅ Change Output Formats

```cmake
FORMATS AU AUv3 VST3 Standalone
```

> **Note:** CLAP format is added separately via `clap-juce-extensions` (already configured in CMakeLists.txt).

To skip a format, just remove it:

```cmake
FORMATS VST3 Standalone
```

#### ✅ Add Preprocessor Macros

```cmake
target_compile_definitions(${PROJECT_NAME} PRIVATE
    USE_MY_DSP_ENGINE=1
)
```

#### ✅ Set Minimum macOS Deployment Target

To ensure your project builds against a specific minimum macOS version, set the CMAKE_OSX_DEPLOYMENT_TARGET before defining the project in your CMakeLists.txt.

```cmake
# Set minimum macOS version before defining the project
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum macOS version")
```

> After making changes, just re-run:

```bash
./scripts/generate_and_open_xcode.sh
```

---

## 📦 Project File Structure

```
JUCE-Plugin-Starter/
├── .env.example                   ← Template for your environment variables
├── CLAUDE.md                      ← Project details for Claude Code
├── CMakeLists.txt                 ← Main build config for your JUCE project
├── README.md                      ← You're reading it
├── prompts/                       ← AI assistant prompts for common features
│   ├── README.md                  ← Guide for using prompts
│   ├── audio-midi-settings-prompt.md
│   └── lfo-modulation-prompt.md
├── scripts/                       ← Automation / helper scripts
│   ├── about/                     ← Documentation
│   │   └── build_system.md        ← Comprehensive build system documentation
│   ├── build.sh                   ← Unified build system (local, test, sign, notarize, publish)
│   ├── bump_version.py            ← Semantic version management
│   ├── dependencies.sh            ← Automated dependency setup
│   ├── diagnose_plugin.sh         ← Plugin diagnostic tool
│   ├── generate_and_open_xcode.sh ← Script that loads `.env`, runs CMake, and opens Xcode
│   ├── generate_release_notes.py  ← AI-powered release notes generator
│   ├── init_plugin_project.sh     ← Script that reinitializes this repo to make it yours
│   ├── post_build.sh              ← Enhanced version handling with semantic versioning
│   └── validate_plugin.sh         ← Plugin validation tool
├── .clang-format                  ← JUCE-style code formatting rules
├── Source/                        ← Your plugin source code
│   ├── PluginProcessor.cpp/.h
│   └── PluginEditor.cpp/.h
├── tests/                         ← Catch2 unit tests
│   ├── Catch2Main.cpp             ← Custom main with JUCE init
│   ├── PluginBasics.cpp           ← Example plugin tests
│   └── helpers/test_helpers.h     ← Test utilities
└── build/                         ← Generated by CMake (can be deleted anytime)
    └── YourPlugin.xcodeproj       ← Generated Xcode project

~/.juce_cache/                     ← Shared JUCE location (outside project)
└── juce-src/                      ← JUCE framework (shared across all projects)
```

### About the JUCE cache location:

* ✅ Shared across projects: Multiple JUCE projects use the same download
* ✅ Survives build cleaning: rm -rf build won't delete JUCE
* ✅ Version controlled: Different projects can use different JUCE versions via JUCE_TAG


>💡 You can safely `rm -rf` build without re-downloading JUCE every time.

---

## 🔨 Enhanced Build System

This template now includes a unified build system (`scripts/build.sh`) that provides comprehensive functionality:

### Quick Build Commands

```bash
# Quick local build (all formats)
./scripts/build.sh

# Build specific format
./scripts/build.sh au          # Audio Unit v2 only
./scripts/build.sh auv3        # Audio Unit v3 only
./scripts/build.sh vst3        # VST3 only
./scripts/build.sh clap        # CLAP only
./scripts/build.sh standalone  # Standalone app only

# Build multiple formats in one command
./scripts/build.sh au vst3              # Build both AU and VST3
./scripts/build.sh au standalone        # Build AU and Standalone
./scripts/build.sh au vst3 test         # Build AU and VST3, then test both

# Build with testing (Catch2 unit tests + PluginVal validation)
./scripts/build.sh all test    # Build and run all tests

# Fast development workflow
./scripts/build.sh uninstall            # Uninstall all plugin components
./scripts/build.sh unsigned             # Build unsigned installer (fast testing)
./scripts/build.sh uninstall && ./scripts/build.sh unsigned  # Quick rebuild cycle

# Production builds
./scripts/build.sh all sign     # Build and codesign
./scripts/build.sh all notarize # Build, sign, and notarize
./scripts/build.sh all pkg      # Build, sign, notarize PKG (no GitHub release)
./scripts/build.sh all publish  # Full release with installer and GitHub publishing
```

### New Build Actions

**`uninstall`** - Quickly remove all plugin components for clean reinstallation:
```bash
./scripts/build.sh uninstall
```
- Removes plugins (AU, VST3, Standalone, Diagnostics)
- Clears AU cache
- Non-interactive mode for dev workflows
- Perfect for clean rebuilds

**`unsigned`** - Create unsigned installer for fast testing:
```bash
./scripts/build.sh unsigned
```
- Skips code signing (~2-3 minutes saved)
- Skips notarization (~5-10 minutes saved)
- Great for testing installer structure
- **For testing only** - not for distribution

**`pkg`** - Build production package without GitHub release:
```bash
./scripts/build.sh all pkg
```
- Full signing and notarization
- Creates distributable PKG installer
- No GitHub release created
- Perfect for manual distribution or beta testing

### Automatic Version Management

- **Semantic Versioning**: Automatic version bumping with `scripts/bump_version.py`
- **Build Integration**: Versions are automatically managed during builds
- **Manual Control**: Bump major/minor versions manually when needed

```bash
python3 scripts/bump_version.py minor  # 0.0.3 → 0.1.0
python3 scripts/bump_version.py major  # 0.1.0 → 1.0.0
```

### Additional Tools

- **Plugin Validation**: `./scripts/validate_plugin.sh` - Comprehensive plugin validation
- **Diagnostic Tool**: `./scripts/diagnose_plugin.sh` - Troubleshoot plugin issues
- **AI Release Notes**: `./scripts/generate_release_notes.py` - Generate release notes from git history

### Complete Documentation

For comprehensive build system documentation, see [`scripts/about/build_system.md`](scripts/about/build_system.md).

---

## 🧪 Unit Testing with Catch2

This template includes [Catch2 v3](https://github.com/catchorg/Catch2) for unit testing, fetched automatically via CMake's FetchContent.

### Test Structure

```
tests/
├── Catch2Main.cpp          # Custom main with JUCE MessageManager initialization
├── PluginBasics.cpp        # Example plugin tests
└── helpers/
    └── test_helpers.h      # Helper for running tests with an active plugin editor
```

### Running Tests

```bash
# Run all tests (Catch2 unit tests + PluginVal validation)
./scripts/build.sh all test

# This will:
# 1. Build all plugin formats
# 2. Build the Catch2 Tests target
# 3. Run Catch2 unit tests
# 4. Run PluginVal validation on AU and VST3
```

### Writing Tests

Add new test files to `tests/`. They're automatically discovered via CMake's `GLOB_RECURSE`.

```cpp
#include <PluginProcessor.h>
#include <catch2/catch_test_macros.hpp>

TEST_CASE ("My feature works", "[feature]")
{
    PluginProcessor plugin;
    // Test your plugin logic
    CHECK (plugin.getName().isNotEmpty());
}
```

For tests that need the plugin editor, use the helper:

```cpp
#include "helpers/test_helpers.h"

TEST_CASE ("Editor renders", "[editor]")
{
    runWithinPluginEditor ([] (PluginProcessor& plugin) {
        REQUIRE (plugin.getActiveEditor() != nullptr);
    });
}
```

---

## 🎨 Code Style

This template includes a `.clang-format` file with JUCE-style conventions:

- **Brace style**: Allman (opening brace on new line), except for lambdas
- **Indent**: 4 spaces, no tabs
- **Column limit**: None (no line wrapping)
- **Standard**: C++17
- **ObjC**: Separate section for Objective-C++ files

Most IDEs (Xcode, VS Code, CLion) will automatically pick up `.clang-format` for code formatting.

---

## 📁 Smart /Applications Organization

The build system automatically organizes installed applications to keep your /Applications folder clean:

### Single App Installation
If you only build the **standalone app**, it installs directly:
```
/Applications/
└── YourPlugin.app
```

### Multiple Apps Installation
If you build **2 or more components** (e.g., standalone + diagnostics + uninstaller), they're organized in a folder:
```
/Applications/
└── YourPlugin/
    ├── YourPlugin.app
    ├── YourPlugin Diagnostics.app
    └── YourPlugin Uninstaller.command
```

### How It Works
- The installer automatically counts apps during PKG creation
- **1 app** → Direct installation
- **2+ apps** → Folder installation
- The uninstaller auto-detects which method was used
- No manual configuration needed

This keeps your /Applications folder clean while making multi-component plugins easy to find and manage.

---

## 🌐 Auto-Download Landing Page

When you publish your first release with `./scripts/build.sh publish` (or `./scripts/build.sh all publish`), the build system automatically:

1. **Generates an index.html landing page** from `templates/index.html.template`
2. **Publishes it to GitHub Pages** (automatically enabled via GitHub API)
3. **Creates a shareable URL** that always fetches the latest release

### How It Works

**First Publish**:
```bash
./scripts/build.sh publish
```
- Generates `index.html` from template
- Commits to your main branch
- Enables GitHub Pages
- Page goes live at `https://<your-github-username>.github.io/<your-plugin-repo>/`

**Subsequent Publishes**:
```bash
./scripts/build.sh publish
```
- Detects existing `index.html`
- Skips regeneration (saves time)
- Page automatically fetches latest release via JavaScript API

**The page is smart**: It uses JavaScript to query GitHub's API for the latest release, so it always shows the current version without needing updates!

### Features
- 🚀 Auto-downloads PKG installer when page loads
- 📦 Shows manual download links for PKG, DMG, and ZIP
- 📊 Displays file sizes dynamically
- 🔄 Fetches latest release via GitHub API (no page updates needed!)
- 🎨 Includes Open Graph and Twitter Card meta tags for rich social sharing
- 📱 Responsive, Apple-style design

### Your Landing Page URL
```
https://<your-github-username>.github.io/<your-plugin-repo>/
```

### Updating the Page Design

If you need to update the page design or fix issues:

```bash
./scripts/build.sh publish --regenerate-page
```

This forces regeneration of `index.html` from the template.

### Social Sharing
Add a 1200x630px image named `YourPlugin.png` to your repo root for rich previews in:
- iMessage
- Slack
- Discord
- Twitter/X
- LinkedIn

### Template Customization
Edit `templates/index.html.template` to customize:
- `{{PROJECT_NAME}}` - Plugin name
- `{{PLUGIN_DESCRIPTION}}` - Brief description (set `PLUGIN_DESCRIPTION` in `.env`)
- `{{GITHUB_USER}}` - Your GitHub username
- `{{GITHUB_REPO}}` - Repository name

The template is automatically processed during the first `publish` and committed to your main branch.

---

## 🩺 DiagnosticKit Integration (Optional)

DiagnosticKit is an optional macOS app that helps your users submit diagnostic reports when they encounter issues.

### Features
- **One-click diagnostic collection** - System info, plugin status, crash logs
- **GitHub issue creation** - Submits reports to a private repository
- **No Terminal needed** - Simple GUI for non-technical users
- **Privacy-conscious** - Only collects troubleshooting data
- **Project-agnostic** - Template system works with any plugin

### Setup

#### 1. Enable During Project Creation
When running `./scripts/init_plugin_project.sh`, answer "yes" to:
```
Would you like to include DiagnosticKit in this project? (y/n)
```

#### 2. Configure GitHub Repository
The setup script will create a private repository for diagnostic reports:
```bash
./scripts/setup_diagnostic_repo.sh
```

This script will:
- Verify GitHub CLI is installed and authenticated
- Create a private `<your-plugin>-diagnostics` repository
- Guide you through creating a GitHub Personal Access Token (PAT)
- Configure the PAT in your `.env` file

#### 3. Create GitHub Personal Access Token
The script will guide you, but here's what you need:
1. Go to https://github.com/settings/tokens?type=beta
2. Click "Generate new token"
3. Configure:
   - **Token name**: `<YourPlugin> Diagnostics`
   - **Expiration**: 1 year (or custom)
   - **Repository access**: Only select repositories
   - **Selected repositories**: `<your-plugin>-diagnostics`
4. **Permissions**:
   - **Issues**: Read and Write (REQUIRED)
   - **Metadata**: Read (auto-selected)
5. Generate and copy the token

#### 4. Build Your Plugin
DiagnosticKit is automatically built when `ENABLE_DIAGNOSTICS=true` in your `.env`:
```bash
./scripts/build.sh all
```

The diagnostics app will be included in your installers.

### What Users See
When users run the diagnostics app, they can:
1. Optionally describe their issue
2. Click "Collect & Submit Diagnostic"
3. Review the GitHub issue URL
4. Open the issue in their browser

The diagnostic report includes:
- macOS version and hardware
- Plugin installation status (AU, VST3, Standalone)
- Recent crash logs (if any)
- Audio Unit validation results
- User's description of the issue

### Privacy
DiagnosticKit collects only troubleshooting data:
- ✅ System version and hardware model
- ✅ Plugin file locations and dates
- ✅ Crash logs (from ~/Library/Logs/DiagnosticReports)
- ✅ Audio device list
- ❌ No personal files or data
- ❌ No browsing history or passwords

### File Locations
```
Tools/DiagnosticKit/
├── .env.example                    # Configuration template
├── Package.swift                   # Swift Package Manager config
├── DiagnosticKit.entitlements      # macOS sandbox permissions
├── Scripts/
│   └── build_app.sh               # Build script
└── Sources/
    ├── DiagnosticApp.swift        # Main entry point
    ├── Config/
    │   └── AppConfig.swift        # Configuration loader
    ├── Services/
    │   ├── DiagnosticCollector.swift   # Data collection
    │   └── GitHubUploader.swift        # GitHub API
    └── Views/
        └── MainView.swift         # SwiftUI interface
```

### Troubleshooting

**DiagnosticKit not building?**
```bash
# Verify setup is complete
./scripts/setup_diagnostic_repo.sh --check-only

# Rebuild from scratch
rm -rf Tools/DiagnosticKit/build
./scripts/build.sh all
```

**Want to disable DiagnosticKit?**
Set in your `.env`:
```bash
ENABLE_DIAGNOSTICS=false
```

---

## 💡 Tips

### 🔁 Building with AI Tools

#### Using with Cursor 

The `generate_and_open_xcode.sh` script includes a line that automatically opens the generated Xcode project. Since Cursor doesn’t require this, I strongly recommend commenting out the following section:

```bash
# Open the generated Xcode project
if [ -d "$XCODE_PROJECT" ]; then
  open "$XCODE_PROJECT"
else
  echo "Xcode project not found: $XCODE_PROJECT"
  exit 1
fi
```


#### Using with Alex Sidebar
To use `generate_and_open_xcode.sh` with [AlexCodes.app](https://alexcodes.app), I've found the following project prompt helpful for managing when and how the Xcode project is compiled and opened:

```text
Whenever the Xcode project file needs to be regenerated use run_shell to execute $PROJECT_PATH/scripts/generate_and_open_xcode.sh
```

<img width="515" alt="regenerate-xcode-alexcodes" src="https://github.com/user-attachments/assets/158b6005-645f-410a-9fdb-51ef9479ac55" />


#### Using with Claude Code
To use `generate_and_open_xcode.sh` with [Claude Code](https://www.anthropic.com/claude-code), I've created a [CLAUDE.md](CLAUDE.md) and added it to the root of the repo. It instructs the agent how and when to properly recreate the project file. It can help you build and run the project by invoking the proper script:

```bash
./scripts/generate_and_open_xcode.sh
```

**Claude will determine whether a full regeneration is needed based on recent file changes or build errors.**. The [CLAUDE.md](CLAUDE.md) explains when it's best to regenerate the Xcode project and how to optionally skip regeneration for faster builds using:

```bash
SKIP_CMAKE_REGEN=1 ./scripts/generate_and_open_xcode.sh
```

---

## 📦 How to Distribute Your Plugin

Once your plugin is built and tested, you can package it for safe, notarized distribution via Apple's system using the unified build system.

> 💭 Interested in more details? [Check out this walkthrough on macOS audio plug-in code signing and notarization](https://melatonin.dev/blog/how-to-code-sign-and-notarize-macos-audio-plugins-in-ci/).

---

### 🛠️ Requirements

#### ✅ Apple Developer Program Membership

- Join at [developer.apple.com/programs](https://developer.apple.com/programs)

#### ✅ Code Signing Certificates

You’ll need two certificates installed in **Keychain Access** (login keychain):

1. **Developer ID Application**
2. **Developer ID Installer**

> These allow Apple to verify your identity and authorize your software for distribution.

---

#### 📥 How to Generate and Install Certificates

1. Go to [Apple Developer Certificates Portal](https://developer.apple.com/account/resources/certificates)
2. Click ➕ “Create Certificate”
3. Choose:
   - `Developer ID Application`
   - `Developer ID Installer`
4. Follow Apple’s steps to:
   - Create a Certificate Signing Request (CSR) using Keychain Access
   - Download the signed certificate
   - Double-click it to install into your Keychain

---

#### 🔍 How to Verify They're Installed

In Terminal, run:

```bash
security find-identity -v -p codesigning
```

You should see both listed, like:

```
  1) A1B2C3D4E5... "Developer ID Application: Your Name (TEAMID)"
  2) F6G7H8I9J0... "Developer ID Installer: Your Name (TEAMID)"
```

Make note of the exact names — you'll reference these in your `.env` file.

---

#### ✅ App-Specific Password for Notarization

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Under **Sign-In and Security**, click **App-Specific Passwords**
3. Click ➕ "Generate App-Specific Password" and consider using your project name as the identifier
4. Make sure to store this password safely — it’s required for every notarization and must be added to your .env

---

### ⚙️ Distribution-Specific Environment Variables

Add these values to your main `.env` file:

```env
# Notarization credentials
APPLE_ID=your@email.com
APP_SPECIFIC_PASSWORD=abcd-efgh-ijkl-mnop
APP_CERT="Developer ID Application: Your Name (TEAM_ID)"
INSTALLER_CERT="Developer ID Installer: Your Name (TEAM_ID)"
TEAM_ID=YOUR_TEAM_ID
```

> 💡 Always make sure your `.env` file is listed in `.gitignore` to avoid exposing credentials.

---

### 🎛️ What Gets Packaged

The build system will automatically detect and package the following plugin formats if they exist:

| Format | Extension    | Path |
|--------|--------------|------|
| AU     | `.component` | `~/Library/Audio/Plug-Ins/Components/` |
| AUv3   | `.appex`     | Bundled in build artefacts |
| VST3   | `.vst3`      | `~/Library/Audio/Plug-Ins/VST3/` |
| CLAP   | `.clap`      | `~/Library/Audio/Plug-Ins/CLAP/` |
| AAX    | `.aaxplugin` | `/Library/Application Support/Avid/Audio/Plug-Ins/` |

- The script signs, notarizes, and staples each format (if found)
- All formats are bundled into a **single `.pkg` installer**
- The `.pkg` is signed and notarized
- Finally, the `.pkg` is included in a **ready-to-share `.dmg`**

> 💡 **Missing formats are skipped**, but the script will print a warning if none are found and exit gracefully.

---

### 🚀 Run the Distribution Script

From your project root:

```bash
./scripts/build.sh all publish
```

This command will:

- ✅ Build all plugin formats
- ✅ Sign and notarize your plugins
- ✅ Create a signed `.pkg` installer and notarize it
- ✅ Bundle it into a distributable `.dmg`
- ✅ Create a GitHub release with all artifacts

> 📂 Output files (`.zip`, `.pkg`, `.dmg`) will be saved to your Desktop for easy sharing.

---

## 🤖 AI-Assisted Development Prompts

The `prompts/` folder contains ready-to-use prompts for common plugin features that you can use with AI coding assistants like Claude Code, Cursor, GitHub Copilot, or ChatGPT.

### What's Included

These prompts are designed to help you quickly implement common plugin features:

- **Audio/MIDI Settings** (`audio-midi-settings-prompt.md`) - Add comprehensive audio device and MIDI routing settings to your plugin
- **LFO & Modulation System** (`lfo-modulation-prompt.md`) - Implement a flexible LFO system with multiple waveforms and modulation targets

### How to Use

1. **Choose a feature** - Browse the `prompts/` folder for the feature you want to add
2. **Copy the prompt** - Open the `.md` file and copy its contents
3. **Provide to your AI assistant** - Paste the prompt into Claude Code, Cursor, or your preferred AI tool
4. **Customize as needed** - The AI will implement the feature, which you can then customize for your specific needs

### Why Use Prompts?

- **Consistency** - Tested prompts that work well with AI assistants
- **Time-saving** - Skip explaining common features from scratch
- **Best practices** - Prompts include JUCE best practices and patterns
- **Learning** - See how features are implemented in your codebase

### Contributing Prompts

As you build features with AI assistance, consider contributing successful prompts back to this collection. This helps the community build plugins faster and more consistently.

> 💡 **Note**: These prompts are starting points. Always review AI-generated code for your specific use case and test thoroughly.

---

## 📚 Resources

* [JUCE Documentation](https://docs.juce.com/)
* [JUCE Tutorials](https://juce.com/learn/tutorials)
* [JUCE Forum](https://forum.juce.com/)
* [CMake Tutorial](https://cmake.org/learn/)
* [pamplejuce: a far more robust JUCE audio plugin template](https://github.com/sudara/pamplejuce)
