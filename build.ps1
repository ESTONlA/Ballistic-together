param([switch]$Install)
$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
$game = (Resolve-Path -LiteralPath (Join-Path $project '..\..')).Path
$source = Join-Path $project 'src'
$installed = Join-Path $game 'Ballistic\Binaries\Win64\ue4ss\Mods\BallisticTogether'
$scripts = Get-ChildItem -LiteralPath (Join-Path $source 'Scripts') -Recurse -File -Filter '*.lua'
foreach ($entry in @('main.lua', 'app.lua', 'release.lua', 'config.lua')) {
    if (-not (Test-Path -LiteralPath (Join-Path $source "Scripts\$entry"))) { throw "Missing entry module: $entry" }
}
$version = [regex]::Match([IO.File]::ReadAllText((Join-Path $source 'Scripts\release.lua')), "version = '([^']+)'").Groups[1].Value
if ($version -notmatch '^\d+\.\d+\.\d+(-[a-z0-9.-]+)?$') { throw 'Invalid release.lua version' }
if (-not (Test-Path -LiteralPath (Join-Path $source 'Native\BallisticSteamInvites.dll'))) { throw 'Build native/build.ps1 first.' }
[IO.File]::WriteAllText((Join-Path $source 'enabled.txt'), '')
if ($Install) {
    [IO.Directory]::CreateDirectory($installed) | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'Scripts') -Destination $installed -Recurse -Force
    [IO.Directory]::CreateDirectory((Join-Path $installed 'Native')) | Out-Null
    $nativeSource = Join-Path $source 'Native\BallisticSteamInvites.dll'
    $nativeInstalled = Join-Path $installed 'Native\BallisticSteamInvites.dll'
    if (-not (Test-Path -LiteralPath $nativeInstalled) -or (Get-FileHash -LiteralPath $nativeSource).Hash -ne (Get-FileHash -LiteralPath $nativeInstalled).Hash) {
        Copy-Item -LiteralPath $nativeSource -Destination $nativeInstalled -Force
    }
    Copy-Item -LiteralPath (Join-Path $source 'enabled.txt') -Destination $installed -Force
}
$dist = Join-Path $project 'dist'
[IO.Directory]::CreateDirectory($dist) | Out-Null
$archive = Join-Path $dist "BallisticTogether-$version.zip"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($archive, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite)
$zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File | Where-Object { $_.Extension -eq '.lua' -or $_.Name -eq 'enabled.txt' -or $_.Name -eq 'BallisticSteamInvites.dll' }) {
        $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, "Ballistic/Binaries/Win64/ue4ss/Mods/BallisticTogether/$relative") | Out-Null
    }
    foreach ($name in @('README.md', 'PATCHNOTES.txt', 'CODEBASE.md', 'LICENSE', 'CONTRIBUTING.md')) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $project $name), $name) | Out-Null
    }
} finally { $zip.Dispose(); $stream.Dispose() }
$check = [IO.Compression.ZipFile]::OpenRead($archive)
try { $check.Entries | Select-Object FullName, Length } finally { $check.Dispose() }
