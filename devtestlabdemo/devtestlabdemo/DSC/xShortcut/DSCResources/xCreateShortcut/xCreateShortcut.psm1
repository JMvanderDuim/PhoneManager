function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $ShortCutName
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."


    $ShortcutExists = Test-Path -path $ShortCutName 
    
    
    $returnValue = @{
        ShortCutName = $ShortCutName
    }

    $returnValue

}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $ShortCutName,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $Executable,

        [System.String]
        $Description,

        [System.String]
        $IconLocation
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1

    #$ShortCutName="C:\Users\Public\Desktop\Logoff.lnk"
    #$Executable="C:\Windows\System32\Logoff.exe"
    if ($Ensure -eq "Present"){
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortCutName)
        $Shortcut.TargetPath = $Executable
        $Shortcut.Description=$Description
        $Shortcut.IconLocation=$IconLocation
        $Shortcut.Save()
    }

    if ($Ensure -eq "Absent"){
        if (Test-Path -Path $ShortCutName){
            Remove-Item $ShortCutName
        }
    }


}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $ShortCutName,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $Executable,

        [System.String]
        $Description,

        [System.String]
        $IconLocation
    )

    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."

    if (Test-Path -Path $ShortCutName){
        return $true 
    }
    else {
        return $false
    }


    <#
    $result = [System.Boolean]
    
    $result
    #>
}


Export-ModuleMember -Function *-TargetResource

