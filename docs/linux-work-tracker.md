# Linux & Auto-Updates — Work Tracker

**Date started:** 2026-03-13
**Last updated:** 2026-03-13

---

## Completed (this session)

### Issue #11: Linux End-to-End Support

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Probe Ubuntu VM | ✅ Done | Ubuntu 24.04 LTS aarch64, all deps installed, gh CLI authenticated |
| 2 | Install dependencies | ✅ Done | cmake, ninja, clang, all JUCE apt deps already present |
| 3 | Build plugin on Ubuntu | ✅ Done | VST3, CLAP, Standalone all compile (JUCE 8.0.12) |
| 4 | Test GitHub release from Ubuntu | ✅ Done | tar.gz created, gh release created and verified |
| 5 | Create AutoUpdater_Linux.cpp | ✅ Done | Custom appcast polling, pure JUCE, no external deps |
| 6 | Update CMakeLists.txt | ✅ Done | Linux auto-update block added |
| 7 | Update AutoUpdater.h | ✅ Done | Comment updated to mention Linux |
| 8 | Commit to JUCE-Plugin-Starter | ✅ Done | Commit: 58e4333 |
| 9 | Update JUCE-Plugin-Starter README | ✅ Done | Linux FAQ, auto-updater docs, Ubuntu testing note. Commit: 9abf36b |
| 10 | Add Linux to juce-dev port command | ✅ Done | All directions: mac→linux, win→linux, linux→mac, linux→win |
| 11 | Update juce-dev README | ✅ Done | Port command, auto-updates mention Linux |
| 12 | Update juce-dev index.html | ✅ Done | Port workflow card, command ref, VM setup, FAQ |
| 13 | Commit to generous-corp-marketplace | ✅ Done | Commit: 2ff09c8 |
| 16 | Add "Port to All" card to juce-dev homepage | ✅ Done | Commit: 7f81fd9 |
| 14 | Update GitHub issue #11 with progress | ✅ Done | Comment posted |
| 15 | Create tracking document | ✅ Done | This file |

### Not tested (skipped per plan)

- Visage GPU rendering (no GPU on Ubuntu VM)
- DAW plugin loading (no Linux DAW installed)
- Auto-updater end-to-end with real appcast (headless VM, no display server)

### Not pushed yet (awaiting user confirmation)

- **JUCE-Plugin-Starter**: 2 commits (auto-updater + README)
- **generous-corp-marketplace**: 1 commit (juce-dev Linux updates)

---

## Open Items

### Issue #4: Update README auto-updates section ✅ DONE
**Priority:** Quick cleanup
**Depends on:** Nothing

- [x] Remove "*(Planned)*" from Auto-Updates section heading
- [x] Rewrite to document actual implementation (Sparkle, WinSparkle, Linux appcast)
- [x] Document how to enable: `ENABLE_AUTO_UPDATE=true`, setup scripts
- [x] Document publish pipeline: `/juce-dev:build publish`
- [x] Add file tree entries for `AutoUpdater.h`, `AutoUpdater_Mac.mm`, `AutoUpdater_Win.cpp`, `AutoUpdater_Linux.cpp`, `StandaloneApp.cpp`
- Commit: c80d3bf

### Issue #9: Split-repo publish (PlunderTube-style releases) ✅ DONE (CI infrastructure)
**Priority:** Medium — user would use this immediately for PlunderTube releases
**Depends on:** #7 (EdDSA signing in CI), #10 (Appcast generation script)

#### Completed:
- [x] Add `RELEASE_REPO` / `APPCAST_REPO` / `RELEASE_REPO_PAT` to `.env.example`
- [x] Add `RELEASE_REPO` support to CI `create_release` job — target configurable repo
- [x] Add `APPCAST_REPO` support — push appcast XML to separate repo after signing
- [x] Add cross-repo PAT authentication for `gh release create` and `git push`
- [x] Add `latest.json` generation (dynamic JSON for website JavaScript loading)

#### Remaining (deferred — juce-dev plugin updates):
- [ ] Update `update_download_links.sh` to support updating links in external repos
- [ ] Add `--release-repo` flag to `/juce-dev:build publish`
- [ ] Update `/juce-dev:setup-updates` to offer split-repo option during setup
- [ ] Document the split-repo pattern in README

