# Self-Extracting EXE Oluşturucu
# Ana uygulama için tek tıkla çalışan portable exe

param(
    [string]$OutputName = "ElifYayinlari_Portable.exe"
)

Write-Host "=== Elif Yayınları Self-Extracting EXE Oluşturuluyor ===" -ForegroundColor Cyan
Write-Host ""

# 7-Zip kontrolü
$7zipPath = "C:\Program Files\7-Zip\7z.exe"
if (!(Test-Path $7zipPath)) {
    Write-Host "HATA: 7-Zip bulunamadı!" -ForegroundColor Red
    Write-Host "Lütfen 7-Zip'i kurun: https://www.7-zip.org/download.html" -ForegroundColor Yellow
    exit 1
}

# Release build kontrolü
$releaseDir = "build\windows\x64\runner\Release"
if (!(Test-Path $releaseDir)) {
    Write-Host "HATA: Release build bulunamadı!" -ForegroundColor Red
    Write-Host "Önce build alın: flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

# SFX konfigürasyon dosyası oluştur
$configContent = @"
;!@Install@!UTF-8!
Title="Elif Yayınları"
GUIMode="2"
RunProgram="hidcon:cmd /c install.bat"
;!@InstallEnd@!
"@

Set-Content -Path "sfx_config.txt" -Value $configContent -Encoding UTF8

Write-Host "Konfigürasyon dosyası oluşturuldu (Sessiz mod)" -ForegroundColor Gray

# Post-install batch script oluştur (kısayol oluşturma + uygulama başlatma)
$installBatchContent = @'
@echo off
setlocal EnableDelayedExpansion

REM Uygulamayı kapat (dosyaların üzerine yazılabilmesi için)
taskkill /F /IM "akilli_tahta_proje_demo.exe" > nul 2>&1

REM Mevcut dizini kaydet (burası extract edilen geçici dizin)
set "EXTRACT_DIR=%CD%"

REM Ana dizini belirle
set "INSTALL_DIR=%LOCALAPPDATA%\ElifYayinlari"

REM Kurulum dizinini oluştur
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM Tüm dosyaları LOCALAPPDATA'ya kopyala
xcopy /E /I /Y /Q "%EXTRACT_DIR%\*" "%INSTALL_DIR%\" > nul 2>&1

REM Gereksiz dosyaları temizle (hedefteki)
if exist "%INSTALL_DIR%\install.bat" del "%INSTALL_DIR%\install.bat"

REM Masaüstü kısayolu oluştur - Ana Uygulama
set "DESKTOP=%USERPROFILE%\Desktop"
set "SHORTCUT=%DESKTOP%\Elif Yayinlari.lnk"
set "TARGET=%INSTALL_DIR%\akilli_tahta_proje_demo.exe"

powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%SHORTCUT%'); $Shortcut.TargetPath = '%TARGET%'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.Description = 'Elif Yayinlari'; $Shortcut.Save()" > nul 2>&1

REM Masaüstü kısayolu oluştur - Çizim Kalemi
set "SHORTCUT_PEN=%DESKTOP%\Cizim Kalemi.lnk"
set "TARGET_PEN=%INSTALL_DIR%\Cizim_Kalemi_Baslat.bat"

if exist "%TARGET_PEN%" (
    powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%SHORTCUT_PEN%'); $Shortcut.TargetPath = '%TARGET_PEN%'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.IconLocation = '%TARGET%,0'; $Shortcut.Description = 'Cizim Kalemi'; $Shortcut.Save()" > nul 2>&1
)

REM Uygulamayı başlat
start "" "%TARGET%"

REM Geçici dosyaları temizle (extract edilen yer)
timeout /t 1 /nobreak > nul
rd /s /q "%EXTRACT_DIR%" > nul 2>&1

exit
'@

Set-Content -Path "install.bat" -Value $installBatchContent -Encoding ASCII

Write-Host "Kurulum batch scripti oluşturuldu" -ForegroundColor Gray

# Geçici arşiv dizini oluştur
$tempArchive = "temp_archive_sfx"
if (Test-Path $tempArchive) {
    Remove-Item $tempArchive -Recurse -Force
}
New-Item -ItemType Directory -Path $tempArchive -Force | Out-Null

# Release dosyalarını kopyala
Write-Host "Release dosyaları kopyalanıyor..." -ForegroundColor Green
Copy-Item "$releaseDir\*" -Destination $tempArchive -Recurse -Force

# Service account ekle
if (Test-Path "service_account.json") {
    Write-Host "  service_account.json ekleniyor..." -ForegroundColor Gray
    Copy-Item "service_account.json" -Destination $tempArchive -Force
}

# Çizim Kalemi launcher ekle
if (Test-Path "Cizim_Kalemi_Baslat.bat") {
    Write-Host "  Çizim Kalemi launcher ekleniyor..." -ForegroundColor Gray
    Copy-Item "Cizim_Kalemi_Baslat.bat" -Destination $tempArchive -Force
}

# Install batch script'i ekle
Write-Host "  Kurulum scripti ekleniyor..." -ForegroundColor Gray
Copy-Item "install.bat" -Destination $tempArchive -Force

# 7z arşivi oluştur
Write-Host "7z arşivi oluşturuluyor..." -ForegroundColor Green
$archiveName = "temp_archive.7z"
if (Test-Path $archiveName) {
    Remove-Item $archiveName -Force
}

# Dizin yapısını korumak için temp klasörün içine girip oradan zip'le
Push-Location $tempArchive
& $7zipPath a -t7z -mx9 "..\$archiveName" * | Out-Null
Pop-Location

# SFX modülünü al
$sfxModule = "C:\Program Files\7-Zip\7z.sfx"

# Self-extracting exe oluştur
Write-Host "Self-extracting exe oluşturuluyor..." -ForegroundColor Green

# Önce config'i binary olarak oku
$configBytes = [System.IO.File]::ReadAllBytes("sfx_config.txt")
$sfxBytes = [System.IO.File]::ReadAllBytes($sfxModule)
$archiveBytes = [System.IO.File]::ReadAllBytes($archiveName)

# Hepsini birleştir
$outputStream = [System.IO.File]::OpenWrite($OutputName)
$outputStream.Write($sfxBytes, 0, $sfxBytes.Length)
$outputStream.Write($configBytes, 0, $configBytes.Length)
$outputStream.Write($archiveBytes, 0, $archiveBytes.Length)
$outputStream.Close()

# Temizlik
Remove-Item $tempArchive -Recurse -Force
Remove-Item $archiveName -Force
Remove-Item "sfx_config.txt" -Force
Remove-Item "install.bat" -Force

# Boyut hesapla
$exeSize = (Get-Item $OutputName).Length / 1MB

Write-Host ""
Write-Host "=== TAMAMLANDI ===" -ForegroundColor Green
Write-Host "Self-extracting exe: $OutputName" -ForegroundColor Cyan
Write-Host "Boyut: $([math]::Round($exeSize, 2)) MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "Kullanım:" -ForegroundColor Yellow
Write-Host "  1. $OutputName dosyasını çift tıklayın" -ForegroundColor White
Write-Host "  2. Kurulum onay dialogunda 'Evet' seçin" -ForegroundColor White
Write-Host "  3. Otomatik kurulum:" -ForegroundColor White
Write-Host "     - Dosyalar: %LOCALAPPDATA%\ElifYayinlari" -ForegroundColor Gray
Write-Host "     - Masaüstü kısayolları oluşturulur" -ForegroundColor Gray
Write-Host "     - Uygulama otomatik başlar" -ForegroundColor Gray
Write-Host ""
Write-Host "Masaüstü Kısayolları:" -ForegroundColor Yellow
Write-Host "  - Elif Yayınları (ana uygulama)" -ForegroundColor White
Write-Host "  - Çizim Kalemi" -ForegroundColor White
Write-Host ""
Write-Host "Dağıtım:" -ForegroundColor Yellow
Write-Host "  Bu tek dosyayı kullanıcılara gönderin!" -ForegroundColor White
