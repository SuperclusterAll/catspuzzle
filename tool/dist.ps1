# 배포용 산출물을 dist/ 에 만든다: release APK + 소스 zip.
#
#   powershell -ExecutionPolicy Bypass -File tool/dist.ps1
#
# 파일 이름에 시각을 붙이고, 종류별로 최근 $Keep 개만 남긴다.
# release APK는 아직 debug 키로 서명된다 (스토어 출시용 서명은 별도 설정 필요).
param([int]$Keep = 5)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { $env:Path += ';C:\src\flutter\bin' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

# 1) release APK
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build apk 실패' }
$apk = Join-Path $dist "catspuzzle-$stamp.apk"
Copy-Item 'build\app\outputs\flutter-apk\app-release.apk' $apk -Force

# 2) 소스 zip: git이 추적하거나 .gitignore에 걸리지 않는 파일만 (빌드 산출물 제외).
#    에이전트/도구 설정 폴더는 제외한다.
$exclude = '^(\.claude|\.gjc|\.agents|dist)/|^skills-lock\.json$'
$files = git ls-files --cached --others --exclude-standard | Where-Object { $_ -notmatch $exclude }
$zip = Join-Path $dist "catspuzzle-src-$stamp.zip"
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    foreach ($f in $files) {
        if (Test-Path $f -PathType Leaf) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, (Join-Path $root $f), "catspuzzle/$f", 'Optimal') | Out-Null
        }
    }
} finally { $archive.Dispose() }

# 3) 오래된 것 정리
foreach ($pattern in 'catspuzzle-2*.apk', 'catspuzzle-src-*.zip') {
    Get-ChildItem $dist -Filter $pattern | Sort-Object Name -Descending |
        Select-Object -Skip $Keep | Remove-Item
}

'{0}  {1:N1} MB' -f (Split-Path -Leaf $apk), ((Get-Item $apk).Length / 1MB)
'{0}  {1:N1} MB ({2} files)' -f (Split-Path -Leaf $zip), ((Get-Item $zip).Length / 1MB), $files.Count
