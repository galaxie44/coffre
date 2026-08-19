; Coffre — suppression complète (programme + coffre + traces Windows)
; Ne laisse pas de désinstalleur : l’exécutable fait le ménage puis se termine.

#define MyAppName "Coffre — tout supprimer"
#define MyAppVersion "1.0.5"
#define MyAppPublisher "Coffre"
#define MyAppURL "https://github.com/galaxie44/coffre"
#define UninstallReg "Software\Microsoft\Windows\CurrentVersion\Uninstall\{8F3C2A91-6B47-4E1D-9C08-C0FF5E11A2B4}_is1"

[Setup]
AppId={{B7E2D4C1-9A18-4F60-8E3B-2C1F6A90D4E8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={tmp}\CoffreWipe
OutputDir=Output
OutputBaseFilename=Coffre-Supprimer-Tout
SetupIconFile=..\..\apps\coffre\assets\icon\coffre.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyMemo=yes
Uninstallable=no
CreateAppDir=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=force
RestartApplications=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Messages]
SetupWindowTitle=Coffre — tout supprimer
WelcomeLabel1=Tout supprimer
WelcomeLabel2=Ce programme ferme Coffre, le désinstalle, puis détruit le coffre local (mots de passe, préférences, traces Windows).%n%nCette action est IRRÉVERSIBLE. Sur Android, désinstallez simplement l’application depuis les paramètres du téléphone.
ButtonInstall=Tout supprimer
FinishedHeadingLabel=Coffre a été retiré
FinishedLabel=Coffre, le coffre chiffré et les raccourcis ont été supprimés de cet ordinateur.

[Code]
var
  ConfirmPage: TInputOptionWizardPage;

procedure InitializeWizard;
begin
  ConfirmPage := CreateInputOptionPage(
    wpWelcome,
    'Confirmation',
    'Tous les mots de passe de Coffre seront perdus.',
    'Cochez la case ci-dessous pour continuer. Aucune récupération n’est possible.',
    False,
    False
  );
  ConfirmPage.Add('Je comprends que le coffre et tous les mots de passe seront détruits');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = ConfirmPage.ID then
  begin
    if not ConfirmPage.Values[0] then
    begin
      MsgBox('Cochez la case pour confirmer la suppression.', mbError, MB_OK);
      Result := False;
    end
    else if MsgBox(
      'Dernière confirmation : supprimer Coffre et toutes ses données maintenant ?',
      mbConfirmation, MB_YESNO) <> IDYES then
      Result := False;
  end;
end;

procedure KillCoffre;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM coffre.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1200);
end;

procedure DeleteShortcut(const FileName: String);
begin
  if FileExists(FileName) then
    DeleteFile(FileName);
end;

procedure DeleteCoffreDir(const Dir: String);
begin
  if DirExists(Dir) then
    DelTree(Dir, True, True, True);
end;

procedure DeleteIfContainsExe(const Dir: String);
begin
  if FileExists(Dir + '\coffre.exe') or FileExists(Dir + '\Coffre.exe') then
    DeleteCoffreDir(Dir);
end;

procedure RemoveCoffreTraces;
var
  ResultCode: Integer;
  Unins: String;
begin
  KillCoffre;

  Unins := ExpandConstant('{localappdata}\Programs\Coffre\unins000.exe');
  if FileExists(Unins) then
    Exec(Unins, '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  KillCoffre;

  DeleteCoffreDir(ExpandConstant('{localappdata}\Programs\Coffre'));
  DeleteCoffreDir(ExpandConstant('{userappdata}\Coffre'));
  DeleteCoffreDir(ExpandConstant('{userappdata}\com.coffre'));
  DeleteCoffreDir(ExpandConstant('{localappdata}\com.coffre'));
  DeleteCoffreDir(ExpandConstant('{localappdata}\Coffre'));
  DeleteIfContainsExe(ExpandConstant('{userdesktop}\Coffre'));

  DeleteShortcut(ExpandConstant('{userdesktop}\Coffre.lnk'));
  DeleteShortcut(ExpandConstant('{commondesktop}\Coffre.lnk'));
  DeleteShortcut(ExpandConstant('{userprograms}\Coffre.lnk'));
  DeleteShortcut(ExpandConstant('{commonprograms}\Coffre.lnk'));
  DeleteCoffreDir(ExpandConstant('{userprograms}\Coffre'));
  DeleteShortcut(ExpandConstant('{userstartup}\Coffre.lnk'));
  DeleteShortcut(ExpandConstant('{commonstartup}\Coffre.lnk'));

  if FileExists(ExpandConstant('{tmp}\Coffre.apk')) then
    DeleteFile(ExpandConstant('{tmp}\Coffre.apk'));
  if FileExists(ExpandConstant('{tmp}\Coffre-Setup-Windows.exe')) then
    DeleteFile(ExpandConstant('{tmp}\Coffre-Setup-Windows.exe'));

  RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Coffre');
  RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, '{#UninstallReg}');
  RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Google\Chrome\NativeMessagingHosts\com.coffre.bridge');
  RegDeleteKeyIncludingSubkeys(HKEY_CURRENT_USER, 'Software\Microsoft\Edge\NativeMessagingHosts\com.coffre.bridge');
  RegDeleteValue(HKEY_CURRENT_USER, 'Software\Policies\Google\Chrome', 'PasswordManagerEnabled');
  RegDeleteValue(HKEY_CURRENT_USER, 'Software\Policies\Google\Chrome', 'PasswordManagerPasskeysEnabled');
  RegDeleteValue(HKEY_CURRENT_USER, 'Software\Policies\Microsoft\Edge', 'PasswordManagerEnabled');
  RegDeleteValue(HKEY_CURRENT_USER, 'Software\Policies\Microsoft\Edge', 'PasswordManagerPasskeysEnabled');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
    RemoveCoffreTraces;
end;
