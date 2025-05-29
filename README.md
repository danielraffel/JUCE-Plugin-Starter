# JUCE Plugin Starter -- WIP

## 🎚 Overview

This is a beginner-friendly JUCE plugin starter template using CMake and environment-based configuration. It allows you to create standalone apps and audio plugins (AU/VST3) for macOS using Xcode. It’s designed for quick setup, ease of customization, and modern JUCE development workflows.

---

## 🧰 Prerequisites

To build and develop plugins with this template, you’ll need:

### System Requirements
- macOS 12.0 or later
- [Xcode](https://developer.apple.com/download/all/) (latest version)
- Additional IDE with AI ([Alex Sidebar](http://alexcodes.app), [Cursor](http://cursor.com), [Windsurf](http://windsurf.com), [Trae](http://trae.ai) or [VSCode](https://code.visualstudio.com) recommended)

### Dependencies

| Tool            | Purpose                         | Install Command                                 |
|-----------------|----------------------------------|--------------------------------------------------|
| **JUCE**        | Audio plugin framework (AU/VST3) | _Included in step 1 under Quick Start_ |
| **CMake**       | Build system configuration        | `brew install cmake`                            |
| **Xcode Command Line Tools**       | Build system configuration        | `xcode-select --install`                            |
| **PluginVal**   | Plugin validation & testing       | `brew install --cask pluginval`                 |
| **Faust** *(opt)* | DSP prototyping compiler       | `brew install faust`                            |
| **GoogleTest** or **Catch2** *(opt)* | C++ unit testing | `brew install googletest` or `brew install catch2` |
| **Python 3 + behave** *(opt)* | Natural language test automation | `pip3 install behave` |

---

## 🚀 Quick Start

### 1. Clone the Starter Template

```bash
git clone --recurse-submodules https://github.com/juce-framework/JUCE.git
git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git
cd JUCE-Plugin-Starter
cp .env.example .env
````

Update your `.env` file to reflect:

* Project name
* Bundle ID
* Absolute path to this folder
* JUCE path

```env
PROJECT_NAME=MyCoolPlugin
PROJECT_BUNDLE_ID=com.myname.mycoolplugin
PROJECT_PATH=/Users/yourname/Code/MyCoolPlugin
JUCE_PATH=/Users/yourname/Code/JUCE
```

---

### 2. Generate the Xcode Project

Run the script:

```bash
./generate_and_open_xcode.sh
```

This will:

* Load your `.env` file
* Run CMake using the configured paths
* Generate the `.xcodeproj` file
* Open it in Xcode

✅ No need to run `cmake` manually — it's handled for you.

---

## 🧱 Build Targets

Once the project is open in Xcode, you can build any of the following:

* ✅ **Standalone App**
* ✅ **AudioUnit Plugin (AU)** – for Logic Pro, GarageBand
* ✅ **VST3 Plugin** – for Reaper, Ableton Live, etc.

Switch targets using the scheme selector in Xcode.

> Ensure the `FORMATS AU VST3 Standalone` line exists in your `CMakeLists.txt` under `juce_add_plugin(...)`.

---

## 📁 Customize Your Plugin

Edit files in the `Source/` directory to define your plugin’s functionality:

* `PluginProcessor.cpp / .h` – handles DSP processing
* `PluginEditor.cpp / .h` – defines the user interface

Feel free to expand with additional `.cpp/.h` files for modular design.

---

## 💡 Tips

* **Regenerate in AlexCodes.app:**
  Set the project prompt:

  ```text
  Whenever the Xcode project file needs to be regenerated use run_shell to execute $PROJECT_PATH/generate_and_open_xcode.sh
  ```

* **Renaming this Starter**:
  When you're ready to publish your plugin, rename your `.zip` and project folder accordingly, then update your `.env`.

---

## 📚 Resources

* [JUCE Documentation](https://docs.juce.com/)
* [JUCE Tutorials](https://juce.com/learn/tutorials)
* [JUCE Forum](https://forum.juce.com/)
* [CMake Tutorial](https://cmake.org/learn/)

```
