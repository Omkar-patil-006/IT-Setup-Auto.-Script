# ============================================================
#        DF IT TEAM - Complete Windows Setup Script
# ============================================================
# Tasks:
#   1. Create Local User Account
#   2. Install Applications
#   3. Move User Folders (Desktop, Downloads, Documents) to D:
#   4. System Cleanup & Health Check
#   5. Windows Update
#   6. Summary Report
# ============================================================
# Auto-elevate to Administrator if not already
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "  [info] Restarting as Administrator..." -ForegroundColor Yellow
    Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ---------- Admin Check ----------
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "`n[ERROR] Please run this script as Administrator!" -ForegroundColor Red
    Write-Host "Right-click the script -> Run as Administrator" -ForegroundColor Yellow
    pause
    exit
}

# ---------- Task Tracker ----------
$TaskResults = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-Result {
    param($Task, $Status, $Note = "")
    $TaskResults.Add([PSCustomObject]@{
        Task   = $Task
        Status = $Status
        Note   = $Note
    })
}

# ============================================================
# HEADER
# ============================================================
Clear-Host
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "           Windows Setup Script                             " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# SECTION 1: CREATE USER ACCOUNT
# ============================================================
Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
Write-Host " SECTION 1: Create User Account" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------" -ForegroundColor Yellow

# Ask Username
$NewUsername = Read-Host "`nEnter Username"

# Ask Password
do {
    $NewPassword        = Read-Host "Enter Password" -AsSecureString
    $ConfirmPassword    = Read-Host "Confirm Password" -AsSecureString

    $pwd1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))
    $pwd2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ConfirmPassword))

    if ($pwd1 -ne $pwd2) {
        Write-Host "[!] Passwords do not match. Please try again." -ForegroundColor Red
    }
} while ($pwd1 -ne $pwd2)

# Ask Rights
Write-Host "`nSelect Account Type:"
Write-Host "  [1] Administrator"
Write-Host "  [2] Normal User"
$RightsChoice = Read-Host "Enter choice (1 or 2)"

$IsAdmin = $RightsChoice -eq "1"

# Create User
try {
    $SecurePwd = ConvertTo-SecureString $pwd1 -AsPlainText -Force

    if (Get-LocalUser -Name $NewUsername -ErrorAction SilentlyContinue) {
        Write-Host "[SKIP] User '$NewUsername' already exists." -ForegroundColor Yellow
        Add-Result "Create User: $NewUsername" "SKIPPED" "User already exists"
    } else {
        New-LocalUser -Name $NewUsername -Password $SecurePwd -FullName $NewUsername -Description "Created by DF IT Script" -PasswordNeverExpires | Out-Null

        if ($IsAdmin) {
            Add-LocalGroupMember -Group "Administrators" -Member $NewUsername
            Write-Host "[OK] User '$NewUsername' created as Administrator." -ForegroundColor Green
            Add-Result "Create User: $NewUsername" "SUCCESS" "Administrator account created"
        } else {
            Add-LocalGroupMember -Group "Users" -Member $NewUsername
            Write-Host "[OK] User '$NewUsername' created as Normal User." -ForegroundColor Green
            Add-Result "Create User: $NewUsername" "SUCCESS" "Normal user account created"
        }
    }
} catch {
    Write-Host "[FAIL] Could not create user: $_" -ForegroundColor Red
    Add-Result "Create User: $NewUsername" "FAILED" $_.Exception.Message
}
# ============================================================
#  CHANGE COMPUTER HOSTNAME
# ============================================================

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host " SECTION 2: CHANGE COMPUTER HOSTNAME                                  " -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""

# Show current hostname
Write-Host "  Current Computer Name: " -NoNewline
Write-Host $env:COMPUTERNAME -ForegroundColor Yellow
Write-Host ""

# Ask for new hostname
$newName = Read-Host "  Enter New Computer Name (e.g. DF-D-Omkar)"

