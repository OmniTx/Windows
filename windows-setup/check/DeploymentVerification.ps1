<#
.SYNOPSIS
    Verifies applied Windows configuration settings against deployment standards.
.DESCRIPTION
    Checks registry keys, service states, power configurations, and network settings
    to confirm system hardening and privacy modifications are active.
    Outputs results to console and saves a detailed report to the user's Desktop.
.NOTES
    Requires Administrator privileges for accurate HKLM registry verification.
    Compatible with Windows 10/11 Pro, Home, LTSC, and Server 2019-2025.
#>
#requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Detect OS context for edition-aware checks
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$isServer = $os.Caption -like '*Server*'
$isLTSC = $os.Caption -like '*LTSC*'
$build = [Environment]::OSVersion.Version.Build

# Report output path
$reportPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'VerificationResult.txt'

# Initialize counters
$passCount = 0
$failCount = 0
$missingCount = 0

# Helper: Write to console with color and accumulate report lines
function Write-Result {
    param([string]$Category, [string]$Check, [string]$Status, [string]$Details = '')
    $line = "[$Category] $Check : $Status"
    if ($Details) { $line += " ($Details)" }
    
    # Console output with color coding
    $color = switch ($Status) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'MISS' { 'Yellow' }
        default { 'Cyan' }
    }
    Write-Host $line -ForegroundColor $color
    
    # Accumulate for report file
    $script:reportLines += $line
    if ($Details) { $script:reportLines += "  └─ $Details" }
    
    # Update counters
    switch ($Status) {
        'PASS' { $script:passCount++ }
        'FAIL' { $script:failCount++ }
        'MISS' { $script:missingCount++ }
    }
}

