# Visage GPU Platform Support Analysis

This document maps Visage's rendering backends and platform support to inform cross-platform expansion.

## Platform Matrix

| Platform | GPU Backend | Windowing | Input | Status |
|----------|-------------|-----------|-------|--------|
| macOS | Metal (BGFX) | Cocoa/MTKView | Mouse, keyboard, gestures | Production-ready |
| iOS | Metal (BGFX) | UIKit/MTKView | Multi-touch (recent), keyboard | Recently added |
| Windows | Direct3D 11 (D3D12 optional) | Win32 HWND | Mouse, keyboard | Production-ready |
| Linux | Vulkan (BGFX) | X11 + Xrandr | Mouse, keyboard, DnD | Production-ready |
| Web | WebGL/OpenGL ES | Emscripten/Canvas | Mouse, touch (DOM) | Production-ready |
| Android | Not implemented | Not implemented | Not implemented | Not available |

## Renderer Initialization by Platform

```
macOS/iOS  → bgfx::RendererType::Metal
Windows    → bgfx::RendererType::Direct3D11 (or D3D12 with USE_DIRECTX12)
Linux      → bgfx::RendererType::Vulkan
Web        → bgfx::RendererType::OpenGLES
```

## Platform-Specific Implementation Files

### macOS (1,035 lines)
- `visage_windowing/macos/windowing_macos.mm` - WindowMac, VisageAppView (MTKView subclass)
- `visage_graphics/macos/windowless_context.mm` - Metal device creation
- Key features: 60 FPS cap, DPI scaling, native cursors, clipboard, file drag-and-drop

### iOS (365 lines)
- `visage_windowing/ios/windowing_ios.mm` - WindowIos, VisageMetalView
- `visage_graphics/ios/windowless_context.mm` - iOS Metal layer init
- Key features: Multi-touch with pointer ID tracking, touch sorting, safe area, DPI scaling
- Recent commits: `ios/7-ios-multitouch` branch with 293 new test cases

### Windows (1,756 lines)
- `visage_windowing/win32/windowing_win32.cpp` - WindowWin32
- Key features: DPI awareness (Win10+), per-monitor DPI, HWND embedding, WM_* routing
- Minimum: Windows 10 (WINVER=0x0A00)

### Linux (1,619 lines)
- `visage_windowing/linux/windowing_x11.cpp` - WindowX11
- Key features: X11 connection pooling, Xrandr multi-monitor, 8 cursor types, clipboard (Selection protocol)

### Web/Emscripten (650 lines)
- `visage_windowing/emscripten/windowing_emscripten.cpp` - WindowEmscripten
- Key features: HTML5 Canvas, device pixel ratio, JavaScript clipboard

## JUCE Integration Status

**Critical finding:** Visage has NO built-in JUCE integration. The bridge layer exists in our JUCE-Plugin-Starter template (`Source/Visage/JuceVisageBridge.*`) and handles:

1. Embedding Visage views in JUCE Component hierarchy
2. Event routing (mouse, keyboard, clipboard, focus, resize)
3. Platform-specific native handle passing

### Bridge Requirements per Platform

| Platform | JUCE View Type | Visage View Type | Bridge Approach |
|----------|---------------|-----------------|-----------------|
| macOS | NSView (via ComponentPeer) | VisageAppView (MTKView) | Embed MTKView as subview |
| iOS | UIView (via ComponentPeer) | VisageMetalView (MTKView) | Embed as subview, native touch |
| Windows | HWND (via ComponentPeer) | Win32 HWND | Embed child HWND |
| Linux | X11 Window (via ComponentPeer) | X11 Window | Embed X11 window (reparent) |

### What Exists Today
- macOS bridge: **Complete** (JuceVisageBridge with full event forwarding)
- iOS bridge: **Complete** (simplified - VisageMetalView handles touches natively)
- Windows bridge: **Not started** (Visage has Win32 support, bridge needed)
- Linux bridge: **Not started** (Visage has X11 support, bridge needed)

### What's Needed for Windows Bridge
1. Get HWND from JUCE ComponentPeer (`getPeer()->getNativeHandle()`)
2. Create Visage WindowWin32 as child of JUCE HWND
3. Forward keyboard events (JUCE key codes → Visage key codes)
4. Handle DPI scaling coordination between JUCE and Visage
5. Manage destruction ordering (same 11-step pattern as macOS)

### What's Needed for Linux Bridge
1. Get X11 Window from JUCE ComponentPeer
2. Create Visage WindowX11 as child (reparent)
3. Forward keyboard events
4. Handle X11 focus management
5. Coordinate DPI scaling via Xrandr

## Android Assessment

**Visage does NOT support Android.** There are:
- No Android windowing files
- No Android GPU backend configuration
- No Java/JNI integration
- No Android-specific input handling

JUCE itself has limited Android support (requires Android Studio, JNI bridge). Adding Android to Visage would require:
1. New windowing implementation (Android SurfaceView or TextureView)
2. OpenGL ES or Vulkan backend (BGFX supports both)
3. JNI bridge for touch events
4. Android lifecycle management

This is a significant undertaking and should be Phase 3+ at earliest.

## Build System Platform Detection

Visage uses this CMake hierarchy (order matters):
```cmake
if (EMSCRIPTEN)        → VISAGE_EMSCRIPTEN=1
elseif (WIN32)         → VISAGE_WINDOWS=1
elseif (iOS)           → VISAGE_IOS=1
elseif (APPLE)         → VISAGE_MAC=1
elseif (UNIX)          → VISAGE_LINUX=1
```

Build requirements:
- macOS: Xcode, Metal framework
- iOS: Xcode, iOS SDK, Metal framework
- Windows: MSVC, DirectX SDK (ships with Windows SDK)
- Linux: Clang/GCC, Vulkan SDK, X11 dev libs, libfreetype
- Web: Emscripten SDK

## Key Takeaway

Visage already has production-ready support for Windows (DirectX) and Linux (Vulkan). The work needed is:
1. **Windows**: Create JuceVisageBridge for Win32 (moderate effort)
2. **Linux**: Create JuceVisageBridge for X11 (moderate effort)
3. **Android**: Not feasible without major Visage work (defer)
