<#
    flash.ps1 - program / verify / debug CH32v3xx_Cmake over WCH-Link-E
                using OpenOCD from MounRiver Studio 2.

    Author: mamkincoderr
      https://github.com/mamkincoderr
      https://t.me/oDeXteRo

    Usage:
      .\flash.ps1                      program obj\CH32v3xx_Cmake.hex
      .\flash.ps1 probe                device id, flash size, ROM/RAM, read-protect state
      .\flash.ps1 erase | reset | verify | gdb
      .\flash.ps1 program -Raw         dump full OpenOCD log
      .\flash.ps1 unlock -Confirm      disable read-protect - MASS ERASES flash, all firmware lost
      .\flash.ps1 lock -Confirm        enable read-protect - blocks further program/debug until unlocked

    Chip is whatever User/chip_select.h says the last build.bat run used
    (see obj/built_as.txt). Any image may be programmed onto the connected
    probe; silicon vs chip_select.h is not checked.

    lock/unlock use the wch_riscv driver's generic 'flash protect' hook and
    refuse to run without -Confirm: unlock forces a mass erase (irreversible,
    all firmware lost), lock can leave the chip unprogrammable/undebuggable
    until unlocked (which then erases it).

    wch_riscv unfreeze: without it OpenOCD only sees the 128K R0WAIT bank.
    Needed when the image has SLOWFLASH (.rodata at 0x20000 on V303, or past
    the CODE window on V307).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Arg1,

    [string]$Image,
    [switch]$Raw,
    [switch]$Confirm
)

$ErrorActionPreference = 'Stop'
$proj = $PSScriptRoot

$modes = @('program', 'probe', 'erase', 'reset', 'verify', 'gdb', 'lock', 'unlock')
$destructiveModes = @('lock', 'unlock')
$Mode = 'program'

if ($Arg1) {
    if ($modes -notcontains $Arg1) {
        throw "Unknown argument '$Arg1'. Use program|probe|erase|reset|verify|gdb|lock|unlock."
    }
    $Mode = $Arg1
}

if ($destructiveModes -contains $Mode -and -not $Confirm) {
    throw "Mode '$Mode' is destructive and needs -Confirm. unlock forces a mass erase (all firmware lost); lock can block further programming/debug until unlocked (which then erases). Re-run as: .\flash.ps1 $Mode -Confirm"
}

$chipDir = Join-Path $proj 'obj'

if (-not $Image) {
    $Image = Join-Path $chipDir 'CH32v3xx_Cmake.hex'
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
    'lock'   { @('init', 'halt', 'flash protect 0 0 last on', 'wlink_reset_resume') }
    'unlock' { @('init', 'halt', 'flash protect 0 0 last off', 'wlink_reset_resume') }
    default  { @('init', 'wch_riscv unfreeze', 'halt', "program $imageFwd verify", 'wlink_reset_resume') }
}

if ($Mode -eq 'program' -or $Mode -eq 'verify') {
    if (-not (Test-Path $Image)) { throw "Image '$Image' missing - run build.bat first." }
}

function ConvertTo-QuotedArg([string]$a) { if ($a -match '\s') { return '"' + $a + '"' } return $a }

$argv = @('-f', (ConvertTo-QuotedArg $ocdCfg))
foreach ($c in $cmds) { $argv += @('-c', (ConvertTo-QuotedArg $c)) }

if ($Mode -eq 'gdb') {
    $elf = Join-Path $chipDir 'CH32v3xx_Cmake.elf'
    Write-Host "GDB server on localhost:3333"
    Write-Host "  riscv32-wch-elf-gdb `"$elf`" -ex `"target remote :3333`""
    $live = @('-f', $ocdCfg); foreach ($c in $cmds) { $live += @('-c', $c) }
    & $ocdExe @live
    exit $LASTEXITCODE
}

$argv += @('-c', 'exit')

Write-Host "OpenOCD : $ocdExe"
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
        $_ -match 'device id|flash size|ROM \d+ kbytes|erased sectors|Programming|Verif|wrote|found at|discontinued|WCH-Link|Read-Protect'
    } | ForEach-Object { Write-Host "  $_" }
}

foreach ($e in $errors) { Write-Host "  $e" -ForegroundColor Red }

$ok = switch ($Mode) {
    'program' { @($log -match '\*\* Verified OK \*\*').Count -gt 0 }
    'verify'  { @($log -match 'verified|Verified OK').Count -gt 0 }
    'erase'   { @($log -match 'erased sectors').Count -gt 0 }
    'probe'   { @($log -match "flash 'wch_riscv' found at").Count -gt 0 }
    'lock'    { @($log -match 'Success to Enable Read-Protect|Read-Protect Status Currently Enabled').Count -gt 0 }
    'unlock'  { @($log -match 'Success to Disable Read-Protect').Count -gt 0 }
    default   { @($log -match 'wlink_init ok').Count -gt 0 }
}

if ($ok -and $errors.Count -eq 0) {
    Write-Host "OK: $Mode succeeded." -ForegroundColor Green
    exit 0
}
Write-Host "FAILED: $Mode (openocd exit $($p.ExitCode))." -ForegroundColor Red
exit 1
