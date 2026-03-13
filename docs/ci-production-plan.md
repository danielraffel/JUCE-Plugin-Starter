# Production CI/CD Plan

**Branch:** `integrate/cross-platform`
**Status:** Plan — not yet implemented

## Overview

Extend the CI/CD system from build-and-verify to a full cloud release pipeline that can sign, notarize, package, publish GitHub Releases, and update the project website — all from GitHub Actions.

This plan covers four connected workstreams:

1. **Production CI workflow** — Three modes: `verify` (current), `sign` (build + sign), and `publish` (full release pipeline)
2. **Per-platform signing controls** — Flexible signing that respects available certs and user overrides
3. **Secrets management** — Smart sync between local `.env` and GitHub Secrets via `/juce-dev:ci`
4. **Website integration** — Publish triggers website download link updates (connects to the website-proposal.md work)

---

## 1. Three CI Modes

### Mode: Verify (current behavior)

What we have today. Builds, runs tests, uploads raw artifacts. No signing, no packaging.

**Triggers:** Push to main/feature/integrate branches, PRs, manual dispatch
**Cost:** Low (~5 min per platform, see [GitHub pricing](https://github.com/pricing) for details)
**Output:** Unsigned build artifacts (downloadable from Actions tab)

### Mode: Sign (new)

Build + sign, but don't create a release or publish anywhere. Useful for testing that your signing setup works before doing a full release.

**Triggers:** Manual dispatch only
**Cost:** Medium (~7-10 min per platform, includes signing but not notarization)
**Output:** Signed artifacts uploaded as workflow artifacts (not to GitHub Releases)

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
          - sign
          - publish
        default: verify
      sign_macos:
        description: "Sign macOS builds (publish/sign mode)"
        type: boolean
        default: true
      sign_windows:
        description: "Sign Windows builds (publish/sign mode)"
        type: boolean
        default: true
      create_release:
        description: "Create GitHub Release (publish mode only)"
        type: boolean
        default: true
  push:
    branches: [main, "feature/**", "integrate/**"]
    # Push triggers always use verify mode
  pull_request:
    # PR triggers always use verify mode
  release:
    types: [created]
    # Release creation triggers publish mode
```

### What Each Mode Does Per Platform

**macOS — Verify:**
1. Build all formats (AU, AUv3, VST3, CLAP, Standalone)
2. Run Catch2 tests + PluginVal validation
3. Upload unsigned artifacts

**macOS — Sign:**
1. Import Apple Developer certificates from GitHub Secrets into temp keychain
2. Build all formats
3. Code sign with Developer ID Application certificate
4. Upload signed (but not notarized) artifacts

**macOS — Publish:**
1. Import Apple Developer certificates
2. Build all formats
3. Code sign
4. Notarize with Apple (uses `xcrun notarytool`, polls until complete)
5. Staple notarization ticket
6. Create signed PKG installer with Developer ID Installer certificate
7. Notarize the PKG
8. Create DMG
9. Upload to GitHub Release
10. Update gh-pages download links (if website exists)
11. Generate EdDSA-signed appcast (if auto-updates enabled)

**Windows — Verify:**
1. Build VST3, CLAP, Standalone
2. Run Catch2 tests + PluginVal validation
3. Upload unsigned artifacts

**Windows — Sign:**
1. Build VST3, CLAP, Standalone
2. Sign with Authenticode or Azure Trusted Signing (if secrets present)
3. Upload signed artifacts

**Windows — Publish:**
1. Build VST3, CLAP, Standalone
2. Sign binaries (if secrets present)
3. Create Inno Setup installer
4. Sign installer (if secrets present)
5. Upload to GitHub Release
6. Update gh-pages download links

**Linux — All modes:**
1. Build VST3, CLAP, Standalone
2. Run Catch2 tests + PluginVal validation
3. Package as tar.gz
4. Upload artifact (verify/sign) or to GitHub Release (publish)

> Linux has no code signing/notarization system relevant to audio plugins. Every major Linux plugin (Surge, Vital, Airwindows) ships plain archives. GPG signing exists for .deb/.rpm repos but adds complexity with no practical benefit for plugin distribution.

---

## 2. Per-Platform Signing Controls

### Design Principle: Graceful Degradation

Signing should **never cause a build failure**. If certs aren't configured, the build succeeds — just unsigned. This means:

- Forks and new users get clean builds without configuring any secrets
- Contributors can run CI on PRs without access to signing secrets
- Users can selectively enable signing per platform as they acquire certificates

### How It Works

```
For each platform in publish/sign mode:
  1. Are signing secrets configured for this platform?  → Yes/No
  2. Did the user explicitly disable signing for this platform?  → Yes/No

  Sign if: secrets exist AND user didn't disable
  Skip if: secrets missing OR user disabled

  Either way: build succeeds, artifact is uploaded
```

### Workflow Implementation

```yaml
jobs:
  build_and_test:
    steps:
      - name: Determine signing status
        id: signing
        run: |
          MODE="${{ github.event.inputs.mode || 'verify' }}"

          # macOS signing: needs certs + not disabled + not verify mode
          SIGN_MACOS="false"
          if [ "$MODE" != "verify" ] && \
             [ "${{ secrets.APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 }}" != "" ] && \
             [ "${{ github.event.inputs.sign_macos }}" != "false" ]; then
            SIGN_MACOS="true"
          fi

          # Windows signing: needs certs + not disabled + not verify mode
          # Supports two approaches: PFX (traditional) or Azure Trusted Signing
          SIGN_WINDOWS="false"
          if [ "$MODE" != "verify" ] && \
             [ "${{ github.event.inputs.sign_windows }}" != "false" ]; then
            if [ "${{ secrets.WINDOWS_CERT_PFX }}" != "" ] || \
               [ "${{ secrets.AZURE_CLIENT_ID }}" != "" ]; then
              SIGN_WINDOWS="true"
            fi
          fi

          echo "sign_macos=$SIGN_MACOS" >> $GITHUB_OUTPUT
          echo "sign_windows=$SIGN_WINDOWS" >> $GITHUB_OUTPUT
          echo "mode=$MODE" >> $GITHUB_OUTPUT

          # Summary for logs
          echo "Mode: $MODE"
          echo "Sign macOS: $SIGN_MACOS"
          echo "Sign Windows: $SIGN_WINDOWS"
```

### `/juce-dev:ci` Per-Platform Signing Flags

```
/juce-dev:ci publish                          # Publish all platforms, sign where certs exist
/juce-dev:ci publish --no-sign-macos          # Publish all, skip macOS signing
/juce-dev:ci publish --no-sign-windows        # Publish all, skip Windows signing
/juce-dev:ci publish --no-sign                # Publish all, skip all signing
/juce-dev:ci publish macos --no-sign          # Publish macOS only, unsigned
/juce-dev:ci sign                             # Sign-only mode (no release, no publish)
/juce-dev:ci sign macos                       # Sign macOS only
```

### Signing Status in CI Output

When signing is skipped, the workflow logs should clearly explain why:

```
macOS signing: SKIPPED (no APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 secret found)
Windows signing: SKIPPED (user passed --no-sign-windows)
Linux signing: N/A (not applicable for Linux)
```

---

## 3. GitHub Secrets Required

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

### Windows Signing — Option A: Traditional Authenticode (PFX Certificate)

For developers who have a code signing certificate from a CA (Sectigo, DigiCert, GlobalSign, etc.).

| Secret Name | Source (.env variable) | What it is |
|------------|----------------------|------------|
| `WINDOWS_CERT_PFX` | Exported .pfx, base64-encoded | Base64-encoded .pfx code signing certificate |
| `WINDOWS_CERT_PASSWORD` | Set during export | Password for the .pfx file |

**How to prepare:**
```bash
# Export your certificate as .pfx from Windows Certificate Manager or your CA's portal
# Then base64-encode it:
base64 -i certificate.pfx | pbcopy   # macOS
certutil -encode certificate.pfx cert_base64.txt   # Windows
```

**How signing works in CI:**
```yaml
- name: Import Windows Certificate
  if: steps.signing.outputs.sign_windows == 'true' && runner.os == 'Windows'
  shell: powershell
  env:
    WINDOWS_CERT_PFX: ${{ secrets.WINDOWS_CERT_PFX }}
    WINDOWS_CERT_PASSWORD: ${{ secrets.WINDOWS_CERT_PASSWORD }}
  run: |
    $pfxBytes = [Convert]::FromBase64String($env:WINDOWS_CERT_PFX)
    $pfxPath = "$env:RUNNER_TEMP\certificate.pfx"
    [IO.File]::WriteAllBytes($pfxPath, $pfxBytes)
    Import-PfxCertificate -FilePath $pfxPath `
      -CertStoreLocation Cert:\CurrentUser\My `
      -Password (ConvertTo-SecureString -String $env:WINDOWS_CERT_PASSWORD -AsPlainText -Force)

- name: Sign Windows Binaries
  if: steps.signing.outputs.sign_windows == 'true' && runner.os == 'Windows'
  shell: powershell
  env:
    WINDOWS_CERT_PASSWORD: ${{ secrets.WINDOWS_CERT_PASSWORD }}
  run: |
    $signtool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"
    $pfxPath = "$env:RUNNER_TEMP\certificate.pfx"

    # Sign VST3
    & $signtool sign /f $pfxPath /p $env:WINDOWS_CERT_PASSWORD `
      /tr http://timestamp.digicert.com /td sha256 /fd sha256 `
      "${{ env.BUILD_DIR }}\${{ env.PROJECT_NAME }}_artefacts\Release\VST3\${{ env.PROJECT_NAME }}.vst3\Contents\x86_64-win\${{ env.PROJECT_NAME }}.vst3"

    # Sign Standalone
    & $signtool sign /f $pfxPath /p $env:WINDOWS_CERT_PASSWORD `
      /tr http://timestamp.digicert.com /td sha256 /fd sha256 `
      "${{ env.BUILD_DIR }}\${{ env.PROJECT_NAME }}_artefacts\Release\Standalone\${{ env.PROJECT_NAME }}.exe"
```

**Important — EV certificates and HSMs:** Since June 2023, CAs must issue code signing certificates on hardware security modules (HSMs). This means traditional PFX files are becoming less common. Many CAs now offer cloud-based HSM signing (DigiCert KeyLocker, Sectigo Certificate Manager) which have their own CLI tools. If your CA provides a cloud signing service, you may need additional secrets specific to their tooling.

### Windows Signing — Option B: Azure Trusted Signing

Microsoft's cloud-based signing service. No PFX file — signing happens entirely in Azure. ~$10/month (Basic tier). **Big advantage:** Instant SmartScreen reputation (no waiting period for users to stop seeing "Windows protected your PC" warnings).

| Secret Name | Source (.env variable) | What it is |
|------------|----------------------|------------|
| `AZURE_TENANT_ID` | `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_CLIENT_ID` | `AZURE_CLIENT_ID` | Azure service principal app ID |
| `AZURE_CLIENT_SECRET` | `AZURE_CLIENT_SECRET` | Azure service principal secret |
| `AZURE_SUBSCRIPTION_ID` | `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AZURE_SIGNING_ACCOUNT` | `AZURE_SIGNING_ACCOUNT` | Trusted Signing account name |
| `AZURE_SIGNING_PROFILE` | `AZURE_SIGNING_PROFILE` | Certificate profile name |
| `AZURE_SIGNING_ENDPOINT` | `AZURE_SIGNING_ENDPOINT` | e.g., `https://eus.codesigning.azure.net` |

**How signing works in CI:**
```yaml
- name: Azure Login
  if: steps.signing.outputs.sign_windows == 'true' && runner.os == 'Windows'
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

- name: Sign with Azure Trusted Signing
  if: steps.signing.outputs.sign_windows == 'true' && runner.os == 'Windows'
  uses: azure/trusted-signing-action@v0.5.0
  with:
    azure-tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    azure-client-id: ${{ secrets.AZURE_CLIENT_ID }}
    azure-client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
    endpoint: ${{ secrets.AZURE_SIGNING_ENDPOINT }}
    trusted-signing-account-name: ${{ secrets.AZURE_SIGNING_ACCOUNT }}
    certificate-profile-name: ${{ secrets.AZURE_SIGNING_PROFILE }}
    files-folder: ${{ env.BUILD_DIR }}\${{ env.PROJECT_NAME }}_artefacts\Release
    files-folder-filter: exe,dll,vst3
    file-digest: SHA256
    timestamp-rfc3161: http://timestamp.acs.microsoft.com
    timestamp-digest: SHA256
```

### Windows Signing — SmartScreen ("Notarization" Equivalent)

There is **no notarization step** on Windows. SmartScreen is passive and reputation-based:

| Certificate Type | SmartScreen Behavior |
|-----------------|---------------------|
| **Unsigned** | "Windows protected your PC" warning every time |
| **OV-signed (traditional PFX)** | Warning fades after enough downloads (weeks, hundreds of installs) |
| **EV-signed or Azure Trusted Signing** | Immediate trust, no warning period |

There is nothing to submit or wait for in CI — signing is the entire action.

### Linux Signing

**Not applicable for audio plugins.** Linux has no centralized code signing or notarization system. GPG signing exists for .deb/.rpm package repositories, but:

- Every major Linux audio plugin ships plain .tar.gz archives (Surge, Vital, Airwindows, Dexed)
- Users don't see warnings for unsigned executables
- Adding GPG signing adds complexity with no practical user-facing benefit

If package repository signing becomes relevant in the future, the secrets would be:

| Secret Name | What it is |
|------------|------------|
| `GPG_PRIVATE_KEY` | ASCII-armored GPG private key |
| `GPG_PASSPHRASE` | Passphrase for the key |

**Recommendation:** Skip Linux signing. Ship tar.gz.

### General (Auto-Updates)

| Secret Name | Source (.env variable) | What it is |
|------------|----------------------|------------|
| `EDDSA_PRIVATE_KEY` | `AUTO_UPDATE_EDDSA_PUBLIC_KEY` (private counterpart) | EdDSA key for Sparkle/WinSparkle signing |

### How macOS Certificates Get Into CI

```yaml
- name: Import Apple Certificates
  if: steps.signing.outputs.sign_macos == 'true' && runner.os == 'macOS'
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

## 4. Secrets Management via `/juce-dev:ci`

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
For macOS P12 certificates, the command should walk the user through:
1. Open Keychain Access
2. Find "Developer ID Application" certificate
3. Right-click → Export → .p12 format
4. Base64 encode: `base64 -i cert.p12 | pbcopy`
5. The command then pushes the base64 string as a GitHub Secret

For Windows PFX certificates:
1. Export from Windows Certificate Manager or your CA's portal
2. Base64 encode: `certutil -encode certificate.pfx cert_base64.txt`
3. Push via `gh secret set WINDOWS_CERT_PFX --body "$(cat cert_base64.txt)"`

For Azure Trusted Signing:
1. Create Azure Trusted Signing account in Azure Portal
2. Create a service principal with signing permissions
3. Configure each secret individually via `/juce-dev:ci secrets push`

---

## 5. `.env.example` Updates

Add the following to `.env.example` so users know what's available:

```env
# ── CI/CD Configuration ──────────────────────────────────────────────
# Which platforms to build in CI (comma-separated)
# Options: macos, windows, linux (or "all" to auto-detect)
CI_PLATFORMS="macos"

# ── Windows Code Signing (Option A: Traditional Authenticode) ────────
# Buy a certificate from a CA (Sectigo, DigiCert, GlobalSign, etc.)
# Export as .pfx, then base64-encode: base64 -i cert.pfx | pbcopy
# WINDOWS_CERT_PFX_BASE64=""
# WINDOWS_CERT_PASSWORD=""

# ── Windows Code Signing (Option B: Azure Trusted Signing) ──────────
# Cloud-based signing (~$10/month). Instant SmartScreen reputation.
# See: https://learn.microsoft.com/en-us/azure/trusted-signing/
# AZURE_TENANT_ID=""
# AZURE_CLIENT_ID=""
# AZURE_CLIENT_SECRET=""
# AZURE_SUBSCRIPTION_ID=""
# AZURE_SIGNING_ACCOUNT=""
# AZURE_SIGNING_PROFILE=""
# AZURE_SIGNING_ENDPOINT=""
```

---

## 6. `/juce-dev:ci` Command Spec (Updated)

### Full Command Reference

```
# ── CI Only (verify builds compile and pass tests) ──────────────────
/juce-dev:ci                          # Show config, offer to trigger or change
/juce-dev:ci macos                    # Trigger macOS-only CI build (verify mode)
/juce-dev:ci macos,windows            # Trigger macOS + Windows
/juce-dev:ci all                      # Trigger all configured platforms

# ── CD (sign, package, release) ─────────────────────────────────────
/juce-dev:ci sign                     # Build + sign only (no release)
/juce-dev:ci sign macos               # Sign macOS only
/juce-dev:ci publish                  # Full release pipeline
/juce-dev:ci publish macos            # Publish macOS only
/juce-dev:ci publish --no-sign-macos  # Publish but skip macOS signing
/juce-dev:ci publish --no-sign-windows # Publish but skip Windows signing
/juce-dev:ci publish --no-sign        # Publish all platforms unsigned
/juce-dev:ci publish --no-release     # Sign + package but don't create GitHub Release

# ── Monitoring ──────────────────────────────────────────────────────
/juce-dev:ci status                   # Show last 5 CI runs with results
/juce-dev:ci logs                     # Show logs from latest run
/juce-dev:ci logs <run-id>            # Show logs from specific run

# ── Secrets Management ──────────────────────────────────────────────
/juce-dev:ci secrets                  # Show sync status (local .env vs GitHub Secrets)
/juce-dev:ci secrets push             # Push .env values to GitHub Secrets
/juce-dev:ci secrets pull             # Add placeholders for missing .env entries

# ── Help ────────────────────────────────────────────────────────────
/juce-dev:ci --help                   # Show full reference
```

### Mode Summary

| Mode | What it does | Signing | Release | When to use |
|------|-------------|---------|---------|-------------|
| `verify` (default) | Build + test | Never | No | Every push, PRs, quick checks |
| `sign` | Build + test + sign | If certs exist | No | Test signing setup, pre-release QA |
| `publish` | Build + test + sign + package + release | If certs exist | Yes (default) | Shipping a release |

### Per-Platform Signing Flags

| Flag | Effect |
|------|--------|
| `--no-sign` | Skip signing on all platforms |
| `--no-sign-macos` | Skip macOS signing only |
| `--no-sign-windows` | Skip Windows signing only |
| `--no-release` | Do everything except create GitHub Release |

These flags only apply to `sign` and `publish` modes. `verify` mode never signs.

---

## 7. Website Integration

When publish mode completes and creates a GitHub Release, the workflow should also update the gh-pages website.

This connects directly to the website-proposal.md work:
- `scripts/update_download_links.sh` updates download buttons on gh-pages
- Uses marker-comment block replacement (DOWNLOAD-MACOS-START/END, etc.)
- Works for both macOS (.pkg) and Windows (_Setup.exe) releases

### CI Publish Step (after release creation)

```yaml
- name: Update Website Download Links
  if: steps.signing.outputs.mode == 'publish'
  run: |
    if git ls-remote --heads origin gh-pages | grep -q gh-pages; then
      ./scripts/update_download_links.sh
    else
      echo "No gh-pages branch found. Tip: Run /juce-dev:website to create a download page."
    fi
```

This step runs AFTER the GitHub Release is created, so download URLs are valid.

---

## 8. Implementation Phases

### Phase A: Production CI Workflow

**A.1** Add `mode` input to workflow_dispatch (verify / sign / publish)
**A.2** Add per-platform signing toggle inputs (`sign_macos`, `sign_windows`)
**A.3** Add signing status detection step (check secrets + user overrides)
**A.4** Add certificate import step for macOS (temp keychain approach)
**A.5** Add Windows PFX signing step (conditional on `WINDOWS_CERT_PFX` existing)
**A.6** Add Azure Trusted Signing step (conditional on `AZURE_CLIENT_ID` existing)
**A.7** Add publish steps: call `./scripts/build.sh all publish` instead of raw cmake
**A.8** Add release tag trigger (`on: release: types: [created]`)
**A.9** Add `create_release` toggle and release creation job
**A.10** Test end-to-end: trigger publish, verify signed artifacts on GitHub Release
**A.11** Update README FAQ with publish mode and signing docs

### Phase B: Secrets Management

**B.1** Add `secrets` subcommand to `/juce-dev:ci` command
**B.2** Implement secret existence checking (`gh secret list`)
**B.3** Implement push flow (`.env` → GitHub Secrets) for all platforms
**B.4** Implement pull flow (placeholder generation for missing `.env` entries)
**B.5** Add macOS certificate export guidance (Keychain → .p12 → base64 → secret)
**B.6** Add Windows PFX export guidance
**B.7** Add Azure Trusted Signing setup guidance
**B.8** Update `.env.example` with Windows signing variables
**B.9** Test: fresh repo with no secrets, push from `.env`, verify publish works

### Phase C: Website Integration (depends on website-proposal.md Phase 1)

**C.1** Add `update_download_links.sh` call to publish workflow
**C.2** Ensure gh-pages worktree works in CI environment
**C.3** Test: publish triggers website update, download buttons activate
**C.4** Handle first activation (stub→active) vs updates (version bump)

### Phase D: `/juce-dev:ci` Enhancements

**D.1** Add `publish` and `sign` subcommands to `/juce-dev:ci`
**D.2** Add `--no-sign`, `--no-sign-macos`, `--no-sign-windows`, `--no-release` flags
**D.3** Add secrets status to `/juce-dev:ci` default output (show what's configured)
**D.4** Add guidance for which secrets are needed based on CI_PLATFORMS
**D.5** Monitor publish runs and report signing/notarization status
**D.6** Show per-platform signing status: "macOS: signed, Windows: unsigned (no certs), Linux: N/A"

---

## 9. Decision: Where Does This Work Live?

### Option 1: Continue on `integrate/cross-platform`

Pro: Everything in one branch, easy to test together.
Con: Branch is getting large, mixes verification CI with production CI.

### Option 2: New `feature/ci-publish` branch from `integrate/cross-platform`

Pro: Clean separation, can merge cross-platform to main first.
Con: Needs cross-platform merged first.

### Recommendation

**Merge `integrate/cross-platform` to main first** (it's tested and passing CI), then create `feature/ci-publish` for the production pipeline work. The website work can either go on `feature/website` (as the proposal suggests) or be combined with `feature/ci-publish` since they're tightly coupled.

---

## 10. Relationship to Website Proposal

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

## 11. Open Questions

1. **Should publish mode create the GitHub Release, or should the user create it and CI attaches assets?** Creating a release tag and having CI do everything is cleaner, but some users want control over release notes. The `create_release` toggle provides flexibility — default is to create, but users can disable it and create the release manually.

2. **Notarization wait time**: Apple notarization can take 1-15 minutes. Should the CI job poll and wait, or should it be a separate workflow that runs after notarization completes? Current `build.sh` polls — same approach could work in CI.

3. **Should we support publishing from CI for BOTH platforms in one run?** e.g., a single "publish" dispatch creates a macOS release AND a Windows release. Or should each platform publish independently? Independent is simpler but means two separate release assets get attached to the same GitHub Release at different times.

4. **Private repo releases**: If the repo is private, GitHub Release download URLs are also private. The website-proposal.md handles this with a separate public website repo. Should CI publish to the website repo too?

5. **Windows signing approach preference**: Should the template default to Azure Trusted Signing (simpler, instant SmartScreen) or traditional PFX (more familiar, no monthly cost)? The workflow supports both — auto-detects which secrets are present and uses the appropriate method.
