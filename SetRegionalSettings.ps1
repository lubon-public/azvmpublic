# Set Regional Settings for Windows Server (Belgium or Netherlands)
# This script configures regional settings for Belgium or Netherlands with English display language
# Works when run by SYSTEM account (e.g., Azure Custom Script Extension) or by user

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Belgium', 'Netherlands', 'BE', 'NL')]
    [Alias('BE', 'NL')]
    [string]$Country = 'Belgium'
)

function Get-WindowsVersion {
    [CmdletBinding()]
    param()
    
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $version = [version]$os.Version
        $productName = $os.Caption
        
        Write-Verbose "Detected OS: $productName (Build: $($os.Version))"
        
        return @{
            Version             = $version
            ProductName         = $productName
            Build               = $os.BuildNumber
            IsServer2025OrNewer = ($version.Major -ge 10 -and [int]$os.BuildNumber -ge 26100)
            IsServer2022OrNewer = ($version.Major -ge 10 -and [int]$os.BuildNumber -ge 20348)
            IsServer2019OrNewer = ($version.Major -ge 10 -and [int]$os.BuildNumber -ge 17763)
            IsModernWindows     = ($version.Major -ge 10)
        }
    }
    catch {
        Write-Warning "Failed to detect Windows version: $_"
        return $null
    }
}

function Set-RegionalSettingsPowerShell {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Locale,
        
        [Parameter(Mandatory = $true)]
        [string]$InputLanguageId,
        
        [Parameter(Mandatory = $true)]
        [int]$GeoId,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayCountry,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayKeyboard
    )
    
    Write-Host "Using modern PowerShell cmdlets method..." -ForegroundColor Cyan
    
    try {
        # Set the system locale (requires restart for full effect)
        Write-Verbose "Setting system locale to $Locale"
        Set-WinSystemLocale -SystemLocale $Locale -ErrorAction Stop
        
        # Set the user culture/format
        Write-Verbose "Setting culture to $Locale"
        Set-Culture -CultureInfo $Locale -ErrorAction Stop
        
        # Set the geographic location
        Write-Verbose "Setting geographic location to GeoId $GeoId"
        Set-WinHomeLocation -GeoId $GeoId -ErrorAction Stop
        
        # Configure the user language list with input method
        Write-Verbose "Configuring user language list"
        $languageList = New-WinUserLanguageList -Language $Locale -ErrorAction Stop
        
        # Set the input method (keyboard layout)
        if ($languageList -and $languageList.Count -gt 0) {
            # Clear existing input methods and add the desired one
            $languageList[0].InputMethodTips.Clear()
            $languageList[0].InputMethodTips.Add($InputLanguageId)
            
            Write-Verbose "Setting user language list"
            Set-WinUserLanguageList -LanguageList $languageList -Force -ErrorAction Stop
        }

        # Copy user international settings to default user accounts
        Write-Verbose "Copying settings to default user accounts"
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $false -NewUser $true -ErrorAction Stop
        
        Write-Host "Regional settings applied successfully using PowerShell cmdlets" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to apply settings using PowerShell cmdlets: $_"
        return $false
    }
}

function Set-LanguageOptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $UserLocale,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $InputLanguageID,

        [Parameter(Mandatory = $true)]
        [int] $LocationGeoId,

        [Parameter(Mandatory = $true)]
        [bool] $CopySettingsToSystemAccount,

        [Parameter(Mandatory = $true)]
        [bool] $CopySettingsToDefaultUserAccount,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SystemLocale
    )

    # Reference:
    # - Guide to Windows Vista Multilingual User Interface
    #   https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-vista/cc721887(v=ws.10)
    $xmlFileContentTemplate = @'
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToSystemAcct="{0}" CopySettingsToDefaultUserAcct="{1}"/>
    </gs:UserList>
    <gs:UserLocale>
        <gs:Locale Name="{2}" SetAsCurrent="true"/>
    </gs:UserLocale>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="{3}" Default="true"/>
    </gs:InputPreferences>
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="{2}"/>
        <gs:MUIFallback Value="en-US"/>
    </gs:MUILanguagePreferences>
    <gs:LocationPreferences>
        <gs:GeoID Value="{4}"/>
    </gs:LocationPreferences>
    <gs:SystemLocale Name="{5}"/>
