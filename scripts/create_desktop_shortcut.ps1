param(
  [Parameter(Mandatory = $true)][string]$ExePath,
  [string]$IconPath = ""
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $ExePath)) {
  throw "Executable introuvable: $ExePath"
}

$desktop = [Environment]::GetFolderPath("Desktop")
$lnkPath = Join-Path $desktop "Coffre.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($lnkPath)
$shortcut.TargetPath = (Resolve-Path $ExePath).Path
$shortcut.WorkingDirectory = Split-Path -Parent $shortcut.TargetPath
$shortcut.Description = "Coffre - gestionnaire de mots de passe"
if ($IconPath -and (Test-Path $IconPath)) {
  $shortcut.IconLocation = (Resolve-Path $IconPath).Path
} else {
  $shortcut.IconLocation = "$($shortcut.TargetPath),0"
}
$shortcut.Save()
Write-Host "Raccourci cree: $lnkPath"

# Force Windows a recharger l'icone du raccourci
try {
  $code = @"
[DllImport("shell32.dll", CharSet = CharSet.Auto)]
public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
"@
  Add-Type -MemberDefinition $code -Name Shell32 -Namespace Win32 -ErrorAction SilentlyContinue
  [Win32.Shell32]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
} catch {}
