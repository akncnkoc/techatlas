# Ana Uygulamayı ZIP Olarak Paketleme
# Bu script ana uygulamayı GitHub Release için hazırlar

param(
    [string]$OutputFile = "techatlas.zip"
)

Write-Host "=== Ana Uygulama Paketleniyor ===" -ForegroundColor Cyan
Write-Host ""

$sourceDir = "build\windows\x64\runner\Release"

if (!(Test-Path $sourceDir)) {
    Write-Host "HATA: Release build bulunamadı!" -ForegroundColor Red
    Write-Host "Önce şunu çalıştırın: flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

# Eski ZIP'i sil
if (Test-Path $OutputFile) {
    Remove-Item $OutputFile -Force
    Write-Host "Eski ZIP dosyası silindi" -ForegroundColor Gray
}

Write-Host "ZIP oluşturuluyor..." -ForegroundColor Green

# Geçici dizin oluştur
$tempDir = "build\temp_package"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Dosyaları kopyala
Write-Host "  Release dosyaları kopyalanıyor..." -ForegroundColor Gray
Copy-Item "$sourceDir\*" -Destination $tempDir -Recurse -Force

# Service account ekle
if (Test-Path "service_account.json") {
    Write-Host "  service_account.json ekleniyor..." -ForegroundColor Gray
    Copy-Item "service_account.json" -Destination $tempDir -Force
}

# Çizim Kalemi launcher ekle
if (Test-Path "Cizim_Kalemi_Baslat.bat") {
    Write-Host "  Çizim Kalemi launcher ekleniyor..." -ForegroundColor Gray
    Copy-Item "Cizim_Kalemi_Baslat.bat" -Destination $tempDir -Force
}

# ZIP oluştur
Write-Host "  Sıkıştırılıyor..." -ForegroundColor Gray
Compress-Archive -Path "$tempDir\*" -DestinationPath $OutputFile -Force

# Temizlik
Remove-Item $tempDir -Recurse -Force

# Boyut bilgisi
$zipSize = (Get-Item $OutputFile).Length / 1MB
Write-Host ""
Write-Host "=== TAMAMLANDI ===" -ForegroundColor Green
Write-Host "ZIP dosyası: $OutputFile" -ForegroundColor Cyan
Write-Host "Boyut: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sonraki adımlar:" -ForegroundColor Yellow
Write-Host "1. Bu ZIP'i GitHub Release olarak yükleyin" -ForegroundColor White
Write-Host "2. Launcher'daki URL'yi güncelleyin" -ForegroundColor White
