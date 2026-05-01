# Windows Deployment Configuration Suite

A collection of scripts and configuration files for applying privacy-focused, performance-optimized settings to Windows 10/11 installations. Compatible with Pro, Home, LTSC, and Server 2019-2025 editions.

---

## 📦 Contents

| File | Purpose | When to Use |
|------|---------|-------------|
| `autounattend.xml` | Unattended deployment configuration | Fresh Windows installation via USB/ISO |
| `ApplyConfigurations.ps1` | Post-install configuration script | Existing Windows installation |
| `DeploymentVerification.ps1` | PowerShell verification utility | Check applied settings (Admin required) |
| `VerifyDeployment.cmd` | CMD verification utility | Quick check without PowerShell execution policy concerns |

---

## ⚙️ System Requirements

- **Operating System**: Windows 10/11 Pro, Home, Enterprise, LTSC, or Server 2019-2025
- **Architecture**: x64 (AMD64)
- **Privileges**: Administrator rights required for all scripts
- **PowerShell**: Version 5.1 or later (included with Windows 10/11)
- **Disk Space**: ~50 MB temporary space for logs and extraction

---

## 🚀 Quick Start

### Option A: Fresh Installation (Recommended)

1. Copy `autounattend.xml` to the **root** of your Windows installation USB or ISO
2. Boot target machine from installation media
3. Windows Setup will automatically detect and apply all configurations
4. After first login, verify settings using `DeploymentVerification.ps1` on the desktop

### Option B: Existing Installation

1. Open PowerShell as Administrator
2. Navigate to the script location
3. Execute:
   ```powershell
   .\ApplyConfigurations.ps1
   ```
4. Wait for completion message
5. Restart Explorer or log out/in for UI changes to apply:
   ```powershell
   taskkill /f /im explorer.exe && start explorer.exe
   ```

### Option C: Verify Applied Settings

Run either verification script as Administrator:

```powershell
# PowerShell version (detailed output)
.\DeploymentVerification.ps1

# CMD version (simplified output)
.\VerifyDeployment.cmd
```

---

## 🔧 What Gets Configured

### System-Wide Settings (HKLM)
- Bypass TPM 2.0, Secure Boot, RAM, and CPU requirements for installation
- Disable Windows Copilot and AI data analysis features
- Set telemetry to minimum (Security/0)
- Enable Win32 long paths (remove 260-character limit)
- Disable Fast Startup for dual-boot compatibility
- Remove consumer features and promotional content
- Optimize CPU priority for background services
- Disable Windows Error Reporting and Defender sample submission
- Hide 3D Objects folder from File Explorer
- Configure network throttling and TCP autotuning for performance

### User Settings (HKCU)
- Show hidden files and file extensions in Explorer
- Launch Explorer to "This PC" instead of Quick Access
- Display full path in Explorer title bar
- Disable Bing search integration in Start menu
- Hide Task View, Widgets, and Chat buttons from taskbar
- Disable advertising ID and tailored experiences
- Configure accessibility keys (disable Sticky/Filter/Toggle prompts)

### Services & Power
- Conditionally disable SysMain (Superfetch) on SSD/Server systems
- Disable hibernation to free disk space
- Set power plan to High Performance
- Disable sleep and monitor timeout timers

### Application Management
- Remove provisioned bloatware packages (Xbox, Teams, Bing, etc.)
- Block automatic installation of DevHome and Outlook OOBE stubs
- Skip application removal on Server editions

---

## 🧪 Verification

After applying configurations, run `DeploymentVerification.ps1` to confirm settings:

```
✅ Passed  : 28
❌ Failed  : 0
⚠️  Missing : 2
```

**Interpretation**:
- ✅ **PASS**: Setting matches expected value
- ❌ **FAIL**: Setting exists but has incorrect value
- ⚠️ **MISS**: Setting not found (may be edition-specific or not applicable)

**Note**: HKCU checks reflect the current user profile. If run as Administrator, per-user settings may not appear until a standard user logs in.

---

## 🛠️ Troubleshooting

### Script won't run: Execution policy error
```powershell
# Allow script execution for current user only
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Verification shows many "MISS" results
- Ensure script is run **as Administrator** (required for HKLM access)
- HKCU settings apply on first standard-user login; re-run verification after logging in as a normal user
- Some settings are edition-specific (e.g., AppX removal skipped on Server)

### Registry changes not applying
- Close any open Registry Editor instances before running scripts
- Some keys require a reboot to take effect
- Check `%TEMP%\ApplyConfig_*.log` for detailed execution logs

### AppX removal fails or hangs
- Ensure internet connectivity is available (for package metadata)
- Some packages may be in use; retry after reboot
- Server editions skip AppX operations by design

### Computer name shows as "DESKTOP-XXXXX"
- The hostname is set during the `specialize` pass; if Windows Setup cached a random name first, the override may not apply
- Manually rename via System Properties or run:
  ```powershell
  Rename-Computer -NewName "DEVICE-XXX" -Force; Restart-Computer
  ```

---

## 🔒 Security Considerations

- **AutoLogon**: The unattended file uses `LogonCount=1` for the built-in Administrator account. Ensure physical security during deployment.
- **BitLocker**: Device encryption is disabled by default. Re-enable post-deployment if required by policy.
- **Telemetry**: Set to minimum (0). Some enterprise management tools may require higher levels; adjust `AllowTelemetry` value if needed.
- **Script Signing**: Scripts are unsigned. For enterprise deployment, sign with a trusted certificate or use AppLocker/WDAC to allow execution.

---

## 📁 File Locations

| Item | Path |
|------|------|
| Deployment scripts | `C:\Windows\Setup\Scripts\` |
| Execution logs | `%TEMP%\ApplyConfig_*.log`, `%TEMP%\Specialize_Transcript.log` |
| Verification report | `%USERPROFILE%\Desktop\VerificationResult.txt` |
| Completion marker | `C:\Windows\Setup\Scripts\SETUP_COMPLETE.txt` |

---

## 🔄 Updating Configurations

To modify settings:

1. Edit the relevant section in `autounattend.xml` or `ApplyConfigurations.ps1`
2. Test changes in a virtual machine before production deployment
3. Update `DeploymentVerification.ps1` to check new settings
4. Document changes in this README for team reference

**Recommended testing workflow**:
```powershell
# 1. Create VM snapshot
# 2. Apply configuration
# 3. Run verification
# 4. Test critical applications
# 5. Revert snapshot if issues found
```

---

## 📄 License

This configuration suite is provided as-is for educational and administrative use. No warranty is expressed or implied. Users are responsible for testing configurations in a non-production environment before deployment.

---

## 📞 Support & Contributions

- Review logs in `%TEMP%` for troubleshooting
- Verify XML syntax with: `xmllint --noout autounattend.xml` (Linux) or PowerShell `[xml]::new().Load("autounattend.xml")`
- For enterprise deployment questions, consult Microsoft documentation on Windows Answer Files and Configuration Designer

---

*Last updated: May 2026*  
*Compatible with Windows 10/11 builds 19041-26100+*