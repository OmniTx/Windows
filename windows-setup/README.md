# Windows Deployment Configuration Suite

A hardened, privacy-focused, performance-optimized `autounattend.xml` for Windows 10/11 installations. Compatible with Pro, Home, LTSC, and Server 2019–2025 editions.

---

## 📦 Contents

| File | Purpose | When to Use |
|------|---------|-------------|
| `autounattend.xml` | Unattended deployment configuration | Fresh Windows installation via USB/ISO |

---

## ⚙️ System Requirements

- **Operating System**: Windows 10/11 Pro, Home, Enterprise, LTSC, or Server 2019–2025
- **Architecture**: x64 (AMD64)
- **PowerShell**: 5.1+ (ships with Windows 10/11)

---

## 🚀 Usage

1. Copy `autounattend.xml` to the **root** of your Windows installation USB
2. Boot from the USB
3. Windows Setup auto-detects the file and applies everything
4. After first login, run `VerifyDeployment.lnk` on the desktop to confirm

---

## 🆚 What's Extra vs a Normal Unattend File

A standard/minimal `autounattend.xml` only does: locale, EULA accept, partition, and maybe a product key. This file goes **far beyond** that with 7 embedded PowerShell scripts and extensive hardening.

### Standard Unattend Features (present in any basic file)

| Feature | Details |
|---------|---------|
| Locale / Language | `en-US`, keyboard layout `0409` |
| Accept EULA | `AcceptEula=true` |
| Skip product key UI | `WillShowUI=Never` |
| Computer name | `*` (random, then overridden by scripts) |
| Timezone | `UTC` |
| OOBE skip | Hides EULA page, online account screens |
| AutoLogon | One-time login as Administrator (no password — set manually post-setup) |

---

### 🛡️ EXTRA: Hardware Requirement Bypasses (windowsPE pass)

Not present in a normal unattend file. Bypasses all Windows 11 hardware checks:

| Bypass | Registry Key |
|--------|-------------|
| TPM 2.0 | `BypassTPMCheck = 1` |
| Secure Boot | `BypassSecureBootCheck = 1` |
| RAM | `BypassRAMCheck = 1` |
| Storage | `BypassStorageCheck = 1` |
| CPU | `BypassCPUCheck = 1` |
| BitLocker auto-encryption | `PreventDeviceEncryption = 1` |

> Allows installing Windows 11 on unsupported hardware (old CPUs, no TPM, etc.)

---

### 🛡️ EXTRA: UAC Kept Enabled (offlineServicing pass)

| Setting | Value |
|---------|-------|
| `EnableLUA` | `true` |

> Many "debloat" scripts disable UAC. This file **keeps it enabled** for security while disabling the annoying stuff separately.

---

### 🔧 EXTRA: Embedded Script System (Extensions)

Uses the [schneegans.de unattend-generator](https://schneegans.de/windows/unattend-generator/) `<Extensions>` pattern to embed **7 PowerShell scripts** directly inside the XML. During the specialize pass, an `ExtractScript` extracts them all to `C:\Windows\Setup\Scripts\`.

**This is the biggest difference from a normal unattend file — normal files can't carry scripts.**

| Script | Phase | What It Does |
|--------|-------|-------------|
| `GetComputerName.ps1` | Specialize | Generates a random hardware-based computer name (e.g. `DEVICE-A87N456`) |
| `ApplyComputerName.ps1` | Specialize | Applies the generated name via `Rename-Computer` with registry fallback |
| `Specialize.ps1` | Specialize | Main hardening — 20+ registry tweaks + bloatware removal |
| `DefaultUser.ps1` | Specialize | Configures the Default User profile (applies to all future users) |
| `UserOnce.ps1` | First User Login | Per-user tweaks via RunOnce (Bing search, ads, accessibility, etc.) |
| `FirstLogon.ps1` | First Logon | Power plan, hibernation, SysMain, verification shortcut |
| `DeploymentVerification.ps1` | Manual | Run anytime to check all settings — outputs PASS/FAIL report |

---

### 🔒 EXTRA: Privacy Hardening (Specialize.ps1)

None of these are in a normal unattend file:

| Setting | Registry Path | Value | What It Does |
|---------|--------------|-------|-------------|
| Disable Copilot | `WindowsCopilot\TurnOffWindowsCopilot` | `1` | Removes Windows Copilot |
| Disable AI data analysis | `WindowsAI\DisableAIDataAnalysis` | `1` | Blocks Recall/AI features |
| Telemetry off | `DataCollection\AllowTelemetry` | `0` | Minimum telemetry (Security only) |
| Disable activity feed | `System\EnableActivityFeed` | `0` | No activity history |
| Disable activity publishing | `System\PublishUserActivities` | `0` | No cloud activity sync |
| Disable consumer features | `CloudContent\DisableWindowsConsumerFeatures` | `1` | No suggested apps/ads |
| Disable Teams chat auto-install | `Communications\ConfigureChatAutoInstall` | `0` | No Teams popup |
| Disable mDNS | `DNSClient\EnableMulticast` | `0` | Privacy — no multicast DNS |
| Disable Windows Error Reporting | `Windows Error Reporting\Disabled` | `1` | No crash reports sent |
| Defender samples: send safe only | `Spynet\SubmitSamplesConsent` | `2` | Only send safe samples |

---

### ⚡ EXTRA: Performance Tuning (Specialize.ps1 + FirstLogon.ps1)

| Setting | Value | What It Does |
|---------|-------|-------------|
| `Win32PrioritySeparation` | `0x26` | Foreground apps get more CPU priority |
| `NetworkThrottlingIndex` | `0xFFFFFFFF` | Removes network throttling limit |
| `SystemResponsiveness` | `0` | All CPU available for foreground tasks |
| `HiberbootEnabled` | `0` | Disables Fast Startup (fixes dual-boot + SSD issues) |
| `LongPathsEnabled` | `1` | Removes 260-char path limit |
| TCP autotuning | `normal` | Ensures TCP window scaling is on |
| Game Bar disabled | `ActivationType = 0` | Stops background Game Bar processes |
| SysMain (Superfetch) | Disabled on SSD | Not needed on SSDs, wastes writes |
| Hibernation | Off | Frees disk space (= RAM size) |
| Power plan | High Performance | Max CPU, no sleep/standby |
| Monitor timeout | 0 (never) | Screen stays on |

---

### 🧹 EXTRA: Bloatware Removal (Specialize.ps1)

Removes 28 provisioned AppX packages (skipped on Server editions):

| Removed Apps |
|-------------|
| Bing Search, Clipchamp, Cortana, Dev Home |
| Microsoft Family, Feedback Hub, Get Started (Tips) |
| Mixed Reality Portal, Office Hub, OneNote |
| Outlook (new), Paint (new), Power Automate Desktop |
| Quick Assist, Skype, Solitaire Collection |
| Teams (both old & new), To Do, Wallet |
| Xbox (TCUI, App, GameOverlay, GamingOverlay, Identity, SpeechToText) |
| Gaming App, Your Phone / Phone Link |
| Copilot Provider (Win 11 only, non-LTSC) |

Also blocks OOBE auto-install stubs:
- `DevHomeUpdate`
- `OutlookUpdate`

---

### 👤 EXTRA: Default User Profile Tweaks (DefaultUser.ps1)

Applied to the Default User hive — every new user gets these settings automatically:

| Setting | Value | What It Does |
|---------|-------|-------------|
| Copilot off | `TurnOffWindowsCopilot = 1` | Per-user Copilot disable |
| OneDrive auto-run | Removed from Run key | No OneDrive popup |
| Game DVR | `AppCaptureEnabled = 0` | No background game recording |
| NumLock on | `InitialKeyboardIndicators = 2` | NumLock on at login |
| End Task in taskbar | `TaskbarEndTask = 1` | Right-click → End Task |
| Show hidden files | `Hidden = 1` | Hidden files visible |
| Show file extensions | `HideFileExt = 0` | `.exe`, `.txt` visible |
| Checkboxes in Explorer | `AutoCheckSelect = 1` | Item selection checkboxes |
| Open to This PC | `LaunchTo = 1` | Explorer opens to This PC |
| Full path in title | `FullPath = 1` | Full path in Explorer title bar |
| Search box style | `SearchboxTaskbarMode = 3` | Search icon mode |
| Hide Task View | `ShowTaskViewButton = 0` | Remove Task View from taskbar |
| Hide Widgets | `TaskbarDa = 0` | Remove Widgets from taskbar |
| Hide Chat | `TaskbarMn = 0` | Remove Chat from taskbar |
| Privacy consent | `PrivacyConsentStatus = 1` | Skip privacy consent |
| No Edge shortcut | `DisableEdgeDesktopShortcutCreation = 1` | No Edge shortcut on desktop |
| Desktop icons | Only Recycle Bin + This PC shown | Hides all other desktop icons |

---

### 👤 EXTRA: Per-User RunOnce Tweaks (UserOnce.ps1)

Runs once per user on first login (via RunOnce registry key):

| Setting | What It Does |
|---------|-------------|
| Remove Copilot AppX | Uninstalls Copilot for the user |
| Disable Bing in Search | `BingSearchEnabled = 0` |
| Disable Cortana consent | `CortanaConsent = 0` |
| Disable advertising ID | `Enabled = 0` |
| Disable tailored experiences | `TailoredExperiencesWithDiagnosticDataEnabled = 0` |
| Disable Game DVR | `GameDVR_Enabled = 0` |
| Disable Sticky Keys prompt | `Flags = 506` |
| Disable Toggle Keys prompt | `Flags = 58` |
| Disable Filter Keys prompt | `Flags = 122` |
| Disable News Feed | `ShellFeedsTaskbarViewMode = 2` |

---

### ✅ EXTRA: Deployment Verification (DeploymentVerification.ps1)

A post-install auditing tool (no normal unattend has this). Run from the desktop shortcut to get a PASS/FAIL report checking 16 settings:

- All HKLM hardening keys
- HKCU user settings
- SysMain service state
- Hibernation state
- TCP autotuning level

Output saved to `Desktop\VerificationResult.txt`.

---

## 🔒 Security Notes

- **AutoLogon** uses `LogonCount=1` — expires immediately after first login scripts run
- **Administrator password** is blank during setup — set it manually post-install
- **BitLocker** is disabled — re-enable if needed
- **UAC** stays enabled (unlike most debloat scripts)

---

## 📁 File Locations After Install

| Item | Path |
|------|------|
| Extracted scripts | `C:\Windows\Setup\Scripts\` |
| Specialize log | `C:\Windows\Setup\Scripts\Specialize.log` |
| DefaultUser log | `C:\Windows\Setup\Scripts\DefaultUser.log` |
| FirstLogon log | `C:\Windows\Setup\Scripts\FirstLogon.log` |
| UserOnce log | `%TEMP%\UserOnce.log` |
| Verification report | `%USERPROFILE%\Desktop\VerificationResult.txt` |
| Verification shortcut | `%USERPROFILE%\Desktop\VerifyDeployment.lnk` |

---

## 🛠️ Troubleshooting

| Problem | Fix |
|---------|-----|
| Setup crashes during install | Validate XML: `[xml](Get-Content autounattend.xml -Raw)` — check for unescaped `&` or `<` in embedded scripts |
| Settings not applied | Check logs in `C:\Windows\Setup\Scripts\*.log` |
| Verification shows FAIL | Some settings are edition-specific; HKCU checks need standard user login |
| Computer name is DESKTOP-XXXX | The name script may have failed; rename manually via System Properties |

---

*Last updated: May 2026*
*Compatible with Windows 10/11 builds 19041–26100+*
