# 🖥️ IT TEAM — Windows Setup Script

## 📌 About This Script

This script was created to **reduce repetitive IT setup work** and
**save time** during fresh Windows machine deployments.

Instead of manually installing each application, creating users,
and configuring folders one by one — this script does everything
automatically in a single run.

> ⚡ This script was built with the assistance of AI tools.
> Developed & maintained by **DF IT Team**.

A PowerShell automation script to quickly set up a fresh Windows machine for deployment. Built for IT teams to save time during bulk laptop/PC setup.

---

## ✅ What This Script Does

| # | Section | Description |
|---|---------|-------------|
| 1 | **Create User Account** | Creates a local Windows user (Admin or Normal) with password |
| 2 | **Change Hostname** | Renames the computer with confirmation prompt |
| 3 | **Install Applications** | Silently installs all required software |
| 4 | **Folder Redirection** | Moves Desktop, Downloads, Documents to D: drive |
| 5 | **Windows Update** | Checks and installs pending Windows updates |
| 6 | **Summary Report** | Displays a full task result table at the end |

---

## 📦 Applications Installed

| App | Type | Source |
|-----|------|--------|
| Google Chrome | Browser | Downloaded automatically |
| Mozilla Firefox | Browser | Downloaded automatically |
| TeamViewer | Remote Support | Downloaded automatically |
| Zoom | Video Conferencing | Downloaded automatically |
| WinRAR | Archive Tool | Downloaded automatically |
| AnyDesk | Remote Desktop | Downloaded automatically |
| AVG Business Antivirus | Security | **Manual — Paid license required** (see below) |
| Adobe Acrobat Reader | PDF Viewer | **Manual — place in Installers folder** |
| Nudi 6.0 | Kannada Typing | **Manual — place in Installers folder** |

---

## 📁 Folder Structure

```
📦 IT-Setup\
 ┣ 📜 DF-IT-Setup.ps1        <- Main script
 ┗ 📁 Installers\
    ┣ avg_business_setup.exe      <- Your paid AVG Business installer (rename to this)
    ┣ AcroRdrDC2100120145_en_US.exe  <- Adobe Acrobat Reader offline installer
    ┗ Nudi_6.0_setup.exe          <- Nudi Kannada software installer
```

> **Note:** Chrome, Firefox, TeamViewer, Zoom, WinRAR, and AnyDesk are downloaded automatically during setup. You only need to manually provide the 3 installers above.

---

## ⚙️ Requirements

- Windows 10 / Windows 11
- PowerShell 5.1 or later
- Run as **Administrator**
- Internet connection (for auto-downloaded apps)
- D: drive must exist (for folder redirection)

---

## 🚀 How to Run

### Step 1 — Download or clone this repo
```
git clone https://github.com/YOUR-USERNAME/df-it-setup.git
```

### Step 2 — Add your manual installers
Place these files inside the `Installers\` folder:
- `avg_business_setup.exe` — rename your paid AVG Business EXE to this name
- `AcroRdrDC2100120145_en_US.exe` — Adobe Acrobat Reader offline installer
- `Nudi_6.0_setup.exe` — Nudi 6.0 Kannada software

### Step 3 — Run the script
```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\DF-IT-Setup.ps1
```

Or simply **right-click** `IT-Setup.ps1` → **Run with PowerShell**

---

## 🔒 AVG Business Antivirus

AVG Business Antivirus requires a **paid subscription**.

1. Log in to your AVG Business account portal
2. Download your installer EXE
3. Rename it to `avg_business_setup.exe`
4. Place it in the `Installers\` folder

> The script will **not** install AVG if the installer is missing — it will show a clear error and skip.

---

## 📋 Summary Report

At the end of the script, a full summary report is shown:

$logoPath = Join-Path $PSScriptRoot ""

if (Test-Path $logoPath) {
    Start-Process $logoPath
} else {
    Write-Host "  [info] Logo image not found at: $logoPath" -ForegroundColor DarkGray
}


<p align="center">
  <img src="script output .png" width="600"/>
</p>

## ⚠️ Notes

- Script auto-elevates to Administrator if not already running as one
- A **restart is recommended** after setup to apply all changes
- Script asks for restart confirmation at the end
- All install logs are saved to `%TEMP%\` for debugging

---

## 👨‍💻 Author

**DF IT Team**  
Internal Windows Setup Automation Tool

---

## 📄 License

This script is for internal IT use. AVG Business Antivirus requires a separate paid license from AVG/Avast Business.
