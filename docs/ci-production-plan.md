# Production CI/CD Plan

**Branch:** `integrate/cross-platform`
**Status:** Plan — not yet implemented

## Overview

Extend the CI/CD system from build-and-verify to a full cloud release pipeline that can sign, notarize, package, publish GitHub Releases, and update the project website — all from GitHub Actions.

This plan covers three connected workstreams:

1. **Production CI workflow** — Two modes: `verify` (current) and `publish` (full release pipeline)
2. **Secrets management** — Smart sync between local `.env` and GitHub Secrets via `/juce-dev:ci`
3. **Website integration** — Publish triggers website download link updates (connects to the website-proposal.md work)

---

## 1. Two CI Modes

### Mode: Verify (current behavior)

What we have today. Builds, runs tests, uploads raw artifacts. No signing, no packaging.

**Triggers:** Push to main/feature/integrate branches, PRs, manual dispatch
**Cost:** Low (~5 min per platform)
**Output:** Unsigned build artifacts (downloadable from Actions tab)

### Mode: Publish (new)

Full release pipeline in the cloud. Equivalent to running `./scripts/build.sh all publish` locally.

**Triggers:** Manual dispatch only (too expensive and sensitive for every push), or push to a `release/**` tag
**Cost:** Higher (~10-15 min per platform, includes notarization wait)
**Output:** Signed, notarized installers uploaded to GitHub Releases + website updated

### Workflow Structure

```yaml
# .github/workflows/build.yml (updated)
on:
  workflow_dispatch:
    inputs:
      platforms:
        description: "Platforms (macos,windows,linux or 'all')"
        default: ""
        type: string
      mode:
        description: "Build mode"
        type: choice
        options:
          - verify
          - publish
        default: verify
  push:
    branches: [main, "feature/**", "integrate/**"]
    # Push triggers always use verify mode
  pull_request:
    # PR triggers always use verify mode
  release:
    types: [created]
    # Release creation triggers publish mode
```

### What Publish Mode Does Per Platform

**macOS:**
1. Import Apple Developer certificates from GitHub Secrets into temp keychain
2. Build all formats (AU, AUv3, VST3, CLAP, Standalone)
3. Code sign with Developer ID Application certificate
4. Notarize with Apple (uses `xcrun notarytool`)
5. Staple notarization ticket
6. Create signed PKG installer with Developer ID Installer certificate
7. Notarize the PKG
8. Create DMG
9. Upload to GitHub Release
10. Update gh-pages download links (if website exists)
11. Generate EdDSA-signed appcast (if auto-updates enabled)

**Windows:**
1. Build VST3, CLAP, Standalone
2. Sign with Authenticode (if Azure Trusted Signing secrets present)
3. Create Inno Setup installer
4. Upload to GitHub Release
5. Update gh-pages download links

**Linux:**
1. Build VST3, CLAP, Standalone
2. Package as tar.gz
3. Upload to GitHub Release

---

## 2. GitHub Secrets Required

### macOS Signing

| Secret Name | Source (.env variable) | What it is |
|------------|----------------------|------------|
| `APPLE_DEVELOPER_CERTIFICATE_P12_BASE64` | Exported from Keychain | Base64-encoded .p12 of "Developer ID Application" cert |
| `APPLE_DEVELOPER_CERTIFICATE_PASSWORD` | Set during export | Password for the .p12 file |
| `APPLE_INSTALLER_CERTIFICATE_P12_BASE64` | Exported from Keychain | Base64-encoded .p12 of "Developer ID Installer" cert |
| `APPLE_INSTALLER_CERTIFICATE_PASSWORD` | Set during export | Password for the .p12 file |
| `APPLE_ID` | `APPLE_ID` | Apple Developer account email |
| `APP_SPECIFIC_PASSWORD` | `APP_PASSWORD` | App-specific password for notarization |
| `TEAM_ID` | `TEAM_ID` | Apple Developer Team ID |

### Windows Signing (Optional — Azure Trusted Signing)

| Secret Name | Source (.env variable) | What it is |
|------------|----------------------|------------|
| `AZURE_TENANT_ID` | `AZURE_TENANT_ID` | Azure AD tenant |
| `AZURE_CLIENT_ID` | `AZURE_CLIENT_ID` | Azure app registration |
| `AZURE_CLIENT_SECRET` | `AZURE_CLIENT_SECRET` | Azure app secret |

### General

| Secret Name | Source (.env variable) | What it is |
|------------|----------------------|------------|
| `EDDSA_PRIVATE_KEY` | `AUTO_UPDATE_EDDSA_PUBLIC_KEY` (private counterpart) | EdDSA key for Sparkle/WinSparkle signing |