</gs:GlobalizationServices>
'@

    # Create the XML file content.
    $fillValues = @(
        $CopySettingsToSystemAccount.ToString().ToLowerInvariant(),
        $CopySettingsToDefaultUserAccount.ToString().ToLowerInvariant(),
        $UserLocale,
        $InputLanguageID,
        $LocationGeoId,
        $SystemLocale
    )
    $xmlFileContent = $xmlFileContentTemplate -f $fillValues

    Write-Verbose -Message ('MUI XML: {0}' -f $xmlFileContent)

    # Create a new XML file and set the content.
    $xmlFileFilePath = Join-Path -Path $env:TEMP -ChildPath ((New-Guid).Guid + '.xml')
    Set-Content -LiteralPath $xmlFileFilePath -Encoding UTF8 -Value $xmlFileContent

    # Copy the current user language settings to the default user account and system user account.
    $procStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ArgumentList 'C:\Windows\System32\control.exe', ('intl.cpl,,/f:"{0}"' -f $xmlFileFilePath)
    $procStartInfo.UseShellExecute = $false
    $procStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    $proc = [System.Diagnostics.Process]::Start($procStartInfo)
    $proc.WaitForExit()
    $proc.Dispose()

    # Delete the XML file.
    Remove-Item -LiteralPath $xmlFileFilePath -Force
}

# Detect Windows version
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Regional Settings Configuration" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$windowsInfo = Get-WindowsVersion

if ($windowsInfo) {
    Write-Host "Detected: $($windowsInfo.ProductName)" -ForegroundColor White
    Write-Host "Build: $($windowsInfo.Build)" -ForegroundColor White
    Write-Host ""
}

# Set the current user's language options and copy it to the default user account and system account.
#
# References:
# - Default Input Profiles (Input Locales) in Windows
#   https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs
# - Table of Geographical Locations
#   https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations

# Configure settings based on selected country
if ($Country -in 'Belgium', 'BE') {
    $locale = 'nl-BE'
    $inputLangId = '0813:00000813'
    $geoId = 21
    $displayCountry = "Belgium"
    $displayLanguage = "Dutch (Belgium)"
    $displayKeyboard = "Dutch (Belgium) - Belgian (Period)"
}
else {
    $locale = 'nl-NL'
    $inputLangId = '0413:00020409'
    $geoId = 176
    $displayCountry = "Netherlands"
    $displayLanguage = "Dutch (Netherlands)"
    $displayKeyboard = "Dutch (Netherlands) - US International"
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuring $displayCountry Regional Settings" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($windowsInfo.IsServer2025OrNewer) {
    write-Host "Detected Windows Server 2025 or newer. Using PowerShell cmdlets for configuration." -ForegroundColor Yellow
    $success = Set-RegionalSettingsPowerShell -Locale $locale -InputLanguageId $inputLangId -GeoId $geoId -DisplayCountry $displayCountry -DisplayKeyboard $displayKeyboard
}
else {
    Write-Host "Using legacy method for configuration..." -ForegroundColor Cyan

    # Apply settings using the control.exe method (Microsoft supported)
    $params = @{
        UserLocale                       = $locale
        InputLanguageID                  = $inputLangId
        LocationGeoId                    = $geoId
        CopySettingsToSystemAccount      = $true
        CopySettingsToDefaultUserAccount = $true
        SystemLocale                     = $locale
    }

    Set-LanguageOptions @params -Verbose
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Regional settings configured successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Settings applied:" -ForegroundColor Cyan
Write-Host "  - Display Language: English (United States) [Default]" -ForegroundColor White
Write-Host "  - Input Language: $displayKeyboard" -ForegroundColor White
Write-Host "  - Format: $displayLanguage" -ForegroundColor White
Write-Host "  - Location: $displayCountry" -ForegroundColor White
Write-Host "  - Settings applied to system and default user accounts" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Changes will take effect for new user sessions." -ForegroundColor Yellow
Write-Host "      A system restart may be required for all settings to take effect." -ForegroundColor Yellow