param([switch]$Test)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot
$output = Join-Path $project 'src\Native'
$artifacts = Join-Path $project 'dev\native-build'
[IO.Directory]::CreateDirectory($output) | Out-Null
[IO.Directory]::CreateDirectory($artifacts) | Out-Null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'MSVC x64 build tools are required.' }
$vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$source = Join-Path $PSScriptRoot 'invites.cpp'
$dll = Join-Path $output 'BallisticSteamInvites.dll'
$batch = Join-Path $artifacts 'compile.cmd'
$lines = @('@echo off', "call `"$vcvars`" >nul", "cd /d `"$artifacts`"", "cl /nologo /std:c++17 /EHsc /W4 /WX /MT /LD `"$source`" /link /OUT:`"$dll`"", 'if errorlevel 1 exit /b 1')
if ($Test) {
    $lines += @("cl /nologo /std:c++17 /EHsc /W4 /WX /MT /DBT_SELF_TEST `"$source`" /Fe:invite-tests.exe", 'if errorlevel 1 exit /b 1', 'invite-tests.exe', 'if errorlevel 1 exit /b 1')
}
[IO.File]::WriteAllLines($batch, $lines, [Text.Encoding]::ASCII)
& $env:ComSpec /d /c $batch
if ($LASTEXITCODE -ne 0) { throw "Native bridge build/test failed ($LASTEXITCODE)." }