### How Certificates Get Into CI

```yaml
- name: Import Apple Certificates
  if: matrix.mode == 'publish' && runner.os == 'macOS'
  env:
    APP_CERT_P12: ${{ secrets.APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 }}
    APP_CERT_PASSWORD: ${{ secrets.APPLE_DEVELOPER_CERTIFICATE_PASSWORD }}
    INSTALLER_CERT_P12: ${{ secrets.APPLE_INSTALLER_CERTIFICATE_P12_BASE64 }}
    INSTALLER_CERT_PASSWORD: ${{ secrets.APPLE_INSTALLER_CERTIFICATE_PASSWORD }}
  run: |
    # Create temporary keychain
    KEYCHAIN_PATH=$RUNNER_TEMP/signing.keychain-db
    KEYCHAIN_PASSWORD=$(openssl rand -base64 32)
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

    # Import certificates
    echo "$APP_CERT_P12" | base64 --decode > $RUNNER_TEMP/app_cert.p12
    echo "$INSTALLER_CERT_P12" | base64 --decode > $RUNNER_TEMP/installer_cert.p12
    security import $RUNNER_TEMP/app_cert.p12 -P "$APP_CERT_PASSWORD" \
      -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
    security import $RUNNER_TEMP/installer_cert.p12 -P "$INSTALLER_CERT_PASSWORD" \
      -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"

    # Add to search list
    security list-keychain -d user -s "$KEYCHAIN_PATH"
    security set-key-partition-list -S apple-tool:,apple: \
      -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

    # Clean up cert files
    rm -f $RUNNER_TEMP/app_cert.p12 $RUNNER_TEMP/installer_cert.p12
```

---

## 3. Secrets Management via `/juce-dev:ci`

The `/juce-dev:ci` command should help users manage the sync between local `.env` and GitHub Secrets.

### Scenarios

**Scenario A: First-time setup**
User has local `.env` with certs but hasn't pushed secrets to GitHub yet.
→ Detect missing secrets, offer to push them.

**Scenario B: Local and cloud match**
→ Confirm they match, continue.

**Scenario C: Local and cloud differ**
→ Show the diff (which values changed), tell user where `.env` lives, offer options:
  1. "Push local values to GitHub Secrets" (local is newer)
  2. "I manually updated GitHub Secrets — pull to local .env" (cloud is newer)
  3. "Edit .env manually and re-scan" (they want to fix something first)
  4. "Skip — continue with current settings"

**Scenario D: Fresh clone, no local .env but secrets exist in cloud**
→ Offer to write a `.env` from GitHub Secrets (useful for new machine setup).

### What We Can Compare

GitHub Secrets are write-only — you can't read the values back. So we can only check:
- Whether a secret **exists** (via `gh secret list`)
- Whether the **local value is set** (non-empty in `.env`)

We **cannot** compare actual values. So the flow is:

```
For each required secret:
  - Local .env has value?  → Yes/No
  - GitHub Secret exists?  → Yes/No

Possible states:
  Both set       → "Looks good. If you've changed your local .env since last push,
                    consider updating GitHub Secrets."
  Local only     → "Found in .env but not in GitHub Secrets. Push it?"
  Secret only    → "Exists in GitHub but not in local .env. Write to .env?"
  Neither        → "Not configured. Needed for [signing/notarization/etc]."
```

### Implementation in `/juce-dev:ci`

Add a `secrets` subcommand:

```
/juce-dev:ci secrets              # Show sync status
/juce-dev:ci secrets push         # Push .env values to GitHub Secrets
/juce-dev:ci secrets pull         # Write GitHub Secret names to .env (values need manual entry)
```

**Push flow:**
```bash
# For each secret mapping:
VALUE=$(grep '^APPLE_ID=' .env | cut -d= -f2- | tr -d '"')
if [ -n "$VALUE" ]; then
  gh secret set APPLE_ID --body "$VALUE"
fi
```

**Pull flow (limited):**
Since we can't read secret values, pull can only:
- Check which secrets exist
- Add placeholder lines to `.env` for missing variables
- Tell the user: "These secrets exist in GitHub but aren't in your .env. Add the values manually."

**Certificate export guidance:**
For the P12 certificates, the command should walk the user through:
1. Open Keychain Access
2. Find "Developer ID Application" certificate
3. Right-click → Export → .p12 format
4. Base64 encode: `base64 -i cert.p12 | pbcopy`
5. The command then pushes the base64 string as a GitHub Secret

---

## 4. Website Integration

When publish mode completes and creates a GitHub Release, the workflow should also update the gh-pages website.