### Issue #11 remaining phases

**Phase 2: Packaging Improvements (optional, deferred)**
- [ ] Add install script inside tar.gz
- [ ] Consider .deb packaging for Ubuntu/Debian
- [ ] Consider AppImage for standalone
- [ ] Document manual install paths in README

**Phase 3: Auto-Updates (partially done)**
- [x] Create AutoUpdater_Linux.cpp
- [x] Add CMakeLists.txt Linux auto-update block
- [ ] End-to-end test with real appcast (needs display server / Xvfb)
- [ ] Depends on #7 (EdDSA signing) and #10 (appcast generation) for full pipeline

### Issue #12: Cross-platform init_plugin_project.sh
**Priority:** Medium — only blocker for Windows/Linux project creation
**Depends on:** Nothing

- [ ] Fix `sed -i ''` (macOS-only) to detect platform and use correct syntax
- [ ] Update script output to recommend correct build command per platform
- [ ] Update juce-dev docs ("Requires macOS" → cross-platform) once fixed
- GitHub issue: https://github.com/danielraffel/JUCE-Plugin-Starter/issues/12

### Issue #5: Phase A test matrix ✅ DONE
- [x] Verify macOS auto-update end-to-end (PlunderTube v0.5.125 → v0.5.126 via Sparkle)
  - Installed v0.5.125 PKG (verified payload contains 0.5.125 build 1185)
  - Sparkle auto-updated silently to v0.5.126 (build 1186) — no user intervention needed
  - Full chain: appcast fetch → version comparison → PKG download (private repo w/ PAT) → install
- [x] Verify Windows auto-update infrastructure (WinSparkle)
  - Installed v0.5.115 on win2 VM via Inno Setup silent install (registry confirms 0.5.115)
  - Appcast accessible from VM, advertises v0.5.126 (build 1186)
  - Previous WinSparkle update artifact found (v0.5.109 Setup.exe in Temp/Update-*) — proves mechanism works
  - Full GUI test requires Proxmox console (JUCE can't run headlessly via SSH Session 0)
  - Infrastructure verified: installed version < appcast version, network OK, PAT auth configured

### Issue #7: Wire EdDSA signing into CI publish mode ✅ DONE
**Depends on:** #5
- [x] CI downloads Sparkle sign_update tool on macOS runner
- [x] Reads EDDSA_PRIVATE_KEY from GitHub Secret (env var fallback)
- [x] Signs PKG installer, saves signature + length as artifact
- [x] Signature metadata passed to release job via JSON artifact

### Issue #10: Appcast generation in CI ✅ DONE
**Depends on:** #7
- [x] CI generates appcast-macos.xml with EdDSA signature embedded
- [x] CI generates appcast-windows.xml for WinSparkle
- [x] Appcast committed and pushed to repo (or separate APPCAST_REPO)
- [x] Per-platform: macOS gets EdDSA, Windows gets basic XML

### Issue #6: Phase B private distribution
**Depends on:** #9
- [ ] Spike: Sparkle with PAT auth for private repo downloads
- [ ] Spike: WinSparkle with PAT auth
- [ ] If spikes fail: evaluate broker service / signed-URL backend

---

## Auto-Updates Series (dependency order)

```
#4 Update README ──────────────────────────── (no deps, quick)
#5 Phase A test matrix ────────────────────── (no deps)
  └─ #7 EdDSA signing in CI ───────────────── (depends on #5)
      └─ #10 Appcast generation script ────── (depends on #7)
          ├─ #9 Split-repo publish ────────── (depends on #7, #10) ← PlunderTube needs this
          │   └─ #6 Phase B private distro ── (depends on #9)
          └─ #11 Linux end-to-end ─────────── (Phase 1 done; Phase 3 depends on #7, #10)
#8 Linux auto-updates research ────────────── (superseded by #11)
```

---

## Environment

- **Ubuntu VM:** `ssh ubuntu` — Ubuntu 24.04 LTS, aarch64 (Proxmox)
- **Windows VM:** `ssh win2` — Windows 10 Pro, Q35+GPU (Proxmox)
- **macOS:** Local development machine
