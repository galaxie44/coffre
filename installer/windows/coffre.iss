; Coffre — installateur Windows par utilisateur (pas d'admin)
#define MyAppName "Coffre"
#define MyAppVersion "1.0.3"
#define MyAppPublisher "Coffre"
#define MyAppURL "https://github.com/galaxie44/coffre"
#define MyAppExeName "coffre.exe"
#define DistDir "..\payload"

[Setup]
AppId={{8F3C2A91-6B47-4E1D-9C08-C0FF5E11A2B4}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
DefaultDirName={localappdata}\Programs\Coffre
DefaultGroupName=Coffre
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename=Coffre-Setup-Windows
SetupIconFile=..\..\apps\coffre\assets\icon\coffre.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
MinVersion=10.0

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\Coffre.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\Coffre.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Lancer Coffre"; Flags: nowait postinstall

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
