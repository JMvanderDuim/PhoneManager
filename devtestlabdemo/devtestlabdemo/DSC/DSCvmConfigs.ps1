#
# Domain Controller
#

configuration DomainController 
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xAdcsDeployment
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xSmbShare
    Import-DscResource -ModuleName xStorage
    Import-DscResource -ModuleName xShortcut

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InteraceAlias=$($Interface.Name)

    Node localhost
    {
        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
        }
		xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InteraceAlias
            AddressFamily  = 'IPv4'
        }
        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }
        xDisk ADDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }
        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
        }  
        xADDomain FirstDS 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            #DatabasePath = "F:\NTDS"
            #LogPath = "F:\NTDS"
            #SysvolPath = "F:\SYSVOL"
            DependsOn = '[xDisk]ADDataDisk'
        }
        WindowsFeature ADCS-Cert-Authority
        {
               Ensure = 'Present'
               Name = 'ADCS-Cert-Authority'
			   DependsOn = '[xADDomain]FirstDS'
        }
		WindowsFeature RSAT-ADCS-Mgmt
        {
               Ensure = 'Present'
               Name = 'RSAT-ADCS-Mgmt'
			   DependsOn = '[xADDomain]FirstDS'
        }
        WindowsFeature RSAT-ADDS
        {
               Ensure = 'Present'
               Name = 'RSAT-ADDS'
               DependsOn = '[xADDomain]FirstDS'
        }
        WindowsFeature RSAT-DNS-Server
        {
               Ensure = 'Present'
               Name = 'RSAT-DNS-Server'
               DependsOn = '[xADDomain]FirstDS'
        }
        File SrcFolder
        {
            DestinationPath = "C:\src"
            Type = "Directory"
            Ensure = "Present"
            DependsOn = "[xADDomain]FirstDS"
        }
        xSmbShare SrcShare
        {
            Ensure = "Present"
			Name = "src"
            Path = "C:\src"
            FullAccess = @("Domain Admins","Domain Computers")
			ReadAccess = "Authenticated Users"
            DependsOn = "[File]SrcFolder"
		}
		xADCSCertificationAuthority ADCS
        {
            Ensure = 'Present'
            Credential = $DomainCreds
            CAType = 'EnterpriseRootCA'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority'              
        }
        WindowsFeature ADCS-Web-Enrollment
        {
            Ensure = 'Present'
            Name = 'ADCS-Web-Enrollment'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority'
        }
        xADCSWebEnrollment CertSrv
        {
            Ensure = 'Present'
            Name = 'CertSrv'
            Credential = $DomainCreds
            DependsOn = '[WindowsFeature]ADCS-Web-Enrollment','[xADCSCertificationAuthority]ADCS'
        } 
        xCreateShortcut Logoff 
        {
            Ensure = "Present"
            ShortCutName = "C:\Users\Public\Desktop\Logoff.lnk"
            Executable = "C:\Windows\System32\Logoff.exe"
            Description = "Logoff from Windows"
            IconLocation = "%SystemRoot%\system32\SHELL32.dll,44"
        }
		 
        LocalConfigurationManager 
        {
		    DebugMode = 'All'
            RebootNodeIfNeeded = $true
        }
   }
} 

#
# SQL Server
#

configuration SQLserver
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=40,
        [Int]$RetryIntervalSec=60
    )

    Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xStorage
    Import-DscResource -ModuleName xShortcut

    Node localhost
    {
        #WindowsFeature ADFSInstall 
        #{ 
        #    Ensure = "Present" 
        #    Name = "ADFS-Federation"
        #}  
        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"

        } 
       xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }
        xDisk DataDisk2
        {
            DiskNumber = 2
            DriveLetter = "F"
        }
       xWaitforDisk Disk3
        {
             DiskNumber = 3
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }
        xDisk DataDisk3
        {
            DiskNumber = 3
            DriveLetter = "G"
        }
		xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $Admincreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec 
            DependsOn = "[WindowsFeature]ADPS"      
        }
		xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
			DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        xCreateShortcut Logoff 
        {
            Ensure = "Present"
            ShortCutName = "C:\Users\Public\Desktop\Logoff.lnk"
            Executable = "C:\Windows\System32\Logoff.exe"
            Description = "Logoff from Windows"
            IconLocation = "%SystemRoot%\system32\SHELL32.dll,44"
        }

        LocalConfigurationManager 
        {
		    DebugMode = 'All'
            RebootNodeIfNeeded = $true
        }
    }     
}

<#
# WAP Server
#

configuration DIRserver
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xActiveDirectory
    
    Node localhost
    {
        #WindowsFeature WAPInstall 
        #{ 
        #    Ensure = "Present" 
        #    Name = "Web-Application-Proxy"
        #}  
        #WindowsFeature WAPMgmt 
        #{ 
        #    Ensure = "Present" 
        #    Name = "RSAT-RemoteAccess"
        #}  
        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        } 
		xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $Admincreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec 
            DependsOn = "[WindowsFeature]ADPS"      
        }
		xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
			DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        LocalConfigurationManager 
        {
		    DebugMode = 'All'
            RebootNodeIfNeeded = $true
        }
    }     
}
#>

configuration WEBServer
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xStorage
    Import-DscResource -ModuleName xShortcut
    
    Node localhost
    {
        #WindowsFeature WAPInstall 
        #{ 
        #    Ensure = "Present" 
        #    Name = "Web-Application-Proxy"
        #}  
        #WindowsFeature WAPMgmt 
        #{ 
        #    Ensure = "Present" 
        #    Name = "RSAT-RemoteAccess"
        #}  
        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        } 
        
        WindowsFeature IIS
        {
            Name = "Web-Server"
            Ensure = "Present"
        }
        
        WindowsFeature IISMGT
        {
            Name = "Web-Mgmt-Tools"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]IIS"
        }
        
        WindowsFeature IISMGTConsole
        {
            Name = "Web-Mgmt-Console"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]IIS"
        }
        
		xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $Admincreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec 
            DependsOn = "[WindowsFeature]ADPS"      
        }
		xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
			DependsOn = "[xWaitForADDomain]DscForestWait"
        }
        xCreateShortcut Logoff 
        {
            Ensure = "Present"
            ShortCutName = "C:\Users\Public\Desktop\Logoff.lnk"
            Executable = "C:\Windows\System32\Logoff.exe"
            Description = "Logoff from Windows"
            IconLocation = "%SystemRoot%\system32\SHELL32.dll,44"
        }

        LocalConfigurationManager 
        {
		    DebugMode = 'All'
            RebootNodeIfNeeded = $true
        }
    }     
}

configuration DIRServer
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xStorage
    Import-DscResource -ModuleName xShortcut
    
    Node localhost
    {
        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        } 
        
        WindowsFeature IIS
        {
            Name = "Web-Server"
            Ensure = "Present"
        }
        
        WindowsFeature IISMGT
        {
            Name = "Web-Mgmt-Tools"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]IIS"
        }
        
        WindowsFeature IISMGTConsole
        {
            Name = "Web-Mgmt-Console"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]IIS"
        }
        
		xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $Admincreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec 
            DependsOn = "[WindowsFeature]ADPS"      
        }
		xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
			DependsOn = "[xWaitForADDomain]DscForestWait"
        }
        xCreateShortcut Logoff 
        {
            Ensure = "Present"
            ShortCutName = "C:\Users\Public\Desktop\Logoff.lnk"
            Executable = "C:\Windows\System32\Logoff.exe"
            Description = "Logoff from Windows"
            IconLocation = "%SystemRoot%\system32\SHELL32.dll,44"
        }

        LocalConfigurationManager 
        {
		    DebugMode = 'All'
            RebootNodeIfNeeded = $true
        }
    }     
}

configuration DomainJoin
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xComputerManagement
	Import-DscResource -ModuleName xActiveDirectory
    
    Node localhost
    {
	    WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"

        } 
		xWaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            DomainUserCredential= $Admincreds
            RetryCount = $RetryCount 
            RetryIntervalSec = $RetryIntervalSec 
            DependsOn = "[WindowsFeature]ADPS"      
        }
		xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
			DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        LocalConfigurationManager 
        {
            DebugMode = 'All'    
            RebootNodeIfNeeded = $true
        }
    }     
}

function WaitForSqlSetup
{
    # Wait for SQL Server Setup to finish before proceeding.
    while ($true)
    {
        try
        {
            Get-ScheduledTaskInfo "\ConfigureSqlImageTasks\RunConfigureImage" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch
        {
            break
        }
    }
}

function Get-NetBIOSName
{ 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}



