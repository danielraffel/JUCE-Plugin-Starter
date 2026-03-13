# Auto-Update Implementation Progress

## Phase A1: Public macOS Updates (full-product PKG)

### Template work (JUCE-Plugin-Starter)
- [x] A1.1 — Add scripts/setup_sparkle.sh
- [x] A1.2 — Write Source/AutoUpdater.h
- [x] A1.3 — Write Source/AutoUpdater_Mac.mm
- [x] A1.4 — Update CMakeLists.txt (Sparkle linking)
- [x] A1.5 — Update .env.example (auto-update variables)
- [ ] A1.6 — Update scripts/post_build.sh (Sparkle Info.plist entries)
- [ ] A1.7 — Add "Check for Updates..." to standalone app menu
- [ ] A1.8 — Add EdDSA signing to build.sh publish
- [ ] A1.9 — Add appcast XML generation to build.sh
- [ ] A1.10 — Implement correct publish pipeline order
- [ ] A1.11 — Handle shutdown callbacks
- [ ] A1.12 — Wire up generate_release_notes.py --format sparkle

### juce-dev plugin work (generous-corp-marketplace)
- [ ] A1.13 — Create commands/setup-updates.md
- [ ] A1.14 — Update commands/create.md (auto-updates question)
- [ ] A1.15 — Update commands/build.md (appcast/EdDSA in publish)
- [ ] A1.16 — Update commands/status.md (auto-update status)

## Phase A2: Public Windows Updates (full-product Inno Setup)

### Template work (JUCE-Plugin-Starter)
- [ ] A2.1 — Add scripts/setup_winsparkle.sh
- [ ] A2.2 — Write Source/AutoUpdater_Win.cpp
- [ ] A2.3 — Update CMakeLists.txt (WinSparkle linking)
- [ ] A2.4 — Add update trigger to Windows Settings panel
- [ ] A2.5 — Add EdDSA signing to build.ps1 publish
- [ ] A2.6 — Add appcast XML generation to build.ps1
- [ ] A2.7 — Implement correct publish pipeline in build.ps1
- [ ] A2.8 — Verify Inno Setup bundles all formats + WinSparkle.dll
- [ ] A2.9 — Handle shutdown callbacks (WinSparkle)
- [ ] A2.10 — Handle elevation for plugin install paths

### juce-dev plugin work (generous-corp-marketplace)
- [ ] A2.11 — Update commands/port.md (Sparkle/WinSparkle audit)
- [ ] A2.12 — Add --doctor validation to setup-updates
- [ ] A2.13 — Update index.html (remove "planned" labels)