This connects directly to the website-proposal.md work:
- `scripts/update_download_links.sh` updates download buttons on gh-pages
- Uses marker-comment block replacement (DOWNLOAD-MACOS-START/END, etc.)
- Works for both macOS (.pkg) and Windows (_Setup.exe) releases

### CI Publish Step (after release creation)

```yaml
- name: Update Website Download Links
  if: matrix.mode == 'publish'
  run: |
    if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
      ./scripts/update_download_links.sh
    else
      echo "No gh-pages branch found. Tip: Run /juce-dev:website to create a download page."
    fi
```

This step runs AFTER the GitHub Release is created, so download URLs are valid.

---

## 5. Implementation Phases

### Phase A: Production CI Workflow

**A.1** Add `mode` input to workflow_dispatch (verify vs publish)
**A.2** Add certificate import step for macOS (temp keychain approach)
**A.3** Add publish steps: call `./scripts/build.sh all publish` instead of raw cmake
**A.4** Add release tag trigger (`on: release: types: [created]`)
**A.5** Add Windows signing step (conditional on Azure secrets existing)
**A.6** Test end-to-end: trigger publish, verify signed PKG is on GitHub Release
**A.7** Update README FAQ with publish mode docs

### Phase B: Secrets Management

**B.1** Add `secrets` subcommand to `/juce-dev:ci` command
**B.2** Implement secret existence checking (`gh secret list`)
**B.3** Implement push flow (`.env` → GitHub Secrets)
**B.4** Implement pull flow (placeholder generation for missing `.env` entries)
**B.5** Add certificate export guidance (Keychain → .p12 → base64 → secret)
**B.6** Test: fresh repo with no secrets, push from `.env`, verify publish works

### Phase C: Website Integration (depends on website-proposal.md Phase 1)

**C.1** Add `update_download_links.sh` call to publish workflow
**C.2** Ensure gh-pages worktree works in CI environment
**C.3** Test: publish triggers website update, download buttons activate
**C.4** Handle first activation (stub→active) vs updates (version bump)

### Phase D: `/juce-dev:ci` Enhancements

**D.1** Add `publish` subcommand: `/juce-dev:ci publish` triggers publish mode
**D.2** Add secrets status to `/juce-dev:ci` default output
**D.3** Add guidance for which secrets are needed based on CI_PLATFORMS
**D.4** Monitor publish runs and report signing/notarization status

---

## 6. Decision: Where Does This Work Live?

### Option 1: Continue on `integrate/cross-platform`

Pro: Everything in one branch, easy to test together.
Con: Branch is getting large, mixes verification CI with production CI.

### Option 2: New `feature/ci-publish` branch from `integrate/cross-platform`

Pro: Clean separation, can merge cross-platform to main first.
Con: Needs cross-platform merged first.

### Recommendation

**Merge `integrate/cross-platform` to main first** (it's tested and passing CI), then create `feature/ci-publish` for the production pipeline work. The website work can either go on `feature/website` (as the proposal suggests) or be combined with `feature/ci-publish` since they're tightly coupled.

---

## 7. Relationship to Website Proposal

The website-proposal.md is a comprehensive plan for `/juce-dev:website`. This plan **extends** it by making the website update step happen automatically in CI, not just during local `build.sh publish`.

| Concern | Website Proposal | This Plan |
|---------|-----------------|-----------|
| Website creation | `/juce-dev:website` command | Same — no change |
| Download link updates (local) | `build.sh publish` calls `update_download_links.sh` | Same — no change |
| Download link updates (CI) | Not covered | **New**: CI publish mode calls `update_download_links.sh` |
| Certificate management | Not covered | **New**: `/juce-dev:ci secrets` manages cert sync |
| Cloud builds | Not covered | **New**: Full signed builds in GitHub Actions |

The website work (Phase 1 of website-proposal.md) should be done first or in parallel — it provides the `update_download_links.sh` script and gh-pages infrastructure that CI publish depends on.

---

## 8. Open Questions

1. **Should publish mode create the GitHub Release, or should the user create it and CI attaches assets?** Creating a release tag and having CI do everything is cleaner, but some users want control over release notes.

2. **Notarization wait time**: Apple notarization can take 1-15 minutes. Should the CI job poll and wait, or should it be a separate workflow that runs after notarization completes? Current `build.sh` polls — same approach could work in CI.

3. **Should we support publishing from CI for BOTH platforms in one run?** e.g., a single "publish" dispatch creates a macOS release AND a Windows release. Or should each platform publish independently? Independent is simpler but means two separate release assets get attached to the same GitHub Release at different times.

4. **Private repo releases**: If the repo is private, GitHub Release download URLs are also private. The website-proposal.md handles this with a separate public website repo. Should CI publish to the website repo too?
