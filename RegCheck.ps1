
# PowerShell script to check the type of 'LowerFilters' and 'UpperFilters' in each subkey of a given registry path
# Function to check each subkey for 'LowerFilters', 'UpperFilters' and display its type

param(
    [String]$RegistryPath="HKLM:\SYSTEM\CurrentControlSet\Control\Class\",
    # Example: HKLM:\SYSTEM\CurrentControlSet\Control\Class\
    [String]$Out="RegistryDump.reg",
    [switch]$F=$false,
    [switch]$DumpOnly=$false
)

function Check-FilterType {
    param(
        [Parameter(Mandatory=$true)]
        $Filter,
        # Example: System.Management.Automation.PSObject
        [Parameter(Mandatory=$true)]
        [String]$Name,
        # Example: LowerFilters, UpperFilters
        [Parameter(Mandatory=$true)]
        [Bool]$Fix
    )

    if ( $Filter.$Name -isnot [System.Array] ){
        # Shorten PSPath from HKEY_LOCAL_MACHINE to HKLM: format
        $regPath = $Filter.PSPath.Split("::")[2].Replace('HKEY_LOCAL_MACHINE', 'HKLM:')
        Write-Host "[-] ERROR : $regPath [$Name] [REG_SZ] : " $Filter.$Name

        if ($Fix){
            Change-FilterType -Filter $Filter -Name $Name
        }
    }   
}


function Change-FilterType {
    param(
        [Parameter(Mandatory=$true)]
        $Filter,
        #Example: System.Management.Automation.PSObject
        [Parameter(Mandatory=$true)]
        [String]$Name
        # Example: LowerFilters, UpperFilters
    )
    
    $regValue = [System.String[]]($Filter.$Name)

    try {
        # Remove Registry with Invalid TYPE
        Remove-ItemProperty -Path $Filter.PSPath -Name $Name -ErrorAction Stop
        # Recreate the Registry with correct TYPE
        Set-ItemProperty -Path $Filter.PSPath -Name $Name -Value $regValue -ErrorAction Stop
    } catch {
        Write-Host "[-] ERROR : $_"
    }

}


function Check-FilterNullValues {
    param(
        [Parameter(Mandatory=$true)]
        $Filter,
        # Example: System.Management.Automation.PSObject
        [Parameter(Mandatory=$true)]
        [String]$Name,
        # Example: LowerFilters
        [Parameter(Mandatory=$true)]
        [Bool]$Fix
    )
    
    if ($Filter.$Name -is [System.Array]){
        $tracker = $false
        foreach ($item in $Filter.$Name){
            if ($item -eq "`0"){
                $tracker = $True
            }
        }
        
        if ($tracker){
            # Write Findings into the STDOUT
            $regPath = $Filter.PSPath.Split("::")[2].Replace('HKEY_LOCAL_MACHINE', 'HKLM:')
            Write-Host "[-] ERROR : $regPath [$Name] [NULL BYTES]"
            $Filter
            if ($Fix){
                Remove-NullValuesFromREG_MULTI -Filter $Filter -Name $Name
            }
        }
    }
}


function Remove-NullValuesFromREG_MULTI {
    param(
        [Parameter(Mandatory=$true)]
        $Filter,
        #Example: System.Management.Automation.PSObject
        [Parameter(Mandatory=$true)]
        [String]$Name
        # Example: LowerFilters, UpperFilters
    )

    Write-Host $Filter
    $regValue = @()

    # Removing NULL BYTES
    if ($Filter.$Name -is [System.Array]){
        foreach ($item in $Filter.$Name){
            if ($item -ne "`0"){
                $regValue += $item
            }
        }
    }
    try {
        # Modify Registry Values without NULL BYTES
        Set-ItemProperty -Path $Filter.PSPath -Name $Name -Value $regValue -ErrorAction Stop
    } catch {
        Write-Host "[-] ERROR : $_"
    }
}


function Get-FilterTypes {
    param (
        [Parameter(Mandatory=$true)]
        [string]$RegistryPath,
        # Example: HKLM:\SYSTEM\CurrentControlSet\Control\Class\
        [Parameter(Mandatory=$true)]
        [Bool]$Fix
    )

    try {

        # Get all subkeys under the given registry path
        $subKeys = Get-ChildItem -Path $RegistryPath

        # Loop through each subkey
        foreach ($subKey in $subKeys) {
            $subKeyPath = $subKey.PSPath

            # Check if 'LowerFilters' exists in the current subkey
            $lowerFilters = Get-ItemProperty -Path $subKeyPath -Name 'LowerFilters' -ErrorAction SilentlyContinue
            if ($lowerFilters) {
                Check-FilterType -Filter $lowerFilters -Name "LowerFilters" -Fix $Fix
                Check-FilterNullValues -Filter $lowerFilters -Name "LowerFilters" -Fix $Fix
            }

            # Check if 'UpperFilters' exists in the current subkey
            $upperFilters = Get-ItemProperty -Path $subKeyPath -Name 'UpperFilters' -ErrorAction SilentlyContinue
            if ($upperFilters) {
                Check-FilterType -Filter $upperFilters -Name "UpperFilters" -Fix $Fix
                Check-FilterNullValues -Filter $upperFilters -Name "UpperFilters" -Fix $Fix
            }
        }
    } catch {
        Write-Host "[-] ERROR : $_"
    }
}


# Convert Powershell Registry path into CMD format
function Convert-RegPathtoCMD(){
    param(
        [Parameter(Mandatory=$true)]
        [string]$RegistryPath
    )
    $regPath = $RegistryPath.Replace(':', '')
    return $regPath
}


# Export Registry
function Export-Registry(){
    param (
        [Parameter(Mandatory=$true)]
        [string]$RegistryPath,
        # Example: HKLM:\SYSTEM\CurrentControlSet\Control\Class\
        [Parameter(Mandatory=$true)]
        [string]$Out
    )

     $RegistryPath = Convert-RegPathtoCMD -RegistryPath $RegistryPath 

    # Export the registry branch
    reg.exe export $RegistryPath $Out /y > $null 2>&1

    Write-Host "[+] Registry Dumped : $Out"
}


# Check Registry Path
if (Test-Path -Path $RegistryPath){
    if ($F){
        Export-Registry -RegistryPath $RegistryPath -Out $Out
    }
    If ($DumpOnly){
        Export-Registry -RegistryPath $RegistryPath -Out $Out
    }
    else {
        Get-FilterTypes -RegistryPath $RegistryPath -Fix $F
    }
}
else{
    Write-Host "[-] ERROR : Invalid RegistryPath"
}