<#
    flash.ps1 - program / verify / debug CH32v3xx_Cmake over WCH-Link-E
                using OpenOCD from MounRiver Studio 2.

    Author: mamkincoderr
      https://github.com/mamkincoderr
      https://t.me/mamkincoderr

    Usage:
      .\flash.ps1                      program obj\CH32V303.hex
      .\flash.ps1 probe
      .\flash.ps1 CH32V307             program the V307 image
      .\flash.ps1 CH32V307 probe
      .\flash.ps1 erase | reset | verify | gdb
      .\flash.ps1 program -Raw         dump full OpenOCD log

    Chip selects which hex/elf. Any image may be programmed onto the
    connected probe; silicon vs CHIP is not checked.

    wch_riscv unfreeze: V307 map is 288K; without unfreeze OpenOCD only
    sees the 128K zero-wait bank. Harmless on a 128K V303 Hello World image.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Arg1,

    [Parameter(Position = 1)]
    [string]$Arg2,

    [string]$Image,
    [switch]$Raw
)

$ErrorActionPreference = 'Stop'
$proj = $PSScriptRoot

$modes = @('program', 'probe', 'erase', 'reset', 'verify', 'gdb')
$chips = @('CH32V303', 'CH32V307')
$Mode = 'program'
$Chip = 'CH32V303'

foreach ($a in @($Arg1, $Arg2)) {
    if (-not $a) { continue }
    $hit = $false
    foreach ($m in $modes) {
        if ($a -eq $m) { $Mode = $m; $hit = $true; break }
    }
    if ($hit) { continue }
    foreach ($c in $chips) {
        if ($a -eq $c) { $Chip = $c; $hit = $true; break }
    }
    if (-not $hit) {
        throw "Unknown argument '$a'. Use Mode (program|probe|erase|reset|verify|gdb) and/or Chip (CH32V303|CH32V307)."
    }
}

function Get-ChipDir([string]$chip) {
    if ($chip -eq 'CH32V303') { return (Join-Path $proj 'obj') }
    return (Join-Path $proj "obj\$chip")
}

if (-not $Image) {
    $Image = Join-Path (Get-ChipDir $Chip) "$Chip.hex"
}

function Find-OpenOcdDir {
    $tail2 = 'resources\app\resources\win32\components\WCH\OpenOCD\OpenOCD\bin'
    $cands = @()
    if ($env:WCH_OPENOCD_DIR) { $cands += $env:WCH_OPENOCD_DIR }
    foreach ($d in 'C', 'D', 'E', 'F') {
        $cands += "${d}:\MounRiver\MounRiver_Studio2\$tail2"
        $cands += "${d}:\Program Files\MounRiver\MounRiver_Studio2\$tail2"
        $cands += "${d}:\MounRiver\MounRiver_Studio\toolchain\OpenOCD\bin"
    }
    foreach ($c in $cands) {
        if ((Test-Path (Join-Path $c 'openocd.exe')) -and
            (Test-Path (Join-Path $c 'wch-riscv.cfg'))) { return $c }
    }
    throw "openocd.exe with wch-riscv.cfg not found. Set `$env:WCH_OPENOCD_DIR to its bin folder."
}

$ocdDir = Find-OpenOcdDir
$ocdExe = Join-Path $ocdDir 'openocd.exe'
$ocdCfg = Join-Path $ocdDir 'wch-riscv.cfg'
$imageFwd = $Image -replace '\\', '/'

# Every mode that halt-s MUST end with wlink_reset_resume, except gdb.
$cmds = switch ($Mode) {
    'probe'  { @('init', 'halt', 'flash probe 0', 'wlink_reset_resume') }
    'erase'  { @('init', 'wch_riscv unfreeze', 'halt', 'flash erase_sector 0 0 last', 'wlink_reset_resume') }
    'reset'  { @('init', 'wlink_reset_resume') }
    'verify' { @('init', 'halt', "verify_image $imageFwd", 'wlink_reset_resume') }
    'gdb'    { @('init', 'halt') }
    default  { @('init', 'wch_riscv unfreeze', 'halt', "program $imageFwd verify", 'wlink_reset_resume') }
}

if ($Mode -eq 'program' -or $Mode -eq 'verify') {
    if (-not (Test-Path $Image)) { throw "Image '$Image' missing - run build.bat $Chip first." }
}

function ConvertTo-QuotedArg([string]$a) { if ($a -match '\s') { return '"' + $a + '"' } return $a }

$argv = @('-f', (ConvertTo-QuotedArg $ocdCfg))
foreach ($c in $cmds) { $argv += @('-c', (ConvertTo-QuotedArg $c)) }

if ($Mode -eq 'gdb') {
    $elf = Join-Path (Get-ChipDir $Chip) "$Chip.elf"
    Write-Host "GDB server on localhost:3333"
    Write-Host "  riscv32-wch-elf-gdb `"$elf`" -ex `"target remote :3333`""
    $live = @('-f', $ocdCfg); foreach ($c in $cmds) { $live += @('-c', $c) }
    & $ocdExe @live
    exit $LASTEXITCODE
}

$argv += @('-c', 'exit')

Write-Host "OpenOCD : $ocdExe"
Write-Host "Chip    : $Chip"
if ($Mode -eq 'program' -or $Mode -eq 'verify') { Write-Host "Image   : $Image" }
Write-Host "Mode    : $Mode"

$outFile = [IO.Path]::GetTempFileName()
$errFile = [IO.Path]::GetTempFileName()
try {
    $p = Start-Process -FilePath $ocdExe -ArgumentList $argv -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $log = @(Get-Content $outFile -ErrorAction SilentlyContinue) +
           @(Get-Content $errFile -ErrorAction SilentlyContinue)
}
finally {
    Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
}

if ($Raw) { $log | ForEach-Object { Write-Host $_ } }

$benign = @(
    'Unsupported register \(enum gdb_regno\)',
    'Transport "sdi" was already selected'
)
$errors = $log | Where-Object { $_ -match '^(Error|Warn)\s*:' } |
    Where-Object { $m = $_; -not ($benign | Where-Object { $m -match $_ }) }

if (-not $Raw) {
    $log | Where-Object {
        $_ -match 'device id|flash size|erased sectors|Programming|Verif|wrote|found at|discontinued|WCH-Link'
    } | ForEach-Object { Write-Host "  $_" }
}

foreach ($e in $errors) { Write-Host "  $e" -ForegroundColor Red }

$ok = switch ($Mode) {
    'program' { @($log -match '\*\* Verified OK \*\*').Count -gt 0 }
    'verify'  { @($log -match 'verified|Verified OK').Count -gt 0 }
    'erase'   { @($log -match 'erased sectors').Count -gt 0 }
    'probe'   { @($log -match "flash 'wch_riscv' found at").Count -gt 0 }
    default   { @($log -match 'wlink_init ok').Count -gt 0 }
}

if ($ok -and $errors.Count -eq 0) {
    Write-Host "OK: $Mode succeeded." -ForegroundColor Green
    exit 0
}
Write-Host "FAILED: $Mode (openocd exit $($p.ExitCode))." -ForegroundColor Red
exit 1