if (-not $newName -or $newName.Trim() -eq "") {
    Write-Host "  [ERROR] Computer name cannot be empty." -ForegroundColor Red
    pause
    exit
}

$newName = $newName.Trim()

# Confirm
Write-Host ""
Write-Host "  You entered: " -NoNewline
Write-Host $newName -ForegroundColor Cyan
$confirm = Read-Host "  Are you sure? (Y/N)"

if ($confirm -eq "Y" -or $confirm -eq "y") {

    try {
        Rename-Computer -NewName $newName -LocalCredential (Get-Credential -Message "Enter local Admin credentials to rename this PC" -UserName $env:USERNAME) -Force -ErrorAction Stop
        Write-Host ""
        Write-Host "  [ok] Hostname changed to: $newName" -ForegroundColor Green
        Write-Host ""
        Write-Host "  ****************************************************" -ForegroundColor Yellow
        Write-Host "  *  NOTE: Please RESTART the computer to apply the  *" -ForegroundColor Yellow
        Write-Host "  *        new hostname change.                       *" -ForegroundColor Yellow
        Write-Host "  ****************************************************" -ForegroundColor Yellow
        Write-Host ""
    } catch {
        Write-Host ""
        Write-Host "  [ERROR] Failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  [tip] Make sure you entered the correct local Admin password." -ForegroundColor DarkGray
    }

} else {
    Write-Host ""
    Write-Host "  [CANCELLED] No changes made." -ForegroundColor DarkGray
}

Write-Host ""
pause

# ============================================================
# SECTION 2: INSTALL APPLICATIONS
# ============================================================
Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host "  STEP 3: INSTALLING APPLICATIONS                           " -ForegroundColor Cyan
Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""

$TempFolder = "$env:TEMP\ITSetupApps"
if (-not (Test-Path $TempFolder)) { New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null }

function Install-App {
    param (
        [string]$AppName,
        [string]$DownloadUrl,
        [string]$InstallerFile,
        [string]$InstallArgs,
        [string]$CheckPath
    )

    Write-Host "  -> $AppName" -ForegroundColor White

    if ($CheckPath -and (Test-Path $CheckPath)) {
        Write-Host "     [SKIP] Already installed." -ForegroundColor Yellow
        Add-Result "Install: $AppName" "SKIPPED" "Already installed"
        Write-Host ""
        return
    }

    $outFile = "$TempFolder\$InstallerFile"

    try {
        Write-Host "     [1/2] Downloading..." -ForegroundColor DarkGray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        $webClient.DownloadFile($DownloadUrl, $outFile)

        if (-not (Test-Path $outFile) -or (Get-Item $outFile).Length -lt 1MB) {
            throw "Downloaded file is invalid or too small."
        }

        Write-Host "     [2/2] Installing silently..." -ForegroundColor DarkGray
        $proc = Start-Process -FilePath $outFile -ArgumentList $InstallArgs -Wait -PassThru -ErrorAction Stop

        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641) {
            Write-Host "     [ok] $AppName installed successfully!" -ForegroundColor Green
            Add-Result "Install: $AppName" "SUCCESS" "Installed successfully"
        } else {
            Write-Host "     [WARN] Installed with exit code: $($proc.ExitCode)" -ForegroundColor Yellow
            Add-Result "Install: $AppName" "WARNING" "Exit Code $($proc.ExitCode)"
        }
    } catch {
        Write-Host "     [ERROR] Failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "     [info] Please install $AppName manually." -ForegroundColor DarkGray
        Add-Result "Install: $AppName" "FAILED" $_.Exception.Message
    }

    if (Test-Path $outFile) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
    Write-Host ""
}

