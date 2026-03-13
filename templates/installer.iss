; Inno Setup installer template for JUCE-Plugin-Starter (Windows)
; Placeholders are replaced by build.ps1 during packaging
;
; Usage: iscc /D"AppName={{PROJECT_NAME}}" /D"AppVersion={{VERSION}}" installer.iss

#ifndef AppName
  #define AppName "{{PROJECT_NAME}}"
#endif
#ifndef AppVersion
  #define AppVersion "{{VERSION}}"
#endif
#ifndef AppPublisher
  #define AppPublisher "{{COMPANY_NAME}}"
#endif
#ifndef AppBundleId
  #define AppBundleId "{{PROJECT_BUNDLE_ID}}"
#endif

[Setup]
AppId={#AppBundleId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputBaseFilename={#AppName}_{#AppVersion}_Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=yes

[Files]
; VST3 plugin
Source: "artifacts\VST3\{#AppName}.vst3\*"; DestDir: "{commoncf}\VST3\{#AppName}.vst3"; Flags: recursesubdirs; Check: ShouldInstallVST3
; CLAP plugin
Source: "artifacts\CLAP\{#AppName}.clap\*"; DestDir: "{commoncf}\CLAP\{#AppName}.clap"; Flags: recursesubdirs; Check: ShouldInstallCLAP
; Standalone app
Source: "artifacts\Standalone\{#AppName}.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: ShouldInstallStandalone
; WinSparkle DLL for auto-updates (bundled alongside standalone)
Source: "artifacts\Standalone\WinSparkle.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist; Check: ShouldInstallStandalone
; DiagnosticKit (optional troubleshooting tool)
Source: "artifacts\Diagnostics\{#AppName} Diagnostics.exe"; DestDir: "{app}\Diagnostics"; Flags: ignoreversion skipifsourcedoesntexist; Tasks: diagnostics
Source: "artifacts\Diagnostics\.env"; DestDir: "{app}\Diagnostics"; Flags: ignoreversion skipifsourcedoesntexist; Tasks: diagnostics

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppName}.exe"; Check: ShouldInstallStandalone
Name: "{group}\{#AppName} Diagnostics"; Filename: "{app}\Diagnostics\{#AppName} Diagnostics.exe"; Tasks: diagnostics
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Tasks]
Name: "vst3"; Description: "Install VST3 plugin"; GroupDescription: "Plugin Formats:"; Flags: checkedonce
Name: "clap"; Description: "Install CLAP plugin"; GroupDescription: "Plugin Formats:"; Flags: checkedonce
Name: "standalone"; Description: "Install Standalone application"; GroupDescription: "Application:"; Flags: checkedonce
Name: "diagnostics"; Description: "Install Diagnostics tool (helps troubleshoot issues)"; GroupDescription: "Tools:"; Flags: checkedonce

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{commoncf}\VST3\{#AppName}.vst3"
Type: filesandordirs; Name: "{commoncf}\CLAP\{#AppName}.clap"

[Code]
function ShouldInstallVST3: Boolean;
begin
  Result := IsTaskSelected('vst3');
end;

function ShouldInstallCLAP: Boolean;
begin
  Result := IsTaskSelected('clap');
end;

function ShouldInstallStandalone: Boolean;
begin
  Result := IsTaskSelected('standalone');
end;
