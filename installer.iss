; Elif Yayınları Installer Script
; Bu script Inno Setup ile Windows installer oluşturmak için kullanılır

#define MyAppName "Elif Yayınları"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Elif Yayınları"
#define MyAppExeName "akilli_tahta_proje_demo.exe"
#define MyAppAssocName "Elif Yayınları Kitap Dosyası"
#define MyAppAssocExt ".book"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt

[Setup]
AppId={{b7005cc2-f2d5-4b12-9708-1588a796a837}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\ElifYayinlari
DisableProgramGroupPage=yes
OutputDir=build\installer
OutputBaseFilename=ElifYayinlariSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Service account JSON dosyası
Source: "service_account.json"; DestDir: "{app}"; Flags: ignoreversion
; VC++ Runtime
Source: "build\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
; Debug launcher
Source: "launcher_debug.bat"; DestDir: "{app}"; Flags: ignoreversion
; Drawing Pen launcher
Source: "Cizim_Kalemi_Baslat.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; WorkingDir: "{app}"
; Drawing Pen shortcuts
Name: "{autoprograms}\Çizim Kalemi"; Filename: "{app}\Cizim_Kalemi_Baslat.bat"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Çizim Kalemi"; Filename: "{app}\Cizim_Kalemi_Baslat.bat"; Tasks: desktopicon; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"

[Run]
; Install VC++ Runtime first
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Visual C++ Runtime yükleniyor..."; Flags: waituntilterminated
; Launch application after install
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