# --- Google Chrome ---
Install-App `
    -AppName       "Google Chrome" `
    -DownloadUrl   "https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7B00000000-0000-0000-0000-000000000000%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Dempty/update2/installers/ChromeSetup.exe" `
    -InstallerFile "ChromeSetup.exe" `
    -InstallArgs   "/silent /install" `
    -CheckPath     "C:\Program Files\Google\Chrome\Application\chrome.exe"

# --- Team Viewer ---
Install-App `
    -AppName       "TeamViewer" `
    -DownloadUrl   "https://download.teamviewer.com/download/TeamViewer_Setup_x64.exe" `
    -InstallerFile "TeamViewerSetup.exe" `
    -InstallArgs   "/S" `
    -CheckPath     "C:\Program Files\TeamViewer\TeamViewer.exe"

# --- Mozilla Firefox ---
Install-App `
    -AppName       "Mozilla Firefox" `
    -DownloadUrl   "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US" `
    -InstallerFile "FirefoxSetup.exe" `
    -InstallArgs   "-ms" `
    -CheckPath     "C:\Program Files\Mozilla Firefox\firefox.exe"

# --- WinRAR ---
Install-App `
    -AppName       "WinRAR" `
    -DownloadUrl   "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-701.exe" `
    -InstallerFile "WinRARSetup.exe" `
    -InstallArgs   "/S" `
    -CheckPath     "C:\Program Files\WinRAR\WinRAR.exe"

# --- Zoom ---
Install-App `
    -AppName       "Zoom" `
    -DownloadUrl   "https://zoom.us/client/latest/ZoomInstallerFull.exe?archType=x64" `
    -InstallerFile "ZoomSetup.exe" `
    -InstallArgs   "/silent" `
    -CheckPath     "C:\Program Files\Zoom\bin\Zoom.exe"

# --- AnyDesk ---
Install-App `
    -AppName       "AnyDesk" `
    -DownloadUrl   "https://download.anydesk.com/AnyDesk.exe" `
    -InstallerFile "AnyDeskSetup.exe" `
    -InstallArgs   "--install `"C:\Program Files\AnyDesk`" --start-with-win --create-shortcuts --silent" `
    -CheckPath     "C:\Program Files\AnyDesk\AnyDesk.exe"

# --- AVG Business Antivirus ---
# ============================================================================================
# AVG Business Antivirus (Paid/Subscribed Version)
# -------------------------------------
# Place your AVG Business installer in the Installers\ folder.
# Script checks for these filenames in order (first match wins):
#   1. (your-avg-business-installer).exe   <- rename your paid EXE to this
#   2. avg_business_agent_setup_online.exe
#   3. avg_business_agent_setup_online.msi (last resort)
#
# NOTE: AVG Business requires a valid paid subscription/license.
#       Download your installer from your AVG Business account portal.
# ============================================================================================
Write-Host "  -> AVG Business Antivirus" -ForegroundColor White

$avgLogFile   = "$env:TEMP\AVG_Install.log"

# NOTE: Rename your paid AVG Business EXE installer to "avg_business_setup.exe"
#       and place it in the Installers\ folder before running this script.
$avgCandidates = @(
    [PSCustomObject]@{ Path = (Join-Path $PSScriptRoot "Installers\avg_business_setup.exe");              Type = "EXE" },
    [PSCustomObject]@{ Path = (Join-Path $PSScriptRoot "Installers\avg_business_agent_setup_online.exe"); Type = "EXE" },
    [PSCustomObject]@{ Path = (Join-Path $PSScriptRoot "Installers\avg_business_agent_setup_online.msi"); Type = "MSI" }
)

$avgInstaller = $null
$avgType      = $null
foreach ($c in $avgCandidates) {
    if (Test-Path $c.Path) {
        $avgInstaller = $c.Path
        $avgType      = $c.Type
        break
    }
}

