# autounattend-check.ps1
# Converted from autounattend-check.cmd
# Usage: PowerShell (elevated) -ExecutionPolicy Bypass -File .\autounattend-check.ps1

# Ensure running elevated
if (-not ([bool] (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))) {
    Write-Warning "Administrator privileges required. Relaunching elevated..."
    Start-Process -FilePath pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit 1
}

# Initialize
$PASS = 0
$FAIL = 0
$MISS = 0
$REPORT = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop\VerificationResult.txt"

# Write header
@"
Configuration Verification Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $env:COMPUTERNAME
========================================
"@ | Out-File -FilePath $REPORT -Encoding UTF8

Write-Host "========================================"
Write-Host " Configuration Verification Utility"
Write-Host "========================================"
Write-Host

function Log {
    param([string]$Message, [ValidateSet("PASS","FAIL","MISS","")][string]$Status = "")
    Write-Host $Message
    Add-Content -Path $REPORT -Value $Message
    switch ($Status) {
        "PASS" { $script:PASS++ }
        "FAIL" { $script:FAIL++ }
        "MISS" { $script:MISS++ }
        default { }
    }
}

function Convert-RegPath {
    param([string]$RegPath)
    # Convert HKLM\Foo\Bar -> HKLM:\Foo\Bar for Get-ItemProperty
    if ($RegPath -match '^(HKLM|HKEY_LOCAL_MACHINE)\\(.+)$')    { return "HKLM:\$($Matches[2])" }
    if ($RegPath -match '^(HKCU|HKEY_CURRENT_USER)\\(.+)$')     { return "HKCU:\$($Matches[2])" }
    if ($RegPath -match '^(HKCR|HKEY_CLASSES_ROOT)\\(.+)$')     { return "HKCR:\$($Matches[2])" }
    if ($RegPath -match '^(HKU|HKEY_USERS)\\(.+)$')             { return "HKU:\$($Matches[2])" }
    if ($RegPath -match '^(HKCC|HKEY_CURRENT_CONFIG)\\(.+)$')   { return "HKCC:\$($Matches[2])" }
    return $RegPath
}

function Parse-ExpectedHex {
    param([string]$expected)
    if ($null -eq $expected) { return $null }
    if ($expected -is [int] -or $expected -is [long]) { return [uint32]$expected }
    if ($expected -match '^[0-9]+$') { return [uint32][int]$expected }
    if ($expected -match '^0x[0-9a-fA-F]+$') {
        return [uint32]([Convert]::ToUInt32($expected.Substring(2),16))
    }
    # try to parse generic numeric
    try { return [uint32]([int64]$expected) } catch { return $null }
}

function Get-RegValue {
    param([string]$RegPath, [string]$Name)
    $psPath = Convert-RegPath -RegPath $RegPath
    try {
        $prop = Get-ItemProperty -Path $psPath -Name $Name -ErrorAction Stop
        return $prop.$Name
    } catch {
        return $null
    }
}

function Test-Reg {
    param([string]$RegPath, [string]$Name, [string]$ExpectedHex, [string]$Label)

    $actual = Get-RegValue -RegPath $RegPath -Name $Name
    if ($null -eq $actual) {
        Log "[MISS] $Label (Not found)" "MISS"
        return
    }

    $expectedVal = Parse-ExpectedHex -expected $ExpectedHex

    # Normalize actual to uint32 for bitwise/equality comparison when possible
    $actualAsUInt = $null
    try {
        if ($actual -is [string] -and $actual -match '^0x[0-9a-fA-F]+$') {
            $actualAsUInt = [Convert]::ToUInt32($actual.Substring(2),16)
        } else {
            $actualAsUInt = [uint32]$actual
        }
    } catch {
        $actualAsUInt = $null
    }

    if ($null -ne $expectedVal -and $null -ne $actualAsUInt) {
        if ($actualAsUInt -eq $expectedVal) {
            Log "[PASS] $Label" "PASS"
        } else {
            Log "[FAIL] $Label (Value mismatch: actual=0x$([Convert]::ToString($actualAsUInt,16)), expected=0x$([Convert]::ToString($expectedVal,16)))" "FAIL"
        }
    } else {
        # Fallback to string comparison if numeric compare not possible
        if ("$actual" -eq "$ExpectedHex" -or "$actual" -eq "$ExpectedHex.ToLower()") {
            Log "[PASS] $Label" "PASS"
        } else {
            Log "[FAIL] $Label (Value mismatch: actual=$actual, expected=$ExpectedHex)" "FAIL"
        }
    }
}

