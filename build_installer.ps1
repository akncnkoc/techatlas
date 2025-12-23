
# Find latest C# compiler
$cscPath = Join-Path $env:windir "Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path $cscPath)) {
    Write-Host "Error: csc.exe not found at $cscPath" -ForegroundColor Red
    exit 1
}

$sourceFile = "Installer_Bootstrap.cs"
$outputFile = "TechAtlas_Setup.exe"

Write-Host "Compiling $sourceFile..." -ForegroundColor Cyan

# References
$refs = "/reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.IO.Compression.dll"

# Compile
$iconPath = "windows\runner\resources\setup_icon.ico"
$command = "& '$cscPath' /target:winexe /out:$outputFile /win32icon:$iconPath $refs $sourceFile"
Invoke-Expression $command

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Successful: $outputFile" -ForegroundColor Green
    Write-Host "Size: $( (Get-Item $outputFile).Length / 1KB ) KB" -ForegroundColor Gray
} else {
    Write-Host "Build Failed!" -ForegroundColor Red
}