if (Test-Path "C:\Program Files\AVG\Antivirus\AVGUI.exe") {
    Write-Host "     [SKIP] AVG already installed." -ForegroundColor Yellow
    Add-Result "Install: AVG Business" "SKIPPED" "Already installed"

} elseif (-not $avgInstaller) {
    Write-Host "     [ERROR] No AVG installer found in Installers\ folder." -ForegroundColor Red
    Write-Host "     [info]  Place your paid AVG Business EXE installer in:" -ForegroundColor DarkGray
    Write-Host "             $PSScriptRoot\Installers\" -ForegroundColor DarkGray
    Write-Host "     [info]  Rename it to: avg_business_setup.exe" -ForegroundColor DarkGray
    Add-Result "Install: AVG Business" "FAILED" "Installer EXE not found in Installers folder"

} else {
    Write-Host "     [info] Found installer ($avgType): $(Split-Path $avgInstaller -Leaf)" -ForegroundColor DarkGray

    try {
        # Pause Windows Defender to avoid file-lock conflicts during install
        Write-Host "     [1/3] Pausing Windows Defender briefly..." -ForegroundColor DarkGray
        $defenderPaused = $false
        try {
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
            $defenderPaused = $true
        } catch {
            Write-Host "     [info] Defender not running or could not be paused. Continuing..." -ForegroundColor DarkGray
        }

        Write-Host "     [2/3] Installing AVG Business silently ($avgType)..." -ForegroundColor DarkGray

        if ($avgType -eq "EXE") {
            $proc = Start-Process `
                -FilePath     $avgInstaller `
                -ArgumentList "/silent /install" `
                -Wait `
                -PassThru `
                -ErrorAction  Stop
        } else {
            # MSI: ALLUSERS=1 fixes most 1603 errors; /L*V writes a debug log
            $msiArgs = "/i `"$avgInstaller`" /qn /norestart ALLUSERS=1 /L*V `"$avgLogFile`""
            $proc = Start-Process `
                -FilePath     "msiexec.exe" `
                -ArgumentList $msiArgs `
                -Wait `
                -PassThru `
                -ErrorAction  Stop
        }

        # Always re-enable Defender
        if ($defenderPaused) {
            Write-Host "     [3/3] Re-enabling Windows Defender..." -ForegroundColor DarkGray
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        }

        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641) {
            Write-Host "     [ok] AVG Business installed successfully!" -ForegroundColor Green
            if ($proc.ExitCode -ne 0) {
                Write-Host "     [info] Reboot required to complete setup." -ForegroundColor Yellow
            }
            Add-Result "Install: AVG Business" "SUCCESS" "Installed (Exit $($proc.ExitCode))"
        } else {
            Write-Host "     [ERROR] Exit Code: $($proc.ExitCode)" -ForegroundColor Red
            if ($avgType -eq "MSI") {
                Write-Host "     [info] Debug log: $avgLogFile  (search for 'value 3')" -ForegroundColor DarkGray
            }
            Add-Result "Install: AVG Business" "FAILED" "Exit Code $($proc.ExitCode)"
        }

    } catch {
        if ($defenderPaused) { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue }
        Write-Host "     [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Add-Result "Install: AVG Business" "FAILED" $_.Exception.Message
    }
}

Write-Host ""
# --- Nudi ---
# ============================================================================================
# Adobe Acrobat Reader
# -------------------------------------
# EXIT CODE 150202 = the EXE bootstrapper could not extract/run internal MSI components.
# Root cause: the installer EXE (AcroRdrDC2100120145_en_US.exe) is a downloader/bootstrapper
# that needs internet OR it unpacks a temp MSI that gets blocked by Defender/permissions.
#
# FIXES APPLIED:
#   1. Added /sPB flag  = suppresses progress bar (cleaner silent mode)
#   2. Added PATCH=""   = tells installer not to look for online patches (avoids net calls)
#   3. Added /msi flags = SUPPRESS_APP_LAUNCH=YES prevents post-install launch that can fail
#   4. Defender paused  = prevents Defender from blocking the unpacked temp MSI
#   5. Extracts first   = if EXE supports /extract, we extract then run the MSI directly
#      (most reliable method - bypasses the bootstrapper entirely)
# ============================================================================================
Write-Host "  -> Adobe Acrobat Reader" -ForegroundColor White

$adobeInstaller = Join-Path $PSScriptRoot "Installers\AcroRdrDC2100120145_en_US.exe"
$adobeExtracted = "$env:TEMP\AdobeExtract"
$adobeLogFile   = "$env:TEMP\Adobe_Install.log"

# Check paths - Adobe can install to two possible locations
$adobeInstalled = (Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe") -or
                  (Test-Path "C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe")

if (-not (Test-Path $adobeInstaller)) {
    Write-Host "     [ERROR] Adobe installer not found at: $adobeInstaller" -ForegroundColor Red
    Add-Result "Install: Adobe Reader" "FAILED" "Installer EXE not found"

} elseif ($adobeInstalled) {
    Write-Host "     [SKIP] Adobe Reader already installed." -ForegroundColor Yellow
    Add-Result "Install: Adobe Reader" "SKIPPED" "Already installed"

} else {
    try {
        # Pause Defender - Adobe's temp MSI extraction is commonly blocked by real-time scan
        Write-Host "     [1/3] Pausing Windows Defender briefly..." -ForegroundColor DarkGray
        $adobeDefenderPaused = $false
        try {
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
            $adobeDefenderPaused = $true
        } catch {
            Write-Host "     [info] Defender not running or could not be paused." -ForegroundColor DarkGray
        }

        Write-Host "     [2/3] Trying extraction method first (most reliable)..." -ForegroundColor DarkGray

        # Method 1: Extract then install MSI directly (bypasses bootstrapper = no error 150202)
        if (-not (Test-Path $adobeExtracted)) {
            New-Item -ItemType Directory -Path $adobeExtracted -Force | Out-Null
        }

        $extractProc = Start-Process `
            -FilePath     $adobeInstaller `
            -ArgumentList "/extract:`"$adobeExtracted`" /quiet" `
            -Wait `
            -PassThru `
            -ErrorAction  SilentlyContinue

        # Find the extracted MSI
        $extractedMsi = Get-ChildItem -Path $adobeExtracted -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue |
                        Select-Object -First 1

        if ($extractedMsi) {
            Write-Host "     [info] Extracted MSI found: $($extractedMsi.Name)" -ForegroundColor DarkGray
            Write-Host "     [3/3] Installing from extracted MSI..." -ForegroundColor DarkGray

            $msiArgs = "/i `"$($extractedMsi.FullName)`" /qn /norestart EULA_ACCEPT=YES SUPPRESS_APP_LAUNCH=YES ALLUSERS=1 /L*V `"$adobeLogFile`""
            $proc = Start-Process `
                -FilePath     "msiexec.exe" `
                -ArgumentList $msiArgs `
                -Wait `
                -PassThru `
                -ErrorAction  Stop
        } else {
            # Method 2: Direct EXE install with improved flags (fallback if extraction fails)
            Write-Host "     [info] Extraction not supported - using direct EXE install..." -ForegroundColor DarkGray
            Write-Host "     [3/3] Installing Adobe Reader silently..." -ForegroundColor DarkGray

            $proc = Start-Process `
                -FilePath     $adobeInstaller `
                -ArgumentList "/sAll /rs /sPB /msi EULA_ACCEPT=YES SUPPRESS_APP_LAUNCH=YES" `
                -Wait `
                -PassThru `
                -ErrorAction  Stop
        }

        # Re-enable Defender
        if ($adobeDefenderPaused) {
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        }

        # Clean up extraction folder
        if (Test-Path $adobeExtracted) {
            Remove-Item $adobeExtracted -Recurse -Force -ErrorAction SilentlyContinue
        }

        if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq 1641) {
            Write-Host "     [ok] Adobe Reader installed successfully!" -ForegroundColor Green
            if ($proc.ExitCode -ne 0) {
                Write-Host "     [info] Reboot required to complete setup." -ForegroundColor Yellow
            }
            Add-Result "Install: Adobe Reader" "SUCCESS" "Installed (Exit $($proc.ExitCode))"
        } else {
            Write-Host "     [ERROR] Exit Code: $($proc.ExitCode)" -ForegroundColor Red
            Write-Host "     [info] Debug log saved to: $adobeLogFile" -ForegroundColor DarkGray
            if ($proc.ExitCode -eq 150202) {
                Write-Host "     [tip]  Error 150202 = bootstrapper blocked. Try downloading a fresh" -ForegroundColor DarkGray
                Write-Host "            full offline installer from: https://get.adobe.com/reader/enterprise/" -ForegroundColor DarkGray
            }
            Add-Result "Install: Adobe Reader" "FAILED" "Exit Code $($proc.ExitCode)"
        }

    } catch {
        if ($adobeDefenderPaused) { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue }
        Write-Host "     [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Add-Result "Install: Adobe Reader" "FAILED" $_.Exception.Message
    }
}

