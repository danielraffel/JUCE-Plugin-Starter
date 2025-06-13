# JUCE Plugin Starter

## ℹ️ Overview

This is a beginner-friendly JUCE plugin starter template using CMake and environment-based configuration. It allows you to create standalone apps and audio plugins (AU/VST3) for macOS using Xcode. It’s designed for quick setup, ease of customization, and modern JUCE development workflows.

---

### How to Just Give This a Try (Without Reading the Full README)

This is the fastest way to test-drive the JUCE Plugin Starter. It assumes you have [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12) installed and will:

* ✅ Install all required dependencies (doesn't assume you have git)
* ✅ Clone this repo and set up your environment
* ✅ Run a guided script to create your new plugin repo and push it to GitHub
* ✅ Download JUCE and generate an Xcode project
  
> **Heads up:** This command runs several scripts and installs multiple components. To avoid surprises, it’s a good idea to read through the full README before running it in your terminal.

```
# Install required tools (Xcode CLT, Homebrew, CMake, PluginVal, etc.)
bash <(curl -fsSL https://raw.githubusercontent.com/danielraffel/JUCE-Plugin-Starter/main/dependencies.sh)

# Clone the starter project and set up environment
git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter
cp .env.example .env

# Run the first-time setup to configure your plugin project
chmod +x scripts/initialize_JUCE-plugin_project.sh
scripts/initialize_JUCE-plugin_project.sh

# Generate and open the Xcode project (downloads JUCE on first run)
chmod +x scripts/generate_and_open_xcode.sh
scripts/generate_and_open_xcode.sh
```

* ✅ After setup, while developing your plugin you'll run this when you need to rebuild your project and reopen in Xcode:
```
scripts/generate_and_open_xcode.sh .
```

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
  - [2. Initialize Your Plugin Project with Git Using a Setup Script](#2-initialize-your-plugin-project-with-git-using-a-setup-script)
  - [3. Generate the Xcode Project](#3-generate-the-xcode-project)
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
- [📦 Project File Structure](#-project-file-structure)
  - [About the JUCE cache location](#about-the-juce-cache-location)
- [💡 Tips](#-tips)
  - [🔁 Building with AI Tools](#-building-with-ai-tools)
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
- [📚 Resources](#-resources)

---

## 🧰 Prerequisites

To build and develop plugins with this template, you’ll need:

### System Requirements
- macOS 15.0 or later ([you can adjust the minimum macOS version in CMakeLists.txt](https://github.com/danielraffel/JUCE-Plugin-Starter/blob/ec4162b7fb21c5c86c25398aa072a64dd7cd818c/CMakeLists.txt#L3))
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

Use the included [`dependencies.sh`](scripts/dependencies.sh) script. It **checks for each required tool** and **installs it automatically if missing**. This is typically needed only for a **first-time setup**.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/danielraffel/JUCE-Plugin-Starter/main/dependencies.sh)
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
| **GoogleTest** or **Catch2** *(optional)* | C++ unit testing                 | `brew install googletest` or `brew install catch2`                                                |
| **Python 3 + behave** *(optional)*        | Natural language test automation | `brew install python && pip3 install behave`                                                      |
| **[JUCE](https://juce.com)**              | Audio plugin framework (AU/VST3) | *Automatically downloaded by CMake/FetchContent*                                                            |

---

## 🚀 Quick Start

### 1. Clone the JUCE Plugin Starter Template
> 💡 This setup will “just work” if you clone this repo into your home folder (i.e., run cd in Terminal before cloning).

```bash
git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter
cp .env.example .env
````

Update your `.env` file to reflect:

```env
PROJECT_NAME=MyCoolPlugin
PROJECT_BUNDLE_ID=com.myname.mycoolplugin
PROJECT_PATH=~/JUCE-Plugin-Starter
COMPANY_NAME="Your Company Name"
JUCE_REPO=https://github.com/juce-framework/JUCE.git
JUCE_TAG=8.0.7
GITHUB_USERNAME=danielraffel
BASE_PROJECT_VERSION="1.0."

# --- Apple Notarization ---
# You only need to edit the fields below when you're ready to distribute your plugin.
# Until then, feel free to leave these default placeholder values as-is.
APPLE_ID=your@email.com
APP_SPECIFIC_PASSWORD=your-app-password
APP_CERT="Developer ID Application: Your Name (TEAM_ID)"
INSTALLER_CERT="Developer ID Installer: Your Name (TEAM_ID)"
TEAM_ID=YOUR_TEAM_ID
```

After cloning and configuring `.env`, remember:

- `PROJECT_NAME` is used as the name of your plugin. This will appear in DAWs like Logic, so name it accordingly.
- `COMPANY_NAME` sets the developer name displayed in the plugin browser.

>💡 On macOS, .env files are hidden by default in Finder. Press `Cmd + Shift + .` to show or hide hidden files.
You can also edit the file in Terminal using:

```bash
nano .env
```

---

### 2. Initialize Your Plugin Project with Git Using a Setup Script
If you're planning to use this template to build your own plugin and eventually publish it to GitHub, this script is designed to help you do that quickly and cleanly.
The script is smart and will:

* 🔍 Auto-detect if you're working in a JUCE project directory that doesn't match your .env settings
* 🏷️ Automatically suggest renaming your project folder to match your plugin name
* 📄 Create basic plugin source files if they don't exist (ready-to-build template)
* 🛡️ Confirm everything before making changes so you stay in control

Just run the interactive setup script (it will help you configure everything):
```bash
scripts/initialize_JUCE-plugin_project.sh
scripts/generate_and_open_xcode.sh
scripts/dependencies.sh
```

What the script does:

* 🔍 Smart path detection - notices if you're in a different directory than your .env expects and offers to fix it
* 🧠 Load and validate your .env settings
* ✏️ Interactive editing of project name, GitHub username, and project path
* 📁 Intelligent folder renaming - suggests renaming to match your plugin name (e.g., JUCE-Plugin-Starter → DelayR)
* 🔧 Script setup - makes build scripts executable (post_build.sh, generate_and_open_xcode.sh)
* 📄 Template source file creation - generates PluginProcessor.cpp/.h and PluginEditor.cpp/.h if missing
* 🔒 Repository visibility choice - asks if you want public or private
* ✅ Clear confirmation - shows exactly what will be created before proceeding
* 🧹 Clean slate - removes the template's Git history
* 🐙 GitHub integration - creates your new repository using the GitHub CLI (gh)
* 🚀 First commit - pushes your initial code and provides next steps

Example flow:
* 🔍 **PATH MISMATCH DETECTED** - Updates .env to match your current location
* 🔁 Edit PROJECT_NAME? → "DelayR" 
* 🔁 Rename folder to match project name? → JUCE-Plugin-Starter becomes DelayR
* 🔧 Setting up build scripts... → Makes scripts executable for immediate use
* 📄 Checking for basic plugin source files... → Creates template files if missing
* 🔒 Make this a private repository? → Choose public or private
* ✅ Proceed with project creation? → Final confirmation
* 🎉 Success! Ready to start coding your plugin

💡 Highly recommended for first-time users — the script handles all the setup automatically (including creating working plugin template files) while keeping you informed every step of the way. After running this script, you'll have a complete, buildable JUCE plugin ready to customize!

---

### 3. Generate the Xcode Project

> 💡 **First time setup**: When you first run `scripts/generate_and_open_xcode.sh`, CMake will automatically download JUCE to `build/_deps/juce-src/` inside your project directory. This may take a few minutes on the first run. JUCE will be reused for subsequent builds and cleaned up when you delete the `build/` directory.

Before running the script for the first time:

```bash
chmod +x scripts/generate_and_open_xcode.sh
```

Then generate your project:

```bash
scripts/generate_and_open_xcode.sh
```

✅ No need to run `cmake` manually — it's handled for you.

---

## 🧱 Build Targets

Once the project is open in Xcode, you can build:

* ✅ **Standalone App**
* ✅ **AudioUnit Plugin (AU)** – for Logic Pro, GarageBand
* ✅ **VST3 Plugin** – for Reaper, Ableton Live, etc.

> Switch targets using the Xcode scheme selector.
> 
<img width="352" alt="image" src="https://github.com/user-attachments/assets/4c3c3ac7-0613-46dc-a6b0-286743b858be" />

> Make sure the `FORMATS AU VST3 Standalone` line is present in `CMakeLists.txt`.

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
FORMATS AU VST3 Standalone
```

To skip AU, just remove it:

```cmake
FORMATS VST3 Standalone
```

#### ✅ Add Preprocessor Macros

```cmake
target_compile_definitions(${PROJECT_NAME} PRIVATE
    USE_MY_DSP_ENGINE=1
)
```

> After making changes, just re-run:

```bash
scripts/generate_and_open_xcode.sh
```

---

## 📦 Project File Structure

```
JUCE-Plugin-Starter/
├── .cursor/rules                         ← Cursor rules for AI
│   └── plugin_rules.mdc                  ← Rules describing how to generate project code
├── .env.example                          ← Template for your environment variables
├── installer                             ← Distribution and packaging templates
│   └── distribution.xml.example          ← macOS installer distribution config
│   └── postinstall.example               ← Post-installation script template
│   └── preinstall.example                ← Pre-installation script template
│   └── TERMS.txt.example                 ← Software license agreement template
│   └── Welcome.txt.example               Installer welcome message template
├── CMakeLists.txt                        ← Main build config for your JUCE project
├── initialize_JUCE-plugin_project        ← Script that will reinitialize this repo to make it yours, configure, rename and push it to GitHub
├── README.md                             ← You're reading it
├── generate_and_open_xcode.sh            ← Script that loads `.env`, runs CMake, and opens Xcode
├── scripts/                              ← Automation / helper scripts
│   └── dependencies.sh                   ← installs dependencies to run this project
│   └── generate_and_open_xcode.sh        ← creates the Xcode project using CMake
│   └── initialize_JUCE-plugin_project.sh ← initializes your plugin project
│   └── post_build.sh                     ← Auto-increments bundle version so Logic reloads 
│   └── setup_uv_environment.sh           ← (optional) if releasing a PKG that benefits from using UV, PIP, etc this helps create a virtual environment 
│   └── sign_and_package_plugin.sh        ← script to sign and package your plugin 
builds
├── Source/                               ← Your plugin source code
│   ├── PluginProcessor.cpp/.h            ← Core audio processing logic
│   └── PluginEditor.cpp/.h               ← User interface components
└── build/                                ← Generated by CMake (can be deleted anytime)
    └── YourPlugin.xcodeproj              ← Generated Xcode project

~/.juce_cache/                            ← Shared JUCE location (outside project)
└── juce-src/                             ← JUCE framework (shared across all projects)
```

### About the JUCE cache location:

* ✅ Shared across projects: Multiple JUCE projects use the same download
* ✅ Survives build cleaning: rm -rf build won't delete JUCE
* ✅ Version controlled: Different projects can use different JUCE versions via JUCE_TAG

>💡 You can safely `rm -rf` build without re-downloading JUCE every time.

---

## 💡 Tips

### 🔁 Building with AI Tools

#### Using with Cursor 

When you need to recreate your project file you can just call `/scripts/generate_and_open_xcode.sh` and when you want to sign and package your project you can just call `/scripts/sign_and_package_plugin.sh`. 


#### Using with Alex Sidebar
The commands are identical to using Cursor but to get the most out of using `generate_and_open_xcode.sh` with [AlexCodes.app](https://alexcodes.app), I’ve found the following project prompt helpful for managing when and how the Xcode project is compiled and opened:

```text
Whenever the Xcode project file needs to be regenerated use run_shell to execute $PROJECT_PATH/scripts/generate_and_open_xcode.sh
```

And, I would recommend uncommenting the following section in `/scripts/generate_and_open_xcode.sh` to open the generated Xcode project automatically after a build:

```bash
# Open the generated Xcode project
if [ -d "$XCODE_PROJECT" ]; then
  open "$XCODE_PROJECT"
else
  echo "Xcode project not found: $XCODE_PROJECT"
  exit 1
fi
```

<img width="515" alt="regenerate-xcode-alexcodes" src="https://github.com/user-attachments/assets/158b6005-645f-410a-9fdb-51ef9479ac55" />

---

## 📦 How to Distribute Your Plugin

Once your plugin is built and tested, you can package it for safe, notarized distribution via Apple’s system using the `/scripts/sign_and_package_plugin.sh` script.

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
2. Under **Security**, click **Generate Password** (app-specific)
3. Save this password securely — you'll need it every time you notarize.

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

> 💡 Always make sure your `.env` file is listed in `.gitignore` to avoid exposing credentials. This is configured by default.

---

### 🎛️ What Gets Packaged

This starter will automatically detect and package the following plugin formats if they exist:

| Format | Extension    | Path |
|--------|--------------|------|
| AU     | `.component` | `~/Library/Audio/Plug-Ins/Components/` |
| VST3   | `.vst3`      | `~/Library/Audio/Plug-Ins/VST3/` |
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
cd scripts
chmod +x sign_and_package_plugin.sh
./sign_and_package_plugin.sh
```

This script will:

- ✅ Sign and notarize your `.component`
- ✅ Create a signed `.pkg` installer and notarize it
- ✅ Bundle it into a distributable `.dmg`

> 📂 Output files (`.pkg`, `.dmg` and optionally `.zip`) will be saved to your Desktop for easy sharing.

---
## 📚 Resources

* [JUCE Documentation](https://docs.juce.com/)
* [JUCE Tutorials](https://juce.com/learn/tutorials)
* [JUCE Forum](https://forum.juce.com/)
* [CMake Tutorial](https://cmake.org/learn/)
* [pamplejuce: a far more robust JUCE audio plugin template](https://github.com/sudara/pamplejuce)