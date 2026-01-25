<#
.SYNOPSIS
  Installs Microsoft Edge WebView2 Runtime (x64) from a fixed, direct link.
  Needed on terminal servers and other systems where WebView2 is not pre-installed.

.DESCRIPTION
  1) Defines the direct link to the x64 Evergreen WebView2 Runtime installer.
  2) Downloads and installs WebView2 Runtime silently.

.NOTES
  Run PowerShell as administrator.
#>

Write-Host "====================================================================="
Write-Host "Script to install Microsoft Edge WebView2 Runtime (x64) from direct link"
Write-Host "====================================================================="
Write-Host ""

# -------------------------------------------------------------------------------------
# Step 1: Define variables for the direct download URL and local paths
# -------------------------------------------------------------------------------------
Write-Host "Defining the direct link and local file paths for the WebView2 installer..."

$webview2DownloadURL   = "https://go.microsoft.com/fwlink/p/?LinkId=2124703"  # Official x64 link
$webview2InstallerName = "MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
$tempFolder            = Join-Path $env:TEMP "WebView2Install"
$webview2InstallerPath = Join-Path $tempFolder $webview2InstallerName

Write-Host "Variables:"
Write-Host "`tDirect Download URL    : $webview2DownloadURL"
Write-Host "`tTemp Folder            : $tempFolder"
Write-Host "`tWebView2 Installer Path: $webview2InstallerPath"
Write-Host ""

# Create the temp folder if it doesn't exist
if (!(Test-Path $tempFolder)) {
    Write-Host "Creating temp folder for WebView2 download..."
    try {
        New-Item -ItemType Directory -Path $tempFolder | Out-Null
        Write-Host "Temp folder created." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create temp folder: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
}
else {
    Write-Host "Temp folder already exists."
}
Write-Host ""

# -------------------------------------------------------------------------------------
# Step 2: Download the WebView2 installer
# -------------------------------------------------------------------------------------
Write-Host "Downloading WebView2 installer from direct URL: $webview2DownloadURL"

try {
    Invoke-WebRequest -Uri $webview2DownloadURL -OutFile $webview2InstallerPath
    Write-Host "Download complete: $webview2InstallerPath" -ForegroundColor Green
}
catch {
    Write-Host "Failed to download the WebView2 installer: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Cannot continue without the installer. Exiting..."
    return
}

Write-Host ""

# -------------------------------------------------------------------------------------
# Step 3: Install WebView2 Runtime silently
# -------------------------------------------------------------------------------------
Write-Host "Installing WebView2 Runtime silently..."
try {
    # /silent /install are commonly used parameters for silent installation
    Start-Process -FilePath $webview2InstallerPath -ArgumentList "/silent", "/install" -Wait
    Write-Host "WebView2 Runtime installation complete." -ForegroundColor Green
}
catch {
    Write-Host "Failed to install WebView2 Runtime: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Cannot continue. Exiting..."
    return
}

Write-Host ""
Write-Host "All done!"