# Helper: Registry value verification
function Test-RegistryValue {
    param([string]$Path, [string]$Name, $ExpectedValue)
    try {
        if (Test-Path -LiteralPath $Path) {
            $actual = (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name
            if ($actual -eq $ExpectedValue) {
                return @{ Status = 'PASS'; Actual = $actual }
            } else {
                return @{ Status = 'FAIL'; Actual = $actual; Expected = $ExpectedValue }
            }
        }
        return @{ Status = 'MISS'; Actual = 'Key not found' }
    } catch {
        return @{ Status = 'MISS'; Actual = "Error: $($_.Exception.Message)" }
    }
}

# Initialize report buffer
$reportLines = @()
$reportLines += "Configuration Verification Report"
$reportLines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$reportLines += "Computer: $env:COMPUTERNAME"
$reportLines += "OS: $($os.Caption) | Build: $build"
$reportLines += "User: $env:USERNAME"
$reportLines += "========================================"
$reportLines += ''

# Header
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Configuration Verification Utility" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ==========================================
# HKLM SYSTEM CHECKS
# ==========================================
Write-Host "Checking system-wide configurations..." -ForegroundColor DarkGray

$r = Test-RegistryValue 'HKLM:\SYSTEM\Setup\MoSetup' 'AllowUpgradesWithUnsupportedTPMOrCPU' 1
Write-Result 'HKLM' 'Allow Upgrades on Unsupported Hardware' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Write-Result 'HKLM' 'Disable Copilot' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
Write-Result 'HKLM' 'Disable AI Data Analysis' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
Write-Result 'HKLM' 'Win32 Long Paths Enabled' $r.Status

$r = Test-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
Write-Result 'HKLM' 'Fast Startup Disabled' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
Write-Result 'HKLM' 'Disable Consumer Features' $r.Status

$r = Test-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
Write-Result 'HKLM' 'Telemetry Level (Security/0)' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 0x26
$actualHex = if ($r.Actual) { "0x$('{0:X}' -f $r.Actual)" } else { $r.Actual }
Write-Result 'HKLM' 'CPU Priority (Background Services)' $r.Status $(if($r.Status -eq 'FAIL'){ "Expected: 0x26, Actual: $actualHex" })

$r = Test-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{31C0DD25-9439-4F12-BF41-7FF4EDA38722}\PropertyBag' 'ThisPCPolicy' 'Hide'
Write-Result 'HKLM' 'Hide 3D Objects from This PC' $r.Status

$r = Test-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 0
Write-Result 'HKLM' 'Power Throttling Disabled' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xFFFFFFFF
$actualHex = if ($r.Actual) { "0x$('{0:X}' -f $r.Actual)" } else { $r.Actual }
Write-Result 'HKLM' 'Max Network Throttling' $r.Status $(if($r.Status -eq 'FAIL'){ "Expected: 0xFFFFFFFF, Actual: $actualHex" })

$r = Test-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' 'SubmitSamplesConsent' 2
Write-Result 'HKLM' 'Defender Sample Submission Disabled' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

# ==========================================
# HKCU USER CHECKS
# ==========================================
Write-Host "`nChecking user-specific configurations..." -ForegroundColor DarkGray

$r = Test-RegistryValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Write-Result 'HKCU' 'Disable Copilot (Current User)' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 1
Write-Result 'HKCU' 'Show Hidden Files' $r.Status

$r = Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0
Write-Result 'HKCU' 'Show File Extensions' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'LaunchTo' 1
Write-Result 'HKCU' 'Explorer: Launch to This PC' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' 'FullPath' 1
Write-Result 'HKCU' 'Show Full Path in Title Bar' $r.Status

$r = Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
Write-Result 'HKCU' 'Disable Advertising ID' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

$r = Test-RegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Write-Result 'HKCU' 'Disable Tailored Experiences' $r.Status $(if($r.Actual -ne $r.Expected){ "Expected: $($r.Expected), Actual: $($r.Actual)" })

# ==========================================
# SERVICE & POWER CHECKS
# ==========================================
Write-Host "`nChecking services and power configuration..." -ForegroundColor DarkGray

# SysMain service state
try {
    $svc = Get-Service -Name 'SysMain' -ErrorAction Stop
    # Check startup type, not current state (service may be stopped but set to Auto)
    if ($svc.StartType -eq 'Disabled') {
        Write-Result 'Service' 'SysMain (Superfetch) Disabled' 'PASS'
    } else {
        Write-Result 'Service' 'SysMain (Superfetch) Disabled' 'FAIL' "StartupType: $($svc.StartType)"
    }
} catch {
    # Service may not exist on some editions (e.g., Server Core)
    Write-Result 'Service' 'SysMain (Superfetch) Disabled' 'MISS' 'Service not found'
}

# Hibernation state
try {
    $hibernateOutput = powercfg /a 2>&1
    if ($hibernateOutput -match 'hibernate.*disabled' -or $hibernateOutput -match 'not available') {
        Write-Result 'Power' 'Hibernation Disabled' 'PASS'
    } else {
        Write-Result 'Power' 'Hibernation Disabled' 'FAIL' 'Hibernation is available/enabled'
    }
} catch {
    Write-Result 'Power' 'Hibernation Disabled' 'MISS' 'Unable to query powercfg'
}

# ==========================================
# NETWORK CHECKS
# ==========================================
Write-Host "`nChecking network configuration..." -ForegroundColor DarkGray

try {
    $tcpOutput = netsh int tcp show global 2>&1
    if ($tcpOutput -match 'Receive Window Auto-Tuning Level.*normal') {
        Write-Result 'Network' 'TCP Auto-Tuning: Normal' 'PASS'
    } else {
        Write-Result 'Network' 'TCP Auto-Tuning: Normal' 'FAIL' 'Auto-tuning not set to normal'
    }
} catch {
    Write-Result 'Network' 'TCP Auto-Tuning: Normal' 'MISS' 'Unable to query netsh'
}

# ==========================================
# EDITION-SPECIFIC CHECKS
# ==========================================
if (-not $isServer) {
    Write-Host "`nChecking application removal (non-Server editions)..." -ForegroundColor DarkGray
    
    # Check for common bloatware packages (provisioned state)
    $bloatPkgs = @('Microsoft.BingSearch', 'Clipchamp.Clipchamp', 'MicrosoftTeams', 'Microsoft.XboxApp')
    foreach ($pkg in $bloatPkgs) {
        try {
            $found = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$pkg*" }
            if ($found) {
                Write-Result 'Packages' "Provisioned: $pkg" 'FAIL' 'Still present in image'
            } else {
                Write-Result 'Packages' "Provisioned: $pkg" 'PASS'
            }
        } catch {
            Write-Result 'Packages' "Provisioned: $pkg" 'MISS' 'Unable to query Appx packages'
        }
    }
} else {
    Write-Result 'Packages' 'Application Removal Checks' 'SKIP' 'Windows Server edition'
}

# ==========================================
# FINALIZE REPORT
# ==========================================
$reportLines += ''
$reportLines += '========================================'
$reportLines += "SUMMARY"
$reportLines += '========================================'
$reportLines += "Total Checks : $($passCount + $failCount + $missingCount)"
$reportLines += "✅ Passed    : $passCount"
$reportLines += "❌ Failed    : $failCount"
$reportLines += "⚠️  Missing   : $missingCount"
$reportLines += '========================================'
$reportLines += ''
$reportLines += 'Note: HKCU checks reflect the current user profile.'
$reportLines += 'Per-user settings apply on first standard-user logon.'
$reportLines += 'Run this script again after logging in as a standard user for complete verification.'

# Write report file
$reportLines | Out-File -FilePath $reportPath -Encoding utf8 -Force

# Console summary
Write-Host "`n========================================" -ForegroundColor $(if($failCount -eq 0){'Green'}else{'Red'})
Write-Host "  Verification Complete" -ForegroundColor $(if($failCount -eq 0){'Green'}else{'Red'})
Write-Host "========================================" -ForegroundColor $(if($failCount -eq 0){'Green'}else{'Red'})
Write-Host "✅ Passed  : $passCount" -ForegroundColor Green
Write-Host "❌ Failed  : $failCount" -ForegroundColor Red
Write-Host "⚠️  Missing : $missingCount" -ForegroundColor Yellow
Write-Host "`n📄 Full report saved to:`n   $reportPath" -ForegroundColor DarkGray

# Show message box for user visibility (optional, non-blocking)
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $msg = "Verification Complete`n`nPassed: $passCount`nFailed: $failCount`nMissing: $missingCount`n`nFull report saved to Desktop\VerificationResult.txt"
    [System.Windows.Forms.MessageBox]::Show($msg, 'Configuration Check', 'OK', 'Information') | Out-Null
} catch {
    # MessageBox not available (e.g., non-interactive session); skip silently
}

# Exit code for scripting/automation
if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}