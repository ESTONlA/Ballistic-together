param([switch]$Install)
$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
$game = (Resolve-Path -LiteralPath (Join-Path $project '..\..')).Path
$source = Join-Path $project 'src'
$installed = Join-Path $game 'Ballistic\Binaries\Win64\ue4ss\Mods\BallisticTogether'
$scripts = Get-ChildItem -LiteralPath (Join-Path $source 'Scripts') -Recurse -File -Filter '*.lua'
if ($scripts.Count -ne 9) { throw "Unexpected source layout: $($scripts.Count) Lua modules" }
if (-not (Test-Path -LiteralPath (Join-Path $source 'Native\BallisticSteamInvites.dll'))) { throw 'Build native/build.ps1 first.' }
[IO.File]::WriteAllText((Join-Path $source 'enabled.txt'), '')
if ($Install) {
    [IO.Directory]::CreateDirectory($installed) | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'Scripts') -Destination $installed -Recurse -Force
    [IO.Directory]::CreateDirectory((Join-Path $installed 'Native')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'Native\BallisticSteamInvites.dll') -Destination (Join-Path $installed 'Native') -Force
    Copy-Item -LiteralPath (Join-Path $source 'enabled.txt') -Destination $installed -Force
}
$dist = Join-Path $project 'dist'
[IO.Directory]::CreateDirectory($dist) | Out-Null
$archive = Join-Path $dist 'BallisticTogether-0.1.2-player-models.zip'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($archive, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite)
$zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File | Where-Object { $_.Extension -eq '.lua' -or $_.Name -eq 'enabled.txt' -or $_.Name -eq 'BallisticSteamInvites.dll' }) {
        $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, "Ballistic/Binaries/Win64/ue4ss/Mods/BallisticTogether/$relative") | Out-Null
    }
    foreach ($name in @('README.md', 'PATCHNOTES.txt', 'LICENSE', 'CONTRIBUTING.md')) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $project $name), $name) | Out-Null
    }
} finally { $zip.Dispose(); $stream.Dispose() }
$check = [IO.Compression.ZipFile]::OpenRead($archive)
try { $check.Entries | Select-Object FullName, Length } finally { $check.Dispose() }