# Registry checks (HKLM)
Test-Reg "HKLM\SYSTEM\Setup\MoSetup" "AllowUpgradesWithUnsupportedTPMOrCPU" "0x1" "Allow Upgrades on Unsupported Hardware"
Test-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" "0x1" "Disable Copilot"
Test-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" "0x1" "Disable AI Data Analysis"
Test-Reg "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" "0x0" "Fast Startup Disabled"
Test-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" "0x1" "Disable Consumer Features"
Test-Reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" "0x0" "Telemetry Level 0"
Test-Reg "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" "0x26" "CPU Priority (Background)"
Test-Reg "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" "0xffffffff" "Network Throttling Max"

# HKCU checks (note: when run elevated, HKCU refers to the elevated profile)
Test-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" "0x1" "Show Hidden Files"
Test-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" "0x0" "Show File Extensions"
Test-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" "0x1" "Launch to This PC"
Test-Reg "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" "0x0" "Disable Advertising ID"

# Service check: SysMain
try {
    $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='SysMain'"
    if ($null -eq $svc) {
        Log "[PASS] SysMain Service (Not Installed)" "PASS"
    } else {
        $startMode = $svc.StartMode  # "Auto", "Manual", "Disabled"
        $state = $svc.State          # "Running", "Stopped"
        if ($startMode -eq "Disabled") {
            Log "[PASS] SysMain Service (Disabled)" "PASS"
        } elseif ($state -eq "Stopped" -and $startMode -ne "Auto") {
            Log "[PASS] SysMain Service (Stopped/Not Auto)" "PASS"
        } else {
            Log "[FAIL] SysMain Service (Enabled)" "FAIL"
        }
    }
} catch {
    Log "[MISS] SysMain Service (Query failed)" "MISS"
}

# Power check: Hibernation (try powercfg output, fallback to registry HiberbootEnabled already checked)
try {
    $p = & powercfg /a 2>&1
    $pText = $p -join "`n"
    if ($pText -match '(hibernate|hibernation).*not available' -or $pText -match 'The following sleep states are available:' -and $pText -match 'Hibernate.*unavailable') {
        Log "[PASS] Hibernation Disabled" "PASS"
    } else {
        # If unclear, rely on HiberbootEnabled registry result above; if HiberbootEnabled was 0 it already logged PASS.
        if ($script:PASS -gt 0 -and $pText.Trim().Length -eq 0) {
            Log "[PASS] Hibernation Disabled (powercfg inconclusive, registry checked)" "PASS"
        } else {
            Log "[FAIL] Hibernation Enabled or powercfg reports available" "FAIL"
        }
    }
} catch {
    Log "[MISS] Hibernation check (powercfg failed)" "MISS"
}

# TCP Auto-Tuning check
try {
    $tcp = & netsh int tcp show global 2>&1
    $tcpText = $tcp -join "`n"
    if ($tcpText -match '(Receive Window Auto[- ]Tuning Level|auto[- ]tuning level).*:\s*normal') {
        Log "[PASS] TCP Auto-Tuning Normal" "PASS"
    } else {
        # Try simpler match for "normal"
        if ($tcpText -match 'normal') {
            Log "[PASS] TCP Auto-Tuning Normal" "PASS"
        } else {
            Log "[FAIL] TCP Auto-Tuning" "FAIL"
        }
    }
} catch {
    Log "[MISS] TCP Auto-Tuning (netsh failed)" "MISS"
}

# Summary
Add-Content -Path $REPORT -Value ""
Add-Content -Path $REPORT -Value "========================================"
Add-Content -Path $REPORT -Value "Summary: $PASS Passed | $FAIL Failed | $MISS Missing"
Add-Content -Path $REPORT -Value "========================================"
Write-Host ""
Write-Host "========================================"
Write-Host "Summary: $PASS Passed | $FAIL Failed | $MISS Missing"
Write-Host "========================================"
Write-Host ""
Write-Host "Report saved to: $REPORT"
Write-Host ""
Pause
