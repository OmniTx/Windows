@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: Verify Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administrator privileges required.
    echo Right-click this file and select "Run as administrator".
    pause
    exit /b 1
)

:: Initialize counters and report file
set "PASS=0"
set "FAIL=0"
set "MISS=0"
set "REPORT=%USERPROFILE%\Desktop\VerificationResult.txt"

(
echo Configuration Verification Report
echo Generated: %date% %time%
echo Computer: %COMPUTERNAME%
echo ========================================
) > "%REPORT%"

:: Header
echo ========================================
echo  Configuration Verification Utility
echo ========================================
echo.

:: Helper: Log to console and report, update counters
:log
echo %~1
echo %~1 >> "%REPORT%"
if "%~2"=="PASS" set /a PASS+=1
if "%~2"=="FAIL" set /a FAIL+=1
if "%~2"=="MISS" set /a MISS+=1
goto :eof

:: Helper: Registry value check
:reg_check
reg query "%~1" /v "%~2" 2>nul | findstr /i "%~3" >nul
if %errorlevel%==0 (
    call :log "[PASS] %~4" "PASS"
) else (
    reg query "%~1" /v "%~2" 2>nul >nul
    if %errorlevel%==0 (
        call :log "[FAIL] %~4 (Value mismatch)" "FAIL"
    ) else (
        call :log "[MISS] %~4 (Not found)" "MISS"
    )
)
goto :eof

:: HKLM System Checks
call :reg_check "HKLM\SYSTEM\Setup\MoSetup" "AllowUpgradesWithUnsupportedTPMOrCPU" "0x1" "Allow Upgrades on Unsupported Hardware"
call :reg_check "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" "0x1" "Disable Copilot"
call :reg_check "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" "0x1" "Disable AI Data Analysis"
call :reg_check "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" "0x0" "Fast Startup Disabled"
call :reg_check "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" "0x1" "Disable Consumer Features"
call :reg_check "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" "0x0" "Telemetry Level 0"
call :reg_check "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" "0x26" "CPU Priority (Background)"
call :reg_check "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" "0xffffffff" "Network Throttling Max"

:: HKCU User Checks (Reflects current elevated profile)
call :reg_check "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" "0x1" "Show Hidden Files"
call :reg_check "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" "0x0" "Show File Extensions"
call :reg_check "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" "0x1" "Launch to This PC"
call :reg_check "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" "0x0" "Disable Advertising ID"

:: Service Checks
sc qc SysMain 2>nul | find "DISABLED" >nul
if %errorlevel%==0 (
    call :log "[PASS] SysMain Service (Disabled)" "PASS"
) else (
    sc qc SysMain 2>nul | find "AUTO_START" >nul && (
        call :log "[FAIL] SysMain Service (Enabled)" "FAIL"
    ) || (
        call :log "[PASS] SysMain Service (Not Installed)" "PASS"
    )
)

:: Power & Network Checks
powercfg /a 2>nul | findstr /i "hibernate.*disabled" >nul
if %errorlevel%==0 (
    call :log "[PASS] Hibernation Disabled" "PASS"
) else (
    call :log "[FAIL] Hibernation Enabled" "FAIL"
)

netsh int tcp show global 2>nul | findstr /i "normal" >nul
if %errorlevel%==0 (
    call :log "[PASS] TCP Auto-Tuning Normal" "PASS"
) else (
    call :log "[FAIL] TCP Auto-Tuning" "FAIL"
)

:: Summary
echo.
echo ========================================
echo Summary: %PASS% Passed | %FAIL% Failed | %MISS% Missing
echo ========================================
echo.
echo Report saved to: %REPORT%
echo.
pause
goto :eof
