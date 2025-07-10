#Set server regional settings to Belgian
function Set-RegionalSettings {
    param(
        [string]$UserLocale = "nl-BE",           # English (Belgium) regional format
        [string]$SystemLocale = "nl-BE",         # Dutch (Belgium) system locale
        [string]$InputLanguageID = "0813:00000813", # Dutch (Belgium) input
        [string]$LocationGeoId = "21",           # Belgium
        [bool]$CopySettingsToSystemAccount = $false,      # Don't copy to system
        [bool]$CopySettingsToDefaultUserAccount = $true   # Copy to new users only
    )

    # XML template for regional settings
    $xmlFileContentTemplate = @'
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToDefaultUserAcct="{1}" CopySettingsToSystemAcct="{0}"/>
    </gs:UserList>
    <gs:UserLocale>
        <gs:Locale Name="{2}" SetAsCurrent="true" ResetAllSettings="true"/>
    </gs:UserLocale>
    <gs:InputPreferences>
        <gs:InputLanguageID Action="add" ID="{3}" Default="true"/>
    </gs:InputPreferences>
    <gs:LocationPreferences>
        <gs:GeoID Value="{4}"/>
    </gs:LocationPreferences>
    <gs:SystemLocale Name="{5}"/>
</gs:GlobalizationServices>
'@

    # Create the XML file content with proper formatting
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
    
    # Create a temporary XML file
    $xmlFileFilePath = Join-Path -Path $env:TEMP -ChildPath ((New-Guid).Guid + '.xml')
    
    try {
        # Write XML content to file
        Set-Content -LiteralPath $xmlFileFilePath -Encoding UTF8 -Value $xmlFileContent
        
        Write-Output "Applying Belgian regional settings (English format) for new users..."
        
        # Apply settings using control.exe
        $procStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ArgumentList 'C:\Windows\System32\control.exe', ('intl.cpl,,/f:"{0}"' -f $xmlFileFilePath)
        $procStartInfo.UseShellExecute = $false
        $procStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
        #$procStartInfo.CreateNoWindow = $true
        
        $proc = [System.Diagnostics.Process]::Start($procStartInfo)
        $proc.WaitForExit()
                
        Write-Output "Regional settings applied successfully."
        
        $proc.Dispose()
        
    } catch {
        Write-Error "Error applying regional settings: $($_.Exception.Message)"
    } finally {
        # Clean up temporary XML file
        if (Test-Path -Path $xmlFileFilePath) {
            Remove-Item -LiteralPath $xmlFileFilePath -Force
        }
    }
}

# Set timezone
Set-TimeZone -Id "Romance Standard Time" -PassThru

# Apply Belgian settings with English regional format for new users only
Set-RegionalSettings -UserLocale "nl-BE" -SystemLocale "nl-BE" -InputLanguageID "0813:00000813" -LocationGeoId "21" -CopySettingsToSystemAccount $false -CopySettingsToDefaultUserAccount $true

Write-Output "A restart is recommended for all language changes to take effect."