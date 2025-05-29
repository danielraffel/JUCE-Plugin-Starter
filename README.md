# JUCE Plugin Starter

## ℹ️ Overview

This is a beginner-friendly JUCE plugin starter template using CMake and environment-based configuration. It allows you to create standalone apps and audio plugins (AU/VST3) for macOS using Xcode. It’s designed for quick setup, ease of customization, and modern JUCE development workflows.

---

## 🧰 Prerequisites

To build and develop plugins with this template, you’ll need:

### System Requirements
- macOS 12.0 or later
- [Xcode](https://developer.apple.com/download/all/) (latest version)
- Additional IDE with AI ([Alex Sidebar](http://alexcodes.app), [Cursor](http://cursor.com), [Windsurf](http://windsurf.com), [Trae](http://trae.ai), or [VSCode](https://code.visualstudio.com)) recommended

### Dependencies

| Tool            | Purpose                         | Install Command                                 |
|-----------------|----------------------------------|--------------------------------------------------|
| **JUCE**        | Audio plugin framework (AU/VST3) | _Included in step 1 under Quick Start_ |
| **CMake**       | Build system configuration        | `brew install cmake`                            |
| **Xcode Command Line Tools** | Xcode compiler & tools  | `xcode-select --install`                        |
| **PluginVal**   | Plugin validation & testing       | `brew install --cask pluginval`                 |
| **Faust** *(opt)* | DSP prototyping compiler       | `brew install faust`                            |
| **GoogleTest** or **Catch2** *(opt)* | C++ unit testing | `brew install googletest` or `brew install catch2` |
| **Python 3 + behave** *(opt)* | Natural language test automation | `pip3 install behave` |

---

## 🚀 Quick Start

### 1. Clone JUCE and the JUCE Plugin Starter Template

```bash
git clone --recurse-submodules https://github.com/juce-framework/JUCE.git
git clone https://github.com/yourname/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter
cp .env.example .env
````

Update your `.env` file to reflect:

```env
PROJECT_NAME=MyCoolPlugin
PROJECT_BUNDLE_ID=com.myname.mycoolplugin
PROJECT_PATH=/Users/yourname/Code/MyCoolPlugin
JUCE_PATH=/Users/yourname/Code/JUCE
```

---

### 2. Generate the Xcode Project

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
├── .env.example              ← Template for your environment variables
├── CMakeLists.txt            ← Main build config for your JUCE project
├── README.md                 ← You’re reading it
├── generate_and_open_xcode.sh ← Script that loads `.env`, runs CMake, and opens Xcode
├── Source/                   ← Your plugin source code
│   ├── PluginProcessor.cpp/.h
│   └── PluginEditor.cpp/.h
```

---

## 💡 Tips

### 🔁 Regenerate with AI Tools

Use in [AlexCodes.app](https://alexcodes.app) with the following project prompt:

```text
Whenever the Xcode project file needs to be regenerated use run_shell to execute $PROJECT_PATH/generate_and_open_xcode.sh
```

<img width="515" alt="regenerate-xcode-alexcodes" src="https://github.com/user-attachments/assets/158b6005-645f-410a-9fdb-51ef9479ac55" />

### 🪄 Rename Your Plugin

Rename your folder and `.zip` archive, then update `.env` with your real plugin name.

---

## 📚 Resources

* [JUCE Documentation](https://docs.juce.com/)
* [JUCE Tutorials](https://juce.com/learn/tutorials)
* [JUCE Forum](https://forum.juce.com/)
* [CMake Tutorial](https://cmake.org/learn/)