Write-Host ""

# -------------------------------------------------------- Nudi (Kannada Software) ------------------------------------------------
Write-Host "  -> Nudi Kannada Software" -ForegroundColor White

$nudiInstaller = Join-Path $PSScriptRoot "Installers\Nudi_6.0_setup.exe"

if (-not (Test-Path $nudiInstaller)) {
    Write-Host "     [ERROR] Nudi installer not found at: $nudiInstaller" -ForegroundColor Red
    Add-Result "Install: Nudi" "FAILED" "Installer EXE not found"

} elseif (Test-Path "C:\Program Files\Nudi 6.0\Nudi.exe") {
    Write-Host "     [SKIP] Nudi already installed." -ForegroundColor Yellow
    Add-Result "Install: Nudi" "SKIPPED" "Already installed"

} else {
    try {
        Write-Host "     [1/2] Installing Nudi silently..." -ForegroundColor DarkGray

        $proc = Start-Process `
            -FilePath     $nudiInstaller `
            -ArgumentList "/SILENT" `
            -Wait `
            -PassThru `
            -ErrorAction  Stop

        if ($proc.ExitCode -eq 0) {
            Write-Host "     [ok] Nudi installed successfully!" -ForegroundColor Green
            Add-Result "Install: Nudi" "SUCCESS" "Installed successfully"
        } else {
            Write-Host "     [WARN] Nudi Exit Code: $($proc.ExitCode)" -ForegroundColor Yellow
            Add-Result "Install: Nudi" "WARNING" "Exit Code $($proc.ExitCode)"
        }
    } catch {
        Write-Host "     [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Add-Result "Install: Nudi" "FAILED" $_.Exception.Message
    }
}

Write-Host ""
# =========================================================
# SECTION 4: FOLDER REDIRECTION TO D:
# =========================================================
Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
Write-Host " SECTION 4: Folder Redirection to D:" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
# =========================================================
# CLEAN FOLDER REDIRECTION TO D:
# Desktop / Downloads / Documents
# =========================================================

# RUN AS ADMINISTRATOR

# ---------------------------------------------------------
# USER
# ---------------------------------------------------------

$User = $env:USERNAME

# ---------------------------------------------------------
# PATHS
# ---------------------------------------------------------

$DesktopNew   = "D:\$User\Desktop"
$DownloadsNew = "D:\$User\Downloads"
$DocumentsNew = "D:\$User\Documents"

# ---------------------------------------------------------
# CREATE D: FOLDERS
# ---------------------------------------------------------

New-Item -ItemType Directory -Force -Path $DesktopNew   | Out-Null
New-Item -ItemType Directory -Force -Path $DownloadsNew | Out-Null
New-Item -ItemType Directory -Force -Path $DocumentsNew | Out-Null

# ---------------------------------------------------------
# MOVE EXISTING FILES
# ---------------------------------------------------------

robocopy "$env:USERPROFILE\Desktop"   $DesktopNew   /E /MOVE
robocopy "$env:USERPROFILE\Downloads" $DownloadsNew /E /MOVE
robocopy "$env:USERPROFILE\Documents" $DocumentsNew /E /MOVE

# ---------------------------------------------------------
# UPDATE WINDOWS FOLDER LOCATIONS
# ---------------------------------------------------------

$Reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

Set-ItemProperty -Path $Reg -Name "Desktop" -Value $DesktopNew
Set-ItemProperty -Path $Reg -Name "Personal" -Value $DocumentsNew
Set-ItemProperty -Path $Reg -Name "{374DE290-123F-4565-9164-39C4925E467B}" -Value $DownloadsNew

# ---------------------------------------------------------
# REFRESH EXPLORER
# ---------------------------------------------------------

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 3

Start-Process explorer.exe

# ---------------------------------------------------------
# REMOVE LINKS FOLDER SHORTCUTS
# ---------------------------------------------------------

$Links = "$env:USERPROFILE\Links"

Remove-Item "$Links\Desktop.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$Links\Downloads.lnk" -Force -ErrorAction SilentlyContinue
Remove-Item "$Links\Documents.lnk" -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------
# HIDE OLD SPECIAL FOLDERS
# ---------------------------------------------------------

attrib +h "$env:USERPROFILE\Desktop"   2>$null
attrib +h "$env:USERPROFILE\Downloads" 2>$null
attrib +h "$env:USERPROFILE\Documents" 2>$null

# ---------------------------------------------------------
# DONE
# ---------------------------------------------------------

Write-Host ""
Write-Host "========================================"
Write-Host " FOLDERS MOVED SUCCESSFULLY TO D:"
Write-Host "========================================"
Write-Host ""
Write-Host "Desktop   -> $DesktopNew"
Write-Host "Downloads -> $DownloadsNew"
Write-Host "Documents -> $DocumentsNew"
Write-Host ""
Write-Host "Old folders hidden from C: drive."
Write-Host ""


# ============================================================
# SECTION 5: WINDOWS UPDATE  [COMMENTED OUT]
# ============================================================
Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
Write-Host " SECTION 5: Windows Update" -ForegroundColor Yellow
Write-Host "------------------------------------------------------------" -ForegroundColor Yellow

Write-Host "`n[INFO] Checking for Windows Updates ..." -ForegroundColor Cyan
try {
    # Install PSWindowsUpdate module if not present
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "[INFO] Installing PSWindowsUpdate module ..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -AllowClobber | Out-Null
    }

    Import-Module PSWindowsUpdate -Force

    $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop

    if ($updates.Count -eq 0) {
        Write-Host "[OK] Windows is up to date. No updates available." -ForegroundColor Green
        Add-Result "Windows Update" "SUCCESS" "Already up to date"
    } else {
        Write-Host "[INFO] Found $($updates.Count) update(s). Installing..." -ForegroundColor Yellow
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Confirm:$false | Out-Null
        Write-Host "[OK] Windows Updates installed successfully." -ForegroundColor Green
        Add-Result "Windows Update" "SUCCESS" "$($updates.Count) update(s) installed"
    }
} catch {
    # Fallback: use built-in Windows Update via COM
    Write-Host "[INFO] Trying fallback Windows Update method..." -ForegroundColor Yellow
    try {
        $updateSession   = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher  = $updateSession.CreateUpdateSearcher()
        $searchResult    = $updateSearcher.Search("IsInstalled=0 and Type='Software'")

        if ($searchResult.Updates.Count -eq 0) {
            Write-Host "[OK] No updates available." -ForegroundColor Green
            Add-Result "Windows Update" "SUCCESS" "Already up to date"
        } else {
            Write-Host "[INFO] Found $($searchResult.Updates.Count) update(s)." -ForegroundColor Yellow
            $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($update in $searchResult.Updates) { $updatesToInstall.Add($update) | Out-Null }

            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $updatesToInstall
            $installResult = $installer.Install()

            Write-Host "[OK] Updates installed. Result Code: $($installResult.ResultCode)" -ForegroundColor Green
            Add-Result "Windows Update" "SUCCESS" "$($searchResult.Updates.Count) update(s) installed"
        }
    } catch {
        Write-Host "[FAIL] Windows Update error: $_" -ForegroundColor Red
        Add-Result "Windows Update" "FAILED" $_.Exception.Message
    }
}

# ============================================================
# FINAL SUMMARY REPORT
# ============================================================

$success = ($TaskResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
$failed  = ($TaskResults | Where-Object { $_.Status -eq "FAILED" }).Count
$skipped = ($TaskResults | Where-Object { $_.Status -eq "SKIPPED" }).Count
$warning = ($TaskResults | Where-Object { $_.Status -eq "WARNING" }).Count
$total   = $TaskResults.Count

Clear-Host
Write-Host ""
Write-Host "  ############################################################" -ForegroundColor Cyan
Write-Host "  #                                                          #" -ForegroundColor Cyan
Write-Host "  #           IT TEAM - SETUP COMPLETE REPORT             #" -ForegroundColor Cyan
Write-Host "  #                                                          #" -ForegroundColor Cyan
Write-Host "  ############################################################" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Computer  : $env:COMPUTERNAME" -ForegroundColor White
Write-Host "  User      : $NewUsername" -ForegroundColor White
Write-Host "  Date      : $(Get-Date -Format 'dd-MM-yyyy  hh:mm tt')" -ForegroundColor White
Write-Host ""
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host "   #   TASK                                    STATUS    NOTE " -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkCyan

$counter = 1
foreach ($item in $TaskResults) {
    $color = switch ($item.Status) {
        "SUCCESS" { "Green"  }
        "FAILED"  { "Red"    }
        "SKIPPED" { "Yellow" }
        "WARNING" { "Yellow" }
        default   { "White"  }
    }
    $icon = switch ($item.Status) {
        "SUCCESS" { "[OK]  " }
        "FAILED"  { "[FAIL]" }
        "SKIPPED" { "[SKIP]" }
        "WARNING" { "[WARN]" }
        default   { "      " }
    }
    $line = "   {0,-2}  {1,-38}  {2,-6}  {3}" -f $counter, $item.Task, $icon, $item.Note
    Write-Host $line -ForegroundColor $color
    $counter++
}

Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  RESULT SUMMARY:" -ForegroundColor White
Write-Host "  +-----------------------+" -ForegroundColor Gray
Write-Host ("  | Total Tasks  : {0,-5} |" -f $total)   -ForegroundColor White
Write-Host ("  | Completed    : {0,-5} |" -f $success) -ForegroundColor Green
Write-Host ("  | Failed       : {0,-5} |" -f $failed)  -ForegroundColor Red
Write-Host ("  | Warnings     : {0,-5} |" -f $warning) -ForegroundColor Yellow
Write-Host ("  | Skipped      : {0,-5} |" -f $skipped) -ForegroundColor Yellow
Write-Host "  +-----------------------+" -ForegroundColor Gray
Write-Host ""

if ($failed -gt 0) {
    Write-Host "  [!] Some tasks FAILED. Please check above and fix manually." -ForegroundColor Red
} else {
    Write-Host "  [OK] All tasks completed successfully!" -ForegroundColor Green
}

Write-Host ""
Write-Host "  ############################################################" -ForegroundColor Cyan
Write-Host "  #  NOTE: Please RESTART the computer to apply all changes  #" -ForegroundColor Yellow
Write-Host "  ############################################################" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Author : Omkar patil" -ForegroundColor DarkCyan
Write-Host ""

# Ask Restart
$restart = Read-Host "  Do you want to restart the computer now? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host ""
    Write-Host "  [info] Restarting in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Host ""
    Write-Host "  [info] Restart skipped. Please restart manually." -ForegroundColor DarkGray
}

pause
