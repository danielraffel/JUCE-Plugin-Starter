# JUCE Plugin Starter

## 🎚 Overview

This is a beginner-friendly JUCE plugin template using CMake and environment-based configuration. It allows you to create a standalone app and audio plugins (AU/VST3) for macOS using Xcode. Setup is quick and portable — ideal for personal projects or quick experiments.

---

## 🚀 Quick Start

### 1. Clone the template
Unzip and rename this project folder. Then create your own `.env` file from the provided example.

```bash
cp .env.example .env
```

Edit `.env` to reflect your plugin name, bundle ID, and paths.

---

### 2. Configure the project

Run the following shell script to generate an Xcode project using your environment variables:

```bash
./generate_and_open_xcode.sh
```

This will:
- Load `.env`
- Run CMake to generate an Xcode project
- Open it in Xcode

---

### 3. Build targets

Your Xcode project supports:

- ✅ Standalone App
- ✅ AU Plugin (for Logic, GarageBand)
- ✅ VST3 Plugin (for Reaper, Live, etc.)

Switch targets using the Xcode scheme dropdown.

---

### 4. Recommended Tools

| Tool           | Purpose                         |
|----------------|---------------------------------|
| JUCE           | Plugin Framework                |
| CMake          | Build System                    |
| PluginVal      | Plugin Validation               |
| Faust (opt.)   | DSP Prototyping                 |
| behave (opt.)  | Natural Language Testing        |

---

## 📁 Customize Your Plugin

Edit files in the `Source/` folder to define your plugin’s UI and audio processing behavior:

- `PluginProcessor.cpp/h`
- `PluginEditor.cpp/h`

---

## 💡 Tips

- Use [AlexCodes.app](https://alexcodes.app) to auto-regenerate the Xcode project with this prompt:
  ```
  Whenever the Xcode project file needs to be regenerated use run_shell to execute $PROJECT_PATH/generate_and_open_xcode.sh
  ```

- Rename your `.zip` to match your actual plugin name when publishing or archiving.

---

## 📚 Resources

- [JUCE Docs](https://docs.juce.com/)
- [JUCE Forum](https://forum.juce.com/)
- [CMake Tutorial](https://cmake.org/learn/)
