# Auto-Update Implementation Progress

## Phase A1: Public macOS Updates (full-product PKG)

### Template work (JUCE-Plugin-Starter)
- [x] A1.1 — Add scripts/setup_sparkle.sh
- [x] A1.2 — Write Source/AutoUpdater.h
- [x] A1.3 — Write Source/AutoUpdater_Mac.mm
- [x] A1.4 — Update CMakeLists.txt (Sparkle linking)
- [x] A1.5 — Update .env.example (auto-update variables)
- [x] A1.6 — Update scripts/post_build.sh (Sparkle Info.plist entries)
- [x] A1.7 — Add "Check for Updates..." to standalone app menu
- [x] A1.8 — Add EdDSA signing to build.sh publish
- [x] A1.9 — Add appcast XML generation to build.sh
- [x] A1.10 — Implement correct publish pipeline order
- [x] A1.11 — Handle shutdown callbacks
- [x] A1.12 — Wire up generate_release_notes.py --format sparkle

### juce-dev plugin work (generous-corp-marketplace)
- [x] A1.13 — Create commands/setup-updates.md
- [x] A1.14 — Update commands/create.md (auto-updates question)
- [x] A1.15 — Update commands/build.md (appcast/EdDSA in publish)
- [x] A1.16 — Update commands/status.md (auto-update status)

## Phase A2: Public Windows Updates (full-product Inno Setup)

### Template work (JUCE-Plugin-Starter)
- [x] A2.1 — Add scripts/setup_winsparkle.sh (fixed: correct GitHub URL, flatten Release/ dirs, copy bin/)
- [x] A2.2 — Write Source/AutoUpdater_Win.cpp (fixed: use win_sparkle_set_eddsa_public_key, compile-time config)
- [x] A2.3 — Update CMakeLists.txt (WinSparkle linking + compile definitions for feed URL/EdDSA key)
- [x] A2.4 — Update trigger via Help menu (already in StandaloneApp.cpp)
- [x] A2.5 — Add EdDSA signing to build.ps1 publish (fixed: use winsparkle-tool.exe sign -f)
- [x] A2.6 — Add appcast XML generation to build.ps1
- [x] A2.7 — Implement correct publish pipeline in build.ps1
- [x] A2.8 — Verify Inno Setup bundles all formats + WinSparkle.dll (added CloseApplications=yes)
- [x] A2.9 — Handle shutdown callbacks (WinSparkle)
- [x] A2.10 — Handle elevation for plugin install paths (Inno Setup handles this)

### juce-dev plugin work (generous-corp-marketplace)
- [x] A2.11 — Update commands/port.md (Sparkle/WinSparkle audit)
- [x] A2.12 — Add --doctor validation to setup-updates
- [x] A2.13 — Update index.html (remove "planned" labels)
