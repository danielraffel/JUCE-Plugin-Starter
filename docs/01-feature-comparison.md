# Feature Comparison: JUCE-Plugin-Starter vs Reference Template

## Legend
- **Us** = JUCE-Plugin-Starter + juce-dev plugin + Visage fork
- **Ref** = Reference cross-platform JUCE template

---

## 1. Platform Support

| Feature | Us | Ref | Gap? |
|---------|-----|-----|------|
| macOS builds | Yes | Yes | - |
| macOS universal binary (arm64+x86_64) | Yes | Yes | - |
| macOS min deployment target configurable | Yes (15.0) | Yes (10.15) | Consider lower target |
| Windows builds | No | Yes (MSVC + Ninja) | **GAP** |
| Linux builds | No | Yes (Clang + Ninja) | **GAP** |
| iOS/iPadOS app target | Yes (via setup-ios) | No | **We're ahead** |
| iOS multi-touch (Visage) | Yes | No | **We're ahead** |
| Android | No | No | - |

## 2. CI/CD

| Feature | Us | Ref | Gap? |
|---------|-----|-----|------|
| GitHub Actions CI | No | Yes (3-platform matrix) | **GAP** |
| macOS CI build | No | Yes | **GAP** |
| Windows CI build | No | Yes | **GAP** |
| Linux CI build | No | Yes | **GAP** |
| Compiler caching (sccache) | No | Yes | **GAP** |
| Concurrency (cancel in-progress) | No | Yes | **GAP** |
| Automated artifact upload | No | Yes | **GAP** |

## 3. Plugin Formats

| Format | Us | Ref | Gap? |
|--------|-----|-----|------|
| Standalone | Yes | Yes | - |
| AU (Audio Unit) | Yes | Yes | - |
| VST3 | Yes | Yes | - |
| AUv3 (iOS) | No (GUI app only) | Yes | **GAP** - should add AUv3 |
| CLAP | No | Yes (via clap-juce-extensions) | **GAP** |
| AAX | No | No (commented out) | - |
| LV2 | No | No | - |

## 4. Build System

| Feature | Us | Ref | Gap? |
|---------|-----|-----|------|
| CMake | Yes | Yes (3.25+) | - |
| Xcode generator | Yes | No (uses Ninja) | Different approach |
| Ninja generator | No | Yes (all platforms) | **GAP** for cross-platform |
| CMake presets | No | No | - |
| Build type configurable | Yes | Yes | - |
| Custom CMake modules | No | Yes (9 modules) | **GAP** |
| Shared code library target | No | Yes (SharedCode STATIC) | **GAP** |
| Assets binary data | No | Yes (juce_add_binary_data) | Minor |
| Post-build version stamping | Yes | No | **We're ahead** |
| Skip-regen fast builds | Yes | No | **We're ahead** |

## 5. Dependency Management

| Feature | Us | Ref | Gap? |
|---------|-----|-----|------|
| JUCE via FetchContent | Yes (shared cache) | No | **We're ahead** (no submodule) |
| JUCE via git submodule | No | Yes | Different approach |
| JUCE version pinning | Yes (.env JUCE_TAG) | Yes (submodule commit) | - |
| CPM package manager | No | Yes | **GAP** |
| Third-party JUCE modules | No | Yes (melatonin_inspector) | **GAP** |
| CLAP extensions | No | Yes (clap-juce-extensions) | **GAP** |
| Intel IPP support | No | Yes (Windows/Linux) | Minor |
| Visage GPU UI | Yes | No | **We're ahead** |

## 6. Testing

| Feature | Us | Ref | Gap? |
|---------|-----|-----|------|
| PluginVal validation | Yes | Yes (strictness 10) | - |
| Unit tests (Catch2) | No | Yes | **GAP** |
| Benchmark framework | No | Yes (Catch2 benchmarks) | **GAP** |
| GUI test helpers | No | Yes (runWithinPluginEditor) | **GAP** |
| Test in CI | No | Yes | **GAP** |

## 7. Code Signing & Distribution

| Feature | Us | Ref | Gap? |
|---------|-----|-----|------|
| macOS code signing | Yes (local) | Yes (CI) | - |
| macOS notarization | Yes (local) | Yes (CI) | - |
| macOS PKG installer | Yes | Yes (pkgbuild+productbuild) | - |
| macOS DMG | Yes | No | **We're ahead** |
| Windows code signing | No | Yes (Azure Trusted Signing) | **GAP** |
| Windows installer | No | Yes (Inno Setup) | **GAP** |
| Linux packaging | No | Yes (7z archive) | **GAP** |
| GitHub release creation | Yes | Yes | - |
| Landing page generation | Yes | No | **We're ahead** |
| AI release notes | Yes (multi-backend) | No | **We're ahead** |

## 8. Developer Experience

| Feature | Us | Ref | Gap? |
|---------|-----|-----|------|
| Interactive project init | Yes (full wizard) | No | **We're ahead** |
| Claude Code plugin | Yes (4 commands, 2 skills) | No | **We're ahead** |
| .env configuration | Yes (comprehensive) | No | **We're ahead** |
| Template reusability | Yes (creates separate projects) | No (fork/clone) | **We're ahead** |
| Diagnostics app | Yes (DiagnosticKit) | No | **We're ahead** |
| Prompt library | Yes (5 prompts) | No | **We're ahead** |
| Auto version bumping | Yes (semantic) | No | **We're ahead** |
| Uninstaller | Yes | No | **We're ahead** |
| .clang-format | No | Yes | **GAP** |
| Melatonin Inspector | No | Yes | **GAP** |
| Xcode prettification | No | Yes (XcodePrettify) | Minor |

## 9. GPU/UI Framework

| Feature | Us | Ref | Gap? |
|---------|-----|-----|------|
| GPU-accelerated UI | Yes (Visage/Metal) | No | **We're ahead** |
| Metal rendering (macOS) | Yes | No | **We're ahead** |
| Metal rendering (iOS) | Yes | No | **We're ahead** |
| DirectX rendering (Windows) | Visage supports it | No | Available via Visage |
| Vulkan rendering (Linux) | Visage supports it | No | Available via Visage |
| WebGL rendering | Visage supports it | No | Available via Visage |
| JUCE-Visage bridge | Yes (macOS/iOS) | No | **We're ahead** |
| Multi-touch support | Yes (iOS) | No | **We're ahead** |

---

## Summary: Where We Lead

1. **Developer experience**: Init wizard, Claude Code plugin, .env config, template reuse
2. **GPU UI**: Visage integration with Metal on macOS/iOS, bridge layer
3. **Distribution**: DMG, landing pages, AI release notes, uninstaller, DiagnosticKit
4. **iOS**: App targets with Visage GPU UI and multi-touch
5. **Build optimization**: Skip-regen, auto version bumping, post-build versioning

## Summary: Key Gaps to Address

### High Priority
1. **CLAP format support** - Growing standard, easy to add via clap-juce-extensions
2. **AUv3 format** - iOS plugin format (not just GUI app)
3. **CI/CD pipeline** - GitHub Actions for automated builds/tests
4. **Unit testing framework** - Catch2 integration
5. **Windows support** - Build system, signing, installer, CI

### Medium Priority
6. **Linux support** - Build system, CI, packaging
7. **.clang-format** - Code formatting consistency
8. **Ninja generator option** - Faster builds on all platforms
9. **Melatonin Inspector** - Runtime UI debugging (useful alongside Visage)
10. **SharedCode library target** - Better CMake architecture

### Lower Priority
11. **CPM package manager** - Modern dependency management
12. **Intel IPP** - DSP performance optimization
13. **Benchmark framework** - Performance regression testing
14. **Lower macOS deployment target** - Support older macOS versions
