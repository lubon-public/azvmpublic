<#
.SYNOPSIS
    Downloads and installs an MSI package from a given URL.

.DESCRIPTION
    This script downloads an MSI file from a specified URL and installs it with configurable options
    including silent installation, reboot control, and custom command line parameters.

.PARAMETER MsiUrl
    The URL of the MSI file to download.

.PARAMETER Silent
    If specified, performs a silent installation (equivalent to /quiet).

.PARAMETER NoReboot
    If specified, suppresses reboot after installation (equivalent to /norestart).

.PARAMETER CommandLineParams
    Additional command line parameters to pass to msiexec.

.EXAMPLE
    .\InstallMSI.ps1 -MsiUrl "https://example.com/package.msi" -Silent -NoReboot

.EXAMPLE
    .\InstallMSI.ps1 -MsiUrl "https://example.com/package.msi" -Silent -NoReboot -CommandLineParams "INSTALLDIR=C:\CustomPath"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="URL of the MSI file to download")]
    [ValidateNotNullOrEmpty()]
    [string]$MsiUrl,

    [Parameter(Mandatory=$false, HelpMessage="Perform silent installation")]
    [switch]$Silent,

    [Parameter(Mandatory=$false, HelpMessage="Suppress reboot after installation")]
    [switch]$NoReboot,

    [Parameter(Mandatory=$false, HelpMessage="Additional command line parameters for msiexec")]
    [string]$CommandLineParams = ""
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

try {
    Write-Log "Starting MSI installation process"
    Write-Log "MSI URL: $MsiUrl"

    # Create temp directory if it doesn't exist
    $tempDir = [System.IO.Path]::GetTempPath()
    $msiFileName = [System.IO.Path]::GetFileName($MsiUrl)
    
    # If URL doesn't have a file extension, generate a unique filename
    if ([string]::IsNullOrEmpty([System.IO.Path]::GetExtension($msiFileName))) {
        $msiFileName = "package_$(Get-Date -Format 'yyyyMMddHHmmss').msi"
    }
    
    $msiFilePath = Join-Path -Path $tempDir -ChildPath $msiFileName
    Write-Log "MSI will be downloaded to: $msiFilePath"

    # Download the MSI file
    Write-Log "Downloading MSI file..."
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($MsiUrl, $msiFilePath)
        $webClient.Dispose()
        Write-Log "Download completed successfully"
    }
    catch {
        Write-Log "Failed to download MSI file: $_" "ERROR"
        throw
    }

    # Verify the file was downloaded
    if (-not (Test-Path -Path $msiFilePath)) {
        throw "MSI file was not downloaded successfully"
    }

    $fileSize = (Get-Item $msiFilePath).Length
    Write-Log "Downloaded file size: $([Math]::Round($fileSize / 1MB, 2)) MB"

    # Build msiexec command line arguments
    $msiexecArgs = @("/i", "`"$msiFilePath`"")
    
    if ($Silent) {
        $msiexecArgs += "/quiet"
        Write-Log "Silent installation enabled"
    }
    
    if ($NoReboot) {
        $msiexecArgs += "/norestart"
        Write-Log "Reboot suppression enabled"
    }
    
    # Add custom command line parameters
    if (-not [string]::IsNullOrWhiteSpace($CommandLineParams)) {
        $msiexecArgs += $CommandLineParams
        Write-Log "Additional parameters: $CommandLineParams"
    }

    # Add logging
    $logFileName = "msi_install_$(Get-Date -Format 'yyyyMMddHHmmss').log"
    $logFilePath = Join-Path -Path $tempDir -ChildPath $logFileName
    $msiexecArgs += "/log"
    $msiexecArgs += "`"$logFilePath`""
    Write-Log "Installation log will be written to: $logFilePath"

    # Execute msiexec
    Write-Log "Starting MSI installation..."
    Write-Log "Command: msiexec.exe $($msiexecArgs -join ' ')"
    
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiexecArgs -Wait -PassThru -NoNewWindow
    
    $exitCode = $process.ExitCode
    Write-Log "Installation completed with exit code: $exitCode"

    # Interpret exit codes
    switch ($exitCode) {
        0 { Write-Log "Installation completed successfully" "SUCCESS" }
        1641 { Write-Log "Installation completed successfully. Reboot initiated by installer." "SUCCESS" }
        3010 { Write-Log "Installation completed successfully. Reboot required." "SUCCESS" }
        1602 { Write-Log "Installation canceled by user" "WARNING" }
        1603 { Write-Log "Fatal error during installation" "ERROR" }
        1619 { Write-Log "Installation package could not be opened" "ERROR" }
        1639 { Write-Log "Invalid command line argument" "ERROR" }
        default { Write-Log "Installation completed with exit code: $exitCode" "WARNING" }
    }

    # Clean up downloaded MSI file
    try {
        if (Test-Path -Path $msiFilePath) {
            Remove-Item -Path $msiFilePath -Force
            Write-Log "Cleaned up downloaded MSI file"
        }
    }
    catch {
        Write-Log "Failed to clean up MSI file: $_" "WARNING"
    }

    Write-Log "Installation log available at: $logFilePath"
    
    # Return exit code
    exit $exitCode
}
catch {
    Write-Log "An error occurred: $_" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}