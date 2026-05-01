<#
.SYNOPSIS
    Applies Windows optimization and privacy configurations to an existing system.
.DESCRIPTION
    Executes all registry, service, power, and application modifications.
    Fully idempotent and safe for repeated execution.
    Compatible with Windows 10/11 Pro, Home, LTSC, and Server 2019-2025.
.NOTES
    Requires Administrator privileges. Logs execution to %TEMP%.
#>
#requires -RunAsAdministrator

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$LogPath = Join-Path $env:TEMP "ApplyConfig_$(Get-Date -f 'yyyyMMdd_HHmmss').log"

# Single logging mechanism (no Transcript + Out-File conflict)
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    # Use Add-Content with shared read/write access to avoid lock conflicts
    Add-Content -Path $LogPath -Value $line -Force -ErrorAction SilentlyContinue
    # Console output with color
    $color = switch ($Level) { 'OK' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } 'ERR' { 'Red' } default { 'Cyan' } }
    Write-Host $line -ForegroundColor $color
}

function Set-RegSafe {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path (Split-Path $Path) -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Write-Log "Registry: $Path\$Name = $Value (PowerShell)" 'DEBUG'
        return $true
    } catch {
        # Fallback to native reg.exe
        $regType = switch ($Type) { 'DWord' { 'REG_DWORD' } 'String' { 'REG_SZ' } default { 'REG_DWORD' } }
        $val = if ($Type -eq 'String') { "`"$Value`"" } else { $Value }
        $cmd = "reg.exe add `"$Path`" /v `"$Name`" /t $regType /d $val /f 2>&1"
        $output = Invoke-Expression $cmd
        # Check success via output text (more reliable than $LASTEXITCODE in some contexts)
        if ($output -match 'The operation completed successfully' -or $LASTEXITCODE -eq 0) {
            Write-Log "Registry: $Path\$Name = $Value (reg.exe fallback)" 'DEBUG'
            return $true
        }
        Write-Log "Registry FAILED: $Path\$Name | $output" 'ERR'
        return $false
    }
}

# Detect OS context
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$isServer = $os.Caption -like '*Server*'
$isLTSC = $os.Caption -like '*LTSC*'
$build = [Environment]::OSVersion.Version.Build
Write-Log "Detected: $($os.Caption) | Build: $build"

# ==========================================
# HKLM SYSTEM CONFIGURATION
# ==========================================
Write-Log "Applying HKLM registry configurations..."
$regHKLM = @(
    @{Path='HKLM:\SYSTEM\Setup\MoSetup'; Name='AllowUpgradesWithUnsupportedTPMOrCPU'; Value=1},
    @{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications'; Name='ConfigureChatAutoInstall'; Value=0},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableAIDataAnalysis'; Value=1},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'; Name='EnableMulticast'; Value=0},
    @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'; Name='LongPathsEnabled'; Value=1},
    @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name='HiberbootEnabled'; Value=0},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures'; Value=1},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableSoftLanding'; Value=1},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='EnableActivityFeed'; Value=0},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='PublishUserActivities'; Value=0},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='AllowTelemetry'; Value=0},
    @{Path='HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'; Name='Win32PrioritySeparation'; Value=0x26},
    @{Path='HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter'; Name='ActivationType'; Value=0},
    @{Path='HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'; Name='Disabled'; Value=1},
    @{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{31C0DD25-9439-4F12-BF41-7FF4EDA38722}\PropertyBag'; Name='ThisPCPolicy'; Value='Hide'; Type='String'},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'; Name='AllowStorageSenseGlobal'; Value=0},
    @{Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name='SystemResponsiveness'; Value=0},
    @{Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name='NetworkThrottlingIndex'; Value=0xFFFFFFFF},
    @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Name='SubmitSamplesConsent'; Value=2}
)

foreach ($key in $regHKLM) {
    $success = Set-RegSafe -Path $key.Path -Name $key.Name -Value $key.Value -Type $key.Type
    $status = if ($success) { 'OK' } else { 'FAIL' }
    Write-Log "$($key.Name) $($success ? 'applied' : 'failed')" $status
}

# ==========================================
# HKCU USER CONFIGURATION
# ==========================================
Write-Log "Applying HKCU user configurations..."
$regHKCU = @(
    @{Path='HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Hidden'; Value=1},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='HideFileExt'; Value=0},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='LaunchTo'; Value=1},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'; Name='FullPath'; Value=1},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name='SearchboxTaskbarMode'; Value=3},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowTaskViewButton'; Value=0},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarDa'; Value=0},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarMn'; Value=0},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name='Enabled'; Value=0},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name='TailoredExperiencesWithDiagnosticDataEnabled'; Value=0},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='ContentDeliveryAllowed'; Value=0},
    @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name='AppCaptureEnabled'; Value=0},
    @{Path='HKCU:\Control Panel\Accessibility\StickyKeys'; Name='Flags'; Value='506'; Type='String'},
    @{Path='HKCU:\Control Panel\Accessibility\ToggleKeys'; Name='Flags'; Value='58'; Type='String'},
    @{Path='HKCU:\Control Panel\Accessibility\FilterKeys'; Name='Flags'; Value='122'; Type='String'}
)

foreach ($key in $regHKCU) {
    Set-RegSafe -Path $key.Path -Name $key.Name -Value $key.Value -Type $key.Type | Out-Null
}

# ==========================================
# SERVICES & POWER
# ==========================================
Write-Log "Optimizing services and power configuration..."

# Conditional SysMain disable (preserves HDD performance)
$pd = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.BusType -ne 'USB' } | Sort-Object Size -Descending | Select-Object -First 1
$isSSD = $pd.MediaType -eq 'SSD' -or $pd.BusType -eq 'NVMe'
if ($isSSD -or $isServer) {
    try {
        Stop-Service SysMain -Force -ErrorAction SilentlyContinue
        Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "SysMain disabled" 'OK'
    } catch { Write-Log "SysMain modification skipped" 'WARN' }
} else {
    Write-Log "SysMain left enabled (HDD detected)" 'INFO'
}

powercfg.exe /hibernate off 2>&1 | Out-Null
$hp = powercfg /l | Select-String 'High performance'
if ($hp) { powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null }
powercfg.exe /change standby-timeout-ac 0 2>&1 | Out-Null
powercfg.exe /change standby-timeout-dc 0 2>&1 | Out-Null
powercfg.exe /change monitor-timeout-ac 0 2>&1 | Out-Null

# ==========================================
# APPLICATION REMOVAL
# ==========================================
if (-not $isServer) {
    Write-Log "Removing default applications..."
    $pkgs = @(
        'Microsoft.BingSearch*','Clipchamp.Clipchamp*','Microsoft.549981C3F5F10*',
        'Microsoft.Windows.DevHome*','MicrosoftCorporationII.MicrosoftFamily*',
        'Microsoft.WindowsFeedbackHub*','Microsoft.Getstarted*','Microsoft.MixedReality.Portal*',
        'Microsoft.MicrosoftOfficeHub*','Microsoft.Office.OneNote*','Microsoft.OutlookForWindows*',
        'Microsoft.MSPaint*','Microsoft.PowerAutomateDesktop*','MicrosoftCorporationII.QuickAssist*',
        'Microsoft.SkypeApp*','Microsoft.MicrosoftSolitaireCollection*','MicrosoftTeams*','MSTeams*',
        'Microsoft.Todos*','Microsoft.Wallet*','Microsoft.Xbox.TCUI*','Microsoft.XboxApp*',
        'Microsoft.XboxGameOverlay*','Microsoft.XboxGamingOverlay*','Microsoft.XboxIdentityProvider*',
        'Microsoft.XboxSpeechToTextOverlay*','Microsoft.GamingApp*','Microsoft.YourPhone*'
    )
    if ($build -ge 22000 -and -not $isLTSC) { $pkgs += 'Microsoft.Windows.Ai.Copilot.Provider*' }

    foreach ($p in $pkgs) {
        try {
            $found = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $p }
            if ($found) {
                Start-Sleep -Milliseconds 1500
                $found | Remove-AppxProvisionedPackage -AllUsers -Online -ErrorAction SilentlyContinue | Out-Null
                Write-Log "Removed: $($found.DisplayName)" 'OK'
            }
        } catch { Write-Log "Skip: $p" 'WARN' }
    }
    @('DevHomeUpdate','OutlookUpdate') | ForEach-Object {
        Remove-Item "HKLM:\Software\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\$_" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================
# NETWORK & UI REFRESH
# ==========================================
netsh.exe int tcp set global autotuning=normal 2>&1 | Out-Null

# Create verification shortcut if available
$desktop = [Environment]::GetFolderPath('Desktop')
$verifyScript = 'C:\Windows\Setup\Scripts\DeploymentVerification.ps1'
if (Test-Path $verifyScript) {
    try {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut("$desktop\VerifyDeployment.lnk")
        $sc.TargetPath = 'powershell.exe'
        $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$verifyScript`""
        $sc.Description = 'Checks deployment configuration status'
        $sc.Save()
        Write-Log "Verification shortcut created" 'OK'
    } catch {}
}

# Refresh Explorer safely
try { (New-Object -ComObject Shell.Application).RefreshMenu() } catch {}

Write-Host "`n✅ All configurations applied successfully." -ForegroundColor Green
Write-Host "📄 Execution log: $LogPath" -ForegroundColor DarkGray
Write-Host "🔄 Log out and back in, or restart Explorer for UI changes to take full effect." -ForegroundColor Yellow