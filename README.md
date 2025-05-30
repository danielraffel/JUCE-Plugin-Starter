# JUCE Plugin Starter

## ℹ️ Overview

This is a beginner-friendly JUCE plugin starter template using CMake and environment-based configuration. It allows you to create standalone apps and audio plugins (AU/VST3) for macOS using Xcode. It’s designed for quick setup, ease of customization, and modern JUCE development workflows.

---

### ⚡️ How to Just Give This a Try (Without Reading the Full README)

This is the fastest way to test-drive the JUCE Plugin Starter. It assumes you have [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12) installed and will:

* ✅ Install all required dependencies (doesn't assume you have git)
* ✅ Clone this repo and set up your environment
* ✅ Run a guided script to create your new plugin repo and push it to GitHub
* ✅ Download JUCE and generate an Xcode project
  
#### To get started paste this in your terminal
```
# Install required tools (Xcode CLT, Homebrew, CMake, PluginVal, etc.)
bash <(curl -fsSL https://raw.githubusercontent.com/danielraffel/JUCE-Plugin-Starter/main/dependencies.sh)

# Clone the starter project and set up environment
git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter
cp .env.example .env

# Run the first-time setup to configure your plugin project
chmod +x ./init_plugin_project.sh
./init_plugin_project.sh

# Generate and open the Xcode project (downloads JUCE on first run)
chmod +x ./generate_and_open_xcode.sh
./generate_and_open_xcode.sh
```

* ✅ After setup, while developing your plugin you'll run this when you need to rebuild your project and reopen in Xcode:
```
./generate_and_open_xcode.sh .
```

---

## 📑 Table of Contents

- [ℹ️ Overview](#️-overview)
  - [⚡️ How to Just Give This a Try (Without Reading the Full README)](#-how-to-just-give-this-a-try-without-reading-the-full-readme)
    - [To get started paste this in your terminal](#to-get-started-paste-this-in-your-terminal)
- [🧰 Prerequisites](#-prerequisites)
  - [System Requirements](#system-requirements)
  - [Dependencies](#dependencies)
    - [Automated Dependency Setup](#automated-dependency-setup)
    - [Manual Dependency Setup](#manual-dependency-setup)
- [🚀 Quick Start](#-quick-start)
  - [1. Clone the JUCE Plugin Starter Template](#1-clone-the-juce-plugin-starter-template)
  - [2. Initialize Your Plugin Project with the Setup Script](#2-initialize-your-plugin-project-with-git-using-a-setup-script)
  - [3. Generate the Xcode Project](#3-generate-the-xcode-project)
- [🧱 Build Targets](#-build-targets)
- [📁 Customize Your Plugin](#-customize-your-plugin)
- [🛠️ How to Edit `CMakeLists.txt`](#️-how-to-edit-cmakeliststxt)
  - [✅ Add Source Files](#-add-source-files)
  - [✅ Add JUCE Modules](#-add-juce-modules)
  - [✅ Change Output Formats](#-change-output-formats)
  - [✅ Add Preprocessor Macros](#-add-preprocessor-macros)
- [📦 Project File Structure](#-project-file-structure)
  - [About the JUCE cache location](#about-the-juce-cache-location)
- [💡 Tips](#-tips)
  - [🔁 Building with AI Tools](#-building-with-ai-tools)
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

Use the included [`dependencies.sh`](./dependencies.sh) script. It **checks for each required tool** and **installs it automatically if missing**. This is typically needed only for a **first-time setup**.

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
JUCE_REPO=https://github.com/juce-framework/JUCE.git
JUCE_TAG=8.0.7  # Can use main for latest (not recommended for production)
GITHUB_USERNAME=danielraffel
```

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
chmod +x ./init_plugin_project.sh
./init_plugin_project.sh
```

What the script does:

* 🔍 Smart path detection - notices if you're in a different directory than your .env expects and offers to fix it
* 🧠 Load and validate your .env settings
* ✏️ Interactive editing of project name, GitHub username, and project path
* 📁 Intelligent folder renaming - suggests renaming to match your plugin name (e.g., JUCE-Plugin-Starter → DelayR)
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
* 📄 Checking for basic plugin source files... → Creates template files if missing
* 🔒 Make this a private repository? → Choose public or private
* ✅ Proceed with project creation? → Final confirmation
* 🎉 Success! Ready to start coding your plugin

💡 Highly recommended for first-time users — the script handles all the setup automatically (including creating working plugin template files) while keeping you informed every step of the way. After running this script, you'll have a complete, buildable JUCE plugin ready to customize!

---

### 3. Generate the Xcode Project

> 💡 **First time setup**: When you first run `./generate_and_open_xcode.sh`, CMake will automatically download JUCE to `build/_deps/juce-src/` inside your project directory. This may take a few minutes on the first run. JUCE will be reused for subsequent builds and cleaned up when you delete the `build/` directory.

Before running the script for the first time:

```bash
chmod +x ./generate_and_open_xcode.sh
```

Then generate your project:

```bash
./generate_and_open_xcode.sh
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
./generate_and_open_xcode.sh
```

---

## 📦 Project File Structure

```
JUCE-Plugin-Starter/
├── .env.example               ← Template for your environment variables
├── CMakeLists.txt             ← Main build config for your JUCE project
├── init_plugin_project.sh     ← Script that will reinitialize this repo to make it yours, configure, rename and push it to GH
├── README.md                  ← You're reading it
├── generate_and_open_xcode.sh ← Script that loads `.env`, runs CMake, and opens Xcode
├── Source/                    ← Your plugin source code
│   ├── PluginProcessor.cpp/.h
│   └── PluginEditor.cpp/.h
└── build/                     ← Generated by CMake (can be deleted anytime)
    └── YourPlugin.xcodeproj   ← Generated Xcode project

~/.juce_cache/                 ← Shared JUCE location (outside project)
└── juce-src/                  ← JUCE framework (shared across all projects)
```

### About the JUCE cache location:

* ✅ Shared across projects: Multiple JUCE projects use the same download
* ✅ Survives build cleaning: rm -rf build won't delete JUCE
* ✅ Version controlled: Different projects can use different JUCE versions via JUCE_TAG


>💡 You can safely `rm -rf` build without re-downloading JUCE every time.

---

## 💡 Tips

### 🔁 Building with AI Tools

Use in [AlexCodes.app](https://alexcodes.app) with the following project prompt:

```text
Whenever the Xcode project file needs to be regenerated use run_shell to execute $PROJECT_PATH/generate_and_open_xcode.sh
```

<img width="515" alt="regenerate-xcode-alexcodes" src="https://github.com/user-attachments/assets/158b6005-645f-410a-9fdb-51ef9479ac55" />

---
## 📚 Resources

* [JUCE Documentation](https://docs.juce.com/)
* [JUCE Tutorials](https://juce.com/learn/tutorials)
* [JUCE Forum](https://forum.juce.com/)
* [CMake Tutorial](https://cmake.org/learn/)
