; Lumen Desk one-click installer.
; Installs the PC service (auto-brightness + profiles + phone API),
; registers the logon task, opens the firewall, and optionally bundles
; the Lumen Desk Windows companion app. Build with Inno Setup 6+:
;   iscc installer\LumenDesk.iss
#define MyAppName "Lumen Desk"
#define MyAppVersion "1.2.0"
#define MyAppExe "LumenDesk.exe"

[Setup]
AppId={{7C4A1E2B-9D3F-4A5C-8B6E-2F1A3C4D5E60}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=Lumen Desk
DefaultDirName={autopf}\Lumen Desk
DefaultGroupName=Lumen Desk
PrivilegesRequired=admin
OutputDir=dist
OutputBaseFilename=LumenDesk-Setup-{#MyAppVersion}
SetupIconFile=..\pc_remote\windows\runner\resources\app_icon.ico
WizardImageFile=wizard.bmp
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName=Lumen Desk (phone remote + auto-brightness)
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full install (recommended)"
Name: "custom"; Description: "Custom"; Flags: iscustom

[Components]
Name: "service"; Description: "Lumen Desk PC service (required)"; Types: full custom; Flags: fixed
Name: "companion"; Description: "Lumen Desk Windows companion app"; Types: full

[Tasks]
Name: "autostart"; Description: "Start Lumen Desk when I log on (recommended)"; GroupDescription: "Startup:"; Components: service
Name: "firewall"; Description: "Let my phone through Windows Firewall (TCP port below)"; GroupDescription: "Phone access:"; Components: service
Name: "desktopicon"; Description: "Desktop shortcut"; GroupDescription: "Shortcuts:"; Components: companion

[Files]
Source: "..\src\*"; DestDir: "{app}\src"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "__pycache__"; Components: service
Source: "..\config\default.json"; DestDir: "{app}\config"; Flags: ignoreversion; Components: service
Source: "..\profiles\admin.json"; DestDir: "{app}\profiles"; Flags: ignoreversion; Components: service
Source: "..\profiles\guest.json"; DestDir: "{app}\profiles"; Flags: ignoreversion; Components: service
Source: "..\profiles\kid.json"; DestDir: "{app}\profiles"; Flags: ignoreversion; Components: service
Source: "..\phone_web\index.html"; DestDir: "{app}\phone_web"; Flags: ignoreversion; Components: service
Source: "tools\SetupTask.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion; Components: service
Source: "tools\RemoveTask.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion; Components: service
Source: "tools\Status.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion; Components: service
Source: "..\pc_remote\build\windows\x64\runner\Release\*"; DestDir: "{app}\companion"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: companion

[INI]
Filename: "{app}\config\install.ini"; Section: "server"; Key: "port"; String: "{code:GetPort}"; Components: service

[Icons]
Name: "{group}\Lumen Desk"; Filename: "{app}\companion\{#MyAppExe}"; Components: companion
Name: "{group}\Check status"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -NoExit -File ""{app}\tools\Status.ps1"""; Components: service
Name: "{group}\Uninstall Lumen Desk"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Lumen Desk"; Filename: "{app}\companion\{#MyAppExe}"; Tasks: desktopicon; Components: companion

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\SetupTask.ps1"" -Pin ""{code:GetPin}"" -Port {code:GetPort} -AppDir ""{app}"" -PythonW ""{code:GetPythonW}"""; StatusMsg: "Starting Lumen Desk service..."; Flags: runhidden waituntilterminated runasoriginaluser; Tasks: autostart

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\RemoveTask.ps1"" -AppDir ""{app}"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveService"

[Code]
var
  CfgPage: TInputQueryWizardPage;
  PythonWPath: String;

function FindPythonW(): String;
var
  Vers: array of String;
  V, P: String;
  I: Integer;
begin
  Result := '';
  Vers := ['3.14', '3.13', '3.12', '3.11'];
  for I := 0 to GetArrayLength(Vers) - 1 do begin
    V := Vers[I];
    if RegQueryStringValue(HKLM64, 'SOFTWARE\Python\PythonCore\' + V + '\InstallPath', '', P) or
       RegQueryStringValue(HKLM32, 'SOFTWARE\Python\PythonCore\' + V + '\InstallPath', '', P) or
       RegQueryStringValue(HKCU, 'SOFTWARE\Python\PythonCore\' + V + '\InstallPath', '', P) then begin
      if FileExists(P + '\pythonw.exe') then begin
        Result := P + '\pythonw.exe';
        Exit;
      end;
    end;
  end;
end;

function InitializeSetup(): Boolean;
var
  Res: Integer;
begin
  Result := True;
  PythonWPath := FindPythonW();
  if PythonWPath = '' then begin
    if MsgBox('Lumen Desk needs Python 3.11 or newer (with the "Add to PATH" option).' + #13#10 + #13#10 +
      'Open python.org to download it, then run this installer again?' + #13#10 + #13#10 +
      'Click No to install anyway (the service will not start without Python).',
      mbError, MB_YESNO) = IDYES then begin
      ShellExec('', 'https://www.python.org/downloads/', '', '', SW_SHOW, ewNoWait, Res);
      Result := False;
    end;
  end;
end;

procedure InitializeWizard;
begin
  CfgPage := CreateInputQueryPage(wpSelectTasks,
    'Phone connection', 'How will your phone reach this laptop?',
    'Same WiFi. The phone app asks for this PIN the first time it connects.');
  CfgPage.Add('Phone PIN (4+ characters):', False);
  CfgPage.Add('Port:', False);
  CfgPage.Values[0] := '1234';
  CfgPage.Values[1] := '5000';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Port: Integer;
begin
  Result := True;
  if CurPageID = CfgPage.ID then begin
    if Length(CfgPage.Values[0]) < 4 then begin
      MsgBox('The PIN must be at least 4 characters.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
    Port := StrToIntDef(CfgPage.Values[1], 0);
    if (Port < 1) or (Port > 65535) then begin
      MsgBox('The port must be between 1 and 65535.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;
end;

function GetPin(Param: String): String;
begin
  Result := CfgPage.Values[0];
end;

function GetPort(Param: String): String;
begin
  Result := CfgPage.Values[1];
end;

function GetPythonW(Param: String): String;
begin
  Result := PythonWPath;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Res: Integer;
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('firewall') then begin
    Exec('netsh.exe', 'advfirewall firewall delete rule name="Lumen Desk"',
      '', SW_HIDE, ewWaitUntilTerminated, Res);
    Exec('netsh.exe', 'advfirewall firewall add rule name="Lumen Desk" dir=in action=allow protocol=TCP localport=' + GetPort('') + ' profile=private',
      '', SW_HIDE, ewWaitUntilTerminated, Res);
  end;
end;
