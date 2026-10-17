; Installer di ScrolleR Studio (Inno Setup 6). Si compila con packaging\build.py,
; che passa AppVersion, SourceDir, OutputDir e IconFile.

#define AppName "ScrolleR Studio"
#define AppExe "ScrolleR Studio.exe"
; ProgId e AppUserModelID restano quelli di "SCRL Studio": cambiarli romperebbe associazioni e aggiornamenti
#define ProgId "SCRL.Studio.Project"

[Setup]
; AppId fisso: non cambiarlo, serve a riconoscere gli aggiornamenti
AppId={{6E2B9C41-5D7A-4F0E-9B3C-8A1F2D4E7C90}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=ScrolleR
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Installazione per l'utente senza permessi di amministratore, con possibilità di scegliere per tutti
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=ScrolleR-Studio-Setup-{#AppVersion}
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ChangesAssociations=yes
CloseApplications=yes

[Languages]
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "assoc"; Description: "Apri i progetti .scrlproj con {#AppName}"; GroupDescription: "Associazioni file:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Aggiornando da "SCRL Studio" (1.0.0): toglie il vecchio exe e i vecchi collegamenti
Type: files; Name: "{app}\SCRL Studio.exe"
Type: files; Name: "{autoprograms}\SCRL Studio.lnk"
Type: files; Name: "{autodesktop}\SCRL Studio.lnk"

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "SCRL.Studio"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; AppUserModelID: "SCRL.Studio"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Classes\.scrlproj"; ValueType: string; ValueName: ""; ValueData: "{#ProgId}"; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\.scrlproj\OpenWithProgids"; ValueType: string; ValueName: "{#ProgId}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueName: ""; ValueData: "Progetto ScrolleR Studio"; Flags: uninsdeletekey; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExe},0"; Tasks: assoc
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""; Tasks: assoc

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
