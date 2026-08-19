; Coffre — suppression complète (programme + coffre + traces Windows)
; Ne laisse pas de désinstalleur : l'exécutable fait le ménage puis se termine.

#define MyAppName "Coffre — tout supprimer"
#define MyAppVersion "1.0.6"
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
WelcomeLabel2=Ce programme ferme Coffre, le désinstalle, puis détruit le coffre local (mots de passe, préférences, traces Windows) et supprime tous les fichiers Coffre du Bureau et des Téléchargements.%n%nCette action est IRRÉVERSIBLE. Sur Android, désinstallez simplement l'application depuis les paramètres du téléphone.
ButtonInstall=Tout supprimer
FinishedHeadingLabel=Coffre a été retiré
FinishedLabel=Coffre, le coffre chiffré, les raccourcis et tous les fichiers associés ont été supprimés de cet ordinateur.

[Code]
var
  ConfirmPage: TInputOptionWizardPage;

procedure InitializeWizard;
begin
  ConfirmPage := CreateInputOptionPage(
    wpWelcome,
    'Confirmation',
    'Tous les mots de passe de Coffre seront perdus.',
    'Cochez la case ci-dessous pour continuer. Aucune récupération n''est possible.',
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
  Sleep(1500);
end;

procedure DeleteIfExists(const FileName: String);
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

procedure DeleteCoffreFilesInFolder(const Folder: String);
begin
  { Installateurs }
  DeleteIfExists(Folder + '\Coffre-Setup-Windows.exe');
  DeleteIfExists(Folder + '\Coffre-Setup-Windows (1).exe');
  DeleteIfExists(Folder + '\Coffre-Setup-Windows (2).exe');
  DeleteIfExists(Folder + '\Coffre-Setup-Windows (3).exe');
  DeleteIfExists(Folder + '\Coffre-Supprimer-Tout.exe');
  DeleteIfExists(Folder + '\Coffre-Supprimer-Tout (1).exe');
  { APK }
  DeleteIfExists(Folder + '\Coffre.apk');
  DeleteIfExists(Folder + '\Coffre (1).apk');
  { Scripts et docs }
  DeleteIfExists(Folder + '\Installer Coffre.bat');
  DeleteIfExists(Folder + '\Installer Coffre (Admin).bat');
  DeleteIfExists(Folder + '\Coffre-LIREMOI.txt');
  DeleteIfExists(Folder + '\Coffre-logo.png');
  DeleteIfExists(Folder + '\coffre-logo.png');
end;

procedure UnpinFromTaskbar;
var
  TaskBarDir: String;
  FindRec: TFindRec;
begin
  TaskBarDir := ExpandConstant('{userappdata}\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar');
  if FindFirst(TaskBarDir + '\Coffre*.lnk', FindRec) then
  begin
    try
      repeat
        DeleteFile(TaskBarDir + '\' + FindRec.Name);
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
  { Windows 10+ peut aussi stocker dans ImplicitAppShortcuts }
  TaskBarDir := ExpandConstant('{userappdata}\Microsoft\Internet Explorer\Quick Launch\User Pinned\ImplicitAppShortcuts');
  if DirExists(TaskBarDir) then
  begin
    if FindFirst(TaskBarDir + '\*', FindRec) then
    begin
      try
        repeat
          if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
          begin
            if FileExists(TaskBarDir + '\' + FindRec.Name + '\Coffre.lnk') then
              DelTree(TaskBarDir + '\' + FindRec.Name, True, True, True);
          end;
        until not FindNext(FindRec);
      finally
        FindClose(FindRec);
      end;
    end;
  end;
end;

procedure RemoveCoffreTraces;
var
  ResultCode: Integer;
  Unins: String;
  Desktop: String;
  Downloads: String;
  UserProfile: String;
begin
  KillCoffre;

  { Désinstalleur Inno Setup }
  Unins := ExpandConstant('{localappdata}\Programs\Coffre\unins000.exe');
  if FileExists(Unins) then
    Exec(Unins, '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  KillCoffre;

  { Dossiers programme et données }
  DeleteCoffreDir(ExpandConstant('{localappdata}\Programs\Coffre'));
  DeleteCoffreDir(ExpandConstant('{userappdata}\Coffre'));
  DeleteCoffreDir(ExpandConstant('{userappdata}\com.coffre'));
  DeleteCoffreDir(ExpandConstant('{localappdata}\com.coffre'));
  DeleteCoffreDir(ExpandConstant('{localappdata}\Coffre'));

  { Raccourcis }
  DeleteIfExists(ExpandConstant('{userdesktop}\Coffre.lnk'));
  DeleteIfExists(ExpandConstant('{commondesktop}\Coffre.lnk'));
  DeleteIfExists(ExpandConstant('{userprograms}\Coffre.lnk'));
  DeleteIfExists(ExpandConstant('{commonprograms}\Coffre.lnk'));
  DeleteCoffreDir(ExpandConstant('{userprograms}\Coffre'));
  DeleteIfExists(ExpandConstant('{userstartup}\Coffre.lnk'));
  DeleteIfExists(ExpandConstant('{commonstartup}\Coffre.lnk'));

  { Désépingler de la barre des tâches }
  UnpinFromTaskbar;

  { Bureau — fichiers Coffre en vrac }
  Desktop := ExpandConstant('{userdesktop}');
  DeleteCoffreFilesInFolder(Desktop);
  DeleteIfContainsExe(Desktop + '\Coffre');

  { Téléchargements — fichiers Coffre }
  UserProfile := GetEnv('USERPROFILE');
  Downloads := UserProfile + '\Downloads';
  DeleteCoffreFilesInFolder(Downloads);
  { Aussi vérifier le dossier Téléchargements localisé }
  Downloads := UserProfile + '\Téléchargements';
  DeleteCoffreFilesInFolder(Downloads);

  { Temp }
  DeleteIfExists(ExpandConstant('{tmp}\Coffre.apk'));
  DeleteIfExists(ExpandConstant('{tmp}\Coffre-Setup-Windows.exe'));

  { Registre }
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
