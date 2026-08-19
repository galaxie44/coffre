; Coffre — installateur Windows par utilisateur (pas d'admin)
#define MyAppName "Coffre"
#define MyAppVersion "1.0.11"
#define MyAppPublisher "Coffre"
#define MyAppURL "https://github.com/galaxie44/coffre"
#define MyAppExeName "coffre.exe"
#define DistDir "..\payload"
#define ChromeExtId "nkomcbokhoemfpdlbjnbhjlhfofmcodl"

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
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "native_host\*"
Source: "{#DistDir}\native_host\*"; DestDir: "{localappdata}\Coffre\native_host"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\Coffre.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\Coffre.ico"; Tasks: desktopicon
Name: "{autoprograms}\Coffre — Tout supprimer"; Filename: "{app}\Coffre-Supprimer-Tout.exe"; IconFilename: "{app}\Coffre.ico"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Lancer Coffre"; Flags: nowait postinstall

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
const
  ChromeExtId = '{#ChromeExtId}';

procedure RegisterNativeMessagingHost;
var
  ManifestPath: String;
  ResultCode: Integer;
  HostDir: String;
begin
  HostDir := ExpandConstant('{localappdata}\Coffre\native_host');
  ManifestPath := HostDir + '\com.coffre.bridge.json';
  if FileExists(HostDir + '\install_host.py') then
  begin
    if Exec('python', ExpandConstant('"' + HostDir + '\install_host.py" ' + ChromeExtId), '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      Exit;
    if Exec('py', ExpandConstant('-3 "' + HostDir + '\install_host.py" ' + ChromeExtId), '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      Exit;
  end;
  if FileExists(ManifestPath) then
  begin
    RegWriteStringValue(HKEY_CURRENT_USER, 'Software\Google\Chrome\NativeMessagingHosts\com.coffre.bridge', '', ManifestPath);
    RegWriteStringValue(HKEY_CURRENT_USER, 'Software\Microsoft\Edge\NativeMessagingHosts\com.coffre.bridge', '', ManifestPath);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    RegisterNativeMessagingHost;
end;
