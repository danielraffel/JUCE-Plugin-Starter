# build.ps1 - Windows build script for JUCE-Plugin-Starter
# Equivalent to build.sh for Windows (MSVC + Ninja)
#
# Usage:
#   .\scripts\build.ps1                    # Build all formats
#   .\scripts\build.ps1 vst3               # Build VST3 only
#   .\scripts\build.ps1 standalone         # Build Standalone only
#   .\scripts\build.ps1 all test           # Build and run tests
#   .\scripts\build.ps1 clap              # Build CLAP only

param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Success($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host $msg -ForegroundColor Red }

# Find project root
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Set-Location $ProjectRoot

# Load .env file
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim().Trim('"').Trim("'")
            [Environment]::SetEnvironmentVariable($key, $val, "Process")
        }
    }
} else {
    Write-Err "Error: .env file not found"
    exit 1
}

# Read required variables
$ProjectName = $env:PROJECT_NAME
$BundleId = $env:PROJECT_BUNDLE_ID
$CompanyName = $env:COMPANY_NAME
$VersionMajor = if ($env:VERSION_MAJOR) { $env:VERSION_MAJOR } else { "1" }
$VersionMinor = if ($env:VERSION_MINOR) { $env:VERSION_MINOR } else { "0" }
$VersionPatch = if ($env:VERSION_PATCH) { $env:VERSION_PATCH } else { "0" }
$Version = "$VersionMajor.$VersionMinor.$VersionPatch"

if (-not $ProjectName -or -not $BundleId) {
    Write-Err "Error: PROJECT_NAME and PROJECT_BUNDLE_ID must be set in .env"
    exit 1
}

# Parse arguments
$Targets = @()
$Action = "local"
$BuildConfig = "Release"

foreach ($arg in $Args) {
    switch ($arg) {
        { $_ -in "all","vst3","clap","standalone" } { $Targets += $_ }
        { $_ -in "local","test","sign","publish","unsigned" } { $Action = $_ }
        "debug" { $BuildConfig = "Debug" }
        "release" { $BuildConfig = "Release" }
        default { Write-Warn "Unknown argument: $arg" }
    }
}

if ($Targets.Count -eq 0) { $Targets = @("all") }

# Determine formats
$BuildFormats = @()
foreach ($target in $Targets) {
    switch ($target) {
        "all" { $BuildFormats = @("VST3", "CLAP", "Standalone") }
        "vst3" { if ("VST3" -notin $BuildFormats) { $BuildFormats += "VST3" } }
        "clap" { if ("CLAP" -notin $BuildFormats) { $BuildFormats += "CLAP" } }
        "standalone" { if ("Standalone" -notin $BuildFormats) { $BuildFormats += "Standalone" } }
    }
}

Write-Success "Building $ProjectName v$Version ($BuildConfig)"
Write-Host "Formats: $($BuildFormats -join ', ')"
Write-Host "Action: $Action"

# Configure with CMake + Ninja
$BuildDir = "build"
if (-not (Test-Path $BuildDir)) {
    Write-Success "Configuring CMake with Ninja..."
    cmake -B $BuildDir -G Ninja `
        -DCMAKE_BUILD_TYPE=$BuildConfig `
        -DCMAKE_CXX_STANDARD=17
    if ($LASTEXITCODE -ne 0) {
        Write-Err "CMake configuration failed"
        exit 1
    }
}

# Build each format
foreach ($format in $BuildFormats) {
    $targetName = "${ProjectName}_${format}"
    Write-Success "Building ${format}: ${targetName}"
    cmake --build $BuildDir --config $BuildConfig --target $targetName
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Build failed for $targetName"
        exit 1
    }
}

# Run tests if requested
if ($Action -eq "test") {
    # Build and run Catch2 tests
    $testBinary = Join-Path $BuildDir "Tests_artefacts\$BuildConfig\Tests.exe"
    if (Test-Path (Join-Path $BuildDir "CMakeFiles")) {
        Write-Success "Building Catch2 test target..."
        cmake --build $BuildDir --config $BuildConfig --target Tests
        if (Test-Path $testBinary) {
            Write-Success "Running Catch2 unit tests..."
            & $testBinary --reporter console
            if ($LASTEXITCODE -ne 0) {
                Write-Err "Catch2 tests failed!"
                exit 1
            }
            Write-Success "Catch2 tests passed."
        }
    }

    # PluginVal (if installed)
    $pluginval = Get-Command pluginval -ErrorAction SilentlyContinue
    if ($pluginval) {
        foreach ($format in $BuildFormats) {
            if ($format -eq "VST3") {
                $vst3Path = Join-Path $BuildDir "${ProjectName}_artefacts\$BuildConfig\VST3\${ProjectName}.vst3"
                if (Test-Path $vst3Path) {
                    Write-Success "Testing VST3: $vst3Path"
                    pluginval --validate-in-process --validate $vst3Path
                }
            }
        }
    } else {
        Write-Warn "PluginVal not found. Install from: https://github.com/Tracktion/pluginval"
    }
}

# Launch standalone if local build
if ($Action -eq "local" -and "Standalone" -in $BuildFormats) {
    $standaloneExe = Join-Path $BuildDir "${ProjectName}_artefacts\$BuildConfig\Standalone\${ProjectName}.exe"
    if (Test-Path $standaloneExe) {
        Write-Success "Launching standalone..."
        Start-Process $standaloneExe
    }
}

# Create installer if publish or unsigned action
if ($Action -in "publish","unsigned") {
    $artifactsDir = Join-Path $ProjectRoot "installer-artifacts"
    if (Test-Path $artifactsDir) { Remove-Item -Recurse -Force $artifactsDir }
    New-Item -ItemType Directory -Path $artifactsDir | Out-Null

    # Copy built plugins to artifacts
    foreach ($format in $BuildFormats) {
        $srcDir = Join-Path $BuildDir "${ProjectName}_artefacts\$BuildConfig\$format"
        if (Test-Path $srcDir) {
            $destDir = Join-Path $artifactsDir $format
            Copy-Item -Recurse $srcDir $destDir
            Write-Success "Copied $format artifacts"
        }
    }

    # Check for Inno Setup
    $iscc = Get-Command iscc -ErrorAction SilentlyContinue
    if (-not $iscc) {
        $innoPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
        if (Test-Path $innoPath) { $iscc = $innoPath }
    }

    if ($iscc) {
        $issTemplate = Join-Path $ProjectRoot "templates\installer.iss"
        if (Test-Path $issTemplate) {
            Write-Success "Creating installer with Inno Setup..."
            & $iscc /DAppName="$ProjectName" /DAppVersion="$Version" `
                /DAppPublisher="$CompanyName" /DAppBundleId="$BundleId" `
                /O"$([Environment]::GetFolderPath('Desktop'))" $issTemplate
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Installer created on Desktop"
            } else {
                Write-Err "Inno Setup failed"
            }
        }
    } else {
        Write-Warn "Inno Setup not found. Install from: https://jrsoftware.org/issetup.exe"
        Write-Host "Artifacts are available at: $artifactsDir"
    }
}

Write-Success "Build complete!"
