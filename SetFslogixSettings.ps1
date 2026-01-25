#Set fslogix settings via registry
param(
    [Parameter(Mandatory = $true)]
    [string] $FslogixFileShare,
    
    # If there is no SSO (Single Sign-On), RoamIdentity should be set to $true to enable credential roaming
    [Parameter(Mandatory = $false)]
    [bool] $RoamIdentity = $false,
    
    [Parameter(Mandatory = $false)]
    [bool] $RoamRecycleBin = $true
)

function New-Log {
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path
    )
    
    $date = Get-Date -UFormat "%Y-%m-%d %H-%M-%S"
    Set-Variable logFile -Scope Script
    $script:logFile = "$Script:Name-$date.log"
    
    if ((Test-Path $path ) -eq $false) {
        $null = New-Item -Path $path -ItemType directory
    }
    
    $script:Log = Join-Path $path $logfile
    
    Add-Content $script:Log "Date`t`t`tCategory`t`tDetails"
}

function Write-Log {
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet("Info", "Warning", "Error")]
        $Category = 'Info',
        [Parameter(Mandatory = $true, Position = 1)]
        $Message
    )
    
    $Date = get-date
    $Content = "[$Date]`t$Category`t`t$Message`n" 
    Add-Content $Script:Log $content -ErrorAction Stop
    If ($Verbose) {
        Write-Verbose $Content
    }
    Else {
        Switch ($Category) {
            'Info' { Write-Host $content }
            'Error' { Write-Error $Content }
            'Warning' { Write-Warning $Content }
        }
    }
}

function Get-WebFile {
    param(
        [parameter(Mandatory)]
        [string]$FileName,

        [parameter(Mandatory)]
        [string]$URL
    )
    $Counter = 0
    do {
        Invoke-WebRequest -Uri $URL -OutFile $FileName -ErrorAction 'SilentlyContinue'
        if ($Counter -gt 0) {
            Start-Sleep -Seconds 30
        }
        $Counter++
    }
    until((Test-Path $FileName) -or $Counter -eq 9)
}

Function Set-RegistryValue {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name,
        [Parameter()]
        [string]
        $Path,
        [Parameter()]
        [string]$PropertyType,
        [Parameter()]
        $Value
    )
    Begin {
        Write-Log -message "[Set-RegistryValue]: Setting Registry Value: $Name"
    }
    Process {
        # Create the registry Key(s) if necessary.
        If (!(Test-Path -Path $Path)) {
            Write-Log -message "[Set-RegistryValue]: Creating Registry Key: $Path"
            New-Item -Path $Path -Force | Out-Null
        }
        # Check for existing registry setting
        $RemoteValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        If ($RemoteValue) {
            # Get current Value
            $CurrentValue = Get-ItemPropertyValue -Path $Path -Name $Name
            Write-Log -message "[Set-RegistryValue]: Current Value of $($Path)\$($Name) : $CurrentValue"
            If ($Value -ne $CurrentValue) {
                Write-Log -message "[Set-RegistryValue]: Setting Value of $($Path)\$($Name) : $Value"
                Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force | Out-Null
            }
            Else {
                Write-Log -message "[Set-RegistryValue]: Value of $($Path)\$($Name) is already set to $Value"
            }           
        }
        Else {
            Write-Log -message "[Set-RegistryValue]: Setting Value of $($Path)\$($Name) : $Value"
            New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value -Force | Out-Null
        }
        Start-Sleep -Milliseconds 500
    }
    End {
    }
}

$ErrorActionPreference = 'Stop'
$Script:Name = 'set-fslogix-settings'
New-Log -Path (Join-Path -Path $env:SystemRoot -ChildPath 'Logs')

##############################################################
#  Add Fslogix Settings
##############################################################
$Settings = @(
        # Enables Fslogix profile containers: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#enabled
        [PSCustomObject]@{
            Name         = 'Enabled'
            Path         = 'HKLM:\SOFTWARE\Fslogix\Profiles'
            PropertyType = 'DWord'
            Value        = 1
        },
        # Deletes a local profile if it exists and matches the profile being loaded from VHD: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#deletelocalprofilewhenvhdshouldapply
        [PSCustomObject]@{
            Name         = 'DeleteLocalProfileWhenVHDShouldApply'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 1
        },
        # The folder created in the Fslogix fileshare will begin with the username instead of the SID: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#flipflopprofiledirectoryname
        [PSCustomObject]@{
            Name         = 'FlipFlopProfileDirectoryName'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 1
        },
        # Loads FRXShell if there's a failure attaching to, or using an existing profile VHD(X): https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#preventloginwithfailure
        [PSCustomObject]@{
            Name         = 'PreventLoginWithFailure'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 1
        },
        # Loads FRXShell if it's determined a temp profile has been created: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#preventloginwithtempprofile
        [PSCustomObject]@{
            Name         = 'PreventLoginWithTempProfile'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 1
        },
        # List of file system locations to search for the user's profile VHD(X) file: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#vhdlocations
        [PSCustomObject]@{
            Name         = 'VHDLocations'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'MultiString'
            Value        = $FslogixFileShare
        },
        [PSCustomObject]@{
            Name         = 'VolumeType'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'MultiString'
            Value        = 'vhdx'
        },
        [PSCustomObject]@{
            Name         = 'RemoveOrphanedOSTFilesOnLogoff'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 1
        },
        [PSCustomObject]@{
            Name         = 'LogFileKeepingPeriod'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Logging'
            PropertyType = 'DWord'
            Value        = 7
        }
        [PSCustomObject]@{
            Name         = 'LockedRetryCount'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 3
        },
        [PSCustomObject]@{
            Name         = 'LockedRetryInterval'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 15
        },
        [PSCustomObject]@{
            Name         = 'ReAttachIntervalSeconds'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 15
        },
        [PSCustomObject]@{
            Name         = 'ReAttachRetryCount'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
            PropertyType = 'DWord'
            Value        = 3
        },
        [PSCustomObject]@{
            Name         = 'RoamRecycleBin'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Apps'
            PropertyType = 'DWord'
            Value        = [int]$RoamRecycleBin
        },
        [PSCustomObject]@{
            Name         = 'RoamIdentity'
            Path         = 'HKLM:\SOFTWARE\FSLogix\Apps'
            PropertyType = 'DWord'
            Value        = [int]$RoamIdentity
        }
    )

# Apply Fslogix Settings
foreach ($Setting in $Settings) {
    Set-RegistryValue -Name $Setting.Name -Path $Setting.Path -PropertyType $Setting.PropertyType -Value $Setting.Value -Verbose
}