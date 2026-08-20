# ═══════════════════════════════════════════════════════════════
# Update PlantUML JS engine (TeaVM) ke versi terbaru.
#
# Engine PlantUML versi JavaScript di-publish ke npm sebagai
# package `@plantuml/core` (lisensi MIT). Script ini mengambil
# `plantuml.js` dan `viz-global.js` versi terbaru dari unpkg dan
# menimpanya ke `assets/plantuml/`.
#
# Cara pakai (dari root project):
#   powershell -ExecutionPolicy Bypass -File tools/update_plantuml.ps1
#
# Setelah update, jalankan `flutter pub get` lalu build ulang APK.
# ═══════════════════════════════════════════════════════════════
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$dest = Join-Path $PSScriptRoot '..\assets\plantuml'
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$files = @('plantuml.js', 'viz-global.js')

foreach ($f in $files) {
    $url = "https://unpkg.com/@plantuml/core@latest/$f"
    $out = Join-Path $dest $f
    Write-Host "Downloading $f ..."
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    $size = (Get-Item $out).Length
    Write-Host "  -> $out ($([math]::Round($size / 1MB, 2)) MB)"
}

Write-Host ''
Write-Host 'Selesai. Versi engine yang terpasang:'
try {
    $latest = Invoke-RestMethod -Uri 'https://registry.npmjs.org/@plantuml/core/latest' -UseBasicParsing
    Write-Host "  @plantuml/core $($latest.version)"
} catch {
    Write-Host '  (gagal membaca versi dari npm registry)'
}
