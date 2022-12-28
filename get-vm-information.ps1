<#

.SYNOPSIS
    This script get information about Virtual Machines on all subscriptions the user can access and store then into CSV report file.

.DESCRIPTION
    The information Get :   
        - Global information about Virtual Machines (Name, Resource Group, Sku...)
        - Network Information
        - Disks Information
.NOTES
    Additional Notes, eg
    File Name  : get-vm-information.ps1
    Author     : Stephane Vallier
    E-mail     : stephane.vallier@cosmosp.fr

.EXAMPLE
    get-vm-information.ps1 -ExportFolder c:\ -NetworkInformation $true -DisksInformation $true $TimeDepthInDays 30
#>


Param (
    [Parameter(mandatory, HelpMessage = 'The path where to export the report into')]
    [string] $ExportFolder,
    [Parameter(mandatory, HelpMessage = 'Get Network information ? Y/n')]
    [bool] $NetworkInformation,
    [Parameter(mandatory, HelpMessage = 'Get Disks information ? Y/n')]
    [bool] $DisksInformation,
    [Parameter(mandatory, HelpMessage = 'Time depth in days')]
    [int] $TimeDepthInDays
)



#################################################################################################
### Preparation
## Configuration
# Name of the report
$reportName = "myReport-" + $TimeDepthInDays + "Days.csv"

# Metrics depyh configuration
$EndDate = Get-Date
$StartDate = $EndDate.AddDays(-$TimeDepthInDays)

# Folder creation if not exist
New-Item $ExportFolder -ItemType Directory -ErrorAction Ignore

## Functions
function Sva-InstallModule {
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Module,
        [Parameter(Mandatory = $false)]
        [string] $Version
    )

    # Install Module
    Write-Output "`n### Module $Module ###"

    # Enforce TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Set repository 
    $PSRepository = Get-PSRepository -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($PSRepository) -eq $True) {
        Register-PSRepository -Default -InstallationPolicy Trusted
    }
    elseif ($PSRepository.InstallationPolicy -ne "Trusted") {
        Set-PSRepository -InstallationPolicy Trusted -Name PSGallery
    }
    
    # Az.Accounts must be latest
    if ($Module -eq "Az.Accounts") { 
        $Version = $Null
    }

    # Find module information
    $GalleryUri = "https://www.powershellgallery.com/api/v2"
    if ($Version) {
        $FindModule=(Invoke-RestMethod "$GalleryUri/FindPackagesById()?id='$Module'" | Where-Object {$_.properties.version -eq $Version})
        $Dependencies = $FindModule.properties.Dependencies
    }
    elseif (!($Version)) {
        $FindModule=(Invoke-RestMethod "$GalleryUri/FindPackagesById()?id='$Module'" | Where-Object {$_.properties.version -notlike '*preview' -and $_.properties.version -notlike '*beta*' } | select -Last 1)   
        $Version = $FindModule.properties.Version
        $Dependencies = $FindModule.properties.Dependencies 
    }


    # Check if module already installed
    $ModuleAlreadyInstalled = Get-InstalledModule -Name $Module -RequiredVersion $Version -ErrorAction SilentlyContinue
    if ($ModuleAlreadyInstalled) {
    Write-Output "Module $Module on version $Version is already installed"
        try {
            foreach ($Dependency in $Dependencies) {
                if ([string]::IsNullOrEmpty($Dependency) -eq $false) {
                    # Ensure that minimum Version of dependencies are assured
                    $DependencyName = $Dependency.Split(":")[0]
                    $DependencyMinimalVersion = ($Dependency.Split("[")[1]).Split(",")[0]
                    $DependencyCurrentVersion = (Get-Module -Name $DependencyName).Version
                    
                    if (([System.Version]$DependencyCurrentVersion -lt [System.Version]$DependencyMinimalVersion) -or ([string]::IsNullOrEmpty($DependencyMinimalVersion) -eq $True)) {
                        Write-Output "Module $Module require dependent Module $DependencyName on the minimum version $DependencyMinimalVersion. Installing.."
                        $DependendentModuleAlreadyInstalled = Get-InstalledModule -Name $DependencyName -MinimumVersion $DependencyMinimalVersion -ErrorAction SilentlyContinue
                        if (!($DependendentModuleAlreadyInstalled)) {
                            Install-Module -Name $DependencyName -MinimumVersion $DependencyMinimalVersion -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force
                        }
                        Get-Module -Name $DependencyName | Remove-Module -Force
                        $LoadedModule = (Import-Module $DependencyName -Global -MinimumVersion $DependencyMinimalVersion -PassThru)
                        Write-Output "Dependent Module $DependencyName loaded on version $($LoadedModule.Version)"      
                    }
                }
            }
            # Unload all existing versions then load the right one
            Write-Output "Load Module $Module version $Version"
            Get-Module -Name $Module | Remove-Module -Force
            $LoadedModule = (Import-Module $Module -Global -RequiredVersion $Version -PassThru)
        }
        catch {
            Write-Error "Error : " $error[0]
            Write-Error "Message : " $error[0].Exception.Message
            Write-Error "Cannot install $Module" -Errors
        }
    }
    elseif (!($ModuleAlreadyInstalled)) {
    Write-Output "Installing Module $Module on version $Version"
        try {
            foreach ($Dependency in $Dependencies) {
                if ([string]::IsNullOrEmpty($Dependency) -eq $false) {
                    # Ensure that minimum Version of dependencies are assured
                    $DependencyName = $Dependency.Split(":")[0]
                    $DependencyMinimalVersion = ($Dependency.Split("[")[1]).Split(",")[0]
                    $DependencyCurrentVersion = (Get-Module -Name $DependencyName).Version
                    
                    if (([System.Version]$DependencyCurrentVersion -lt [System.Version]$DependencyMinimalVersion) -or ([string]::IsNullOrEmpty($DependencyMinimalVersion) -eq $True)) {
                        Write-Output "Module $Module require dependent Module $DependencyName on the minimum version $DependencyMinimalVersion. Installing.."
                        $DependendentModuleAlreadyInstalled = Get-InstalledModule -Name $DependencyName -MinimumVersion $DependencyMinimalVersion -ErrorAction SilentlyContinue
                        if (!($DependendentModuleAlreadyInstalled)) {
                            Install-Module -Name $DependencyName -MinimumVersion $DependencyMinimalVersion -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force
                        }
                        Get-Module -Name $DependencyName | Remove-Module -Force
                        $LoadedModule = (Import-Module $DependencyName -Global -MinimumVersion $DependencyMinimalVersion -PassThru)
                        Write-Output "Dependent Module $DependencyName loaded on version $($LoadedModule.Version)"      
                    }
                }
            }
            # Install Module
            Install-Module -Name $Module -RequiredVersion $Version -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force -WarningAction SilentlyContinue
            # Unload all existing versions then load the right one
            Write-Output "Load Module $Module version $Version"
            Get-Module -Name $Module | Remove-Module -Force
            $LoadedModule = (Import-Module $Module -Global -RequiredVersion $Version -PassThru)
        }
        catch {
            Write-Error "Error : " $error[0]
            Write-Error "Message : " $error[0].Exception.Message
            Write-Error "Cannot install $Module. An Other old assembly is already loaded. Please restart your powershell session then try again" -Errors
        }
    }
    Write-Output "Module $Module installed & loaded on version $($LoadedModule.Version)"
} 


## Install necessary modules
#Sva-InstallModule -Module Az.Resources
#Sva-InstallModule -Module Az.Monitor



#################################################################################################
### Authentication
# Sign into Azure Portal if not already signed
$context = Get-AzContext

if ([string]::IsNullOrEmpty($context)) {
    Connect-AzAccount
}

# Fetching all subscriptions 
$subscriptionList = Get-AzSubscription



#################################################################################################
### Things get serious
# Fetching the IaaS inventory list for each subscription
foreach($subscription in $subscriptionList){
    Select-AzSubscription -SubscriptionId $subscription.Id
    
    if ($subscription.Name -eq "SDX Sandbox") {
        $VirtualMachines = Get-AzResource -ResourceType Microsoft.Compute/virtualMachines #-Name "Ivanti-clt1"
        
        ## VM Region
        foreach($VirtualMachine in $VirtualMachines){
            Write-Output "Digging $($VirtualMachine.Name)"

            # Init array
            $Report=@()
            $infos = "" | Select-Object VmName, ResourceGroupName, Region, VmSize, Os, Version
            # Insert datas
            $VirtualMachineDetails = Get-AzVm -ResourceGroupName $VirtualMachine.ResourceGroupName -Name $VirtualMachine.Name
            $infos.VMName = $VirtualMachineDetails.Name 
            $infos.ResourceGroupName = $VirtualMachineDetails.ResourceGroupName 
            $infos.Region = $VirtualMachineDetails.Location 
            $infos.VmSize = $VirtualMachineDetails.HardwareProfile.VmSize
            $infos.Os = $VirtualMachineDetails.StorageProfile.OsDisk.OsType
            $infos.Version = $VirtualMachineDetails.StorageProfile.ImageReference.Sku

            ## Network Region
            if ($NetworkInformation -eq $true) {
                # Add columns to array
                Add-Member -InputObject $infos -NotePropertyName "VirtualNetwork" -NotePropertyValue "VirtualNetwork"
                Add-Member -InputObject $infos -NotePropertyName "Subnet" -NotePropertyValue "Subnet"
                Add-Member -InputObject $infos -NotePropertyName "NicName" -NotePropertyValue "NicName"
                Add-Member -InputObject $infos -NotePropertyName "MacAddress" -NotePropertyValue "MacAddress"
                Add-Member -InputObject $infos -NotePropertyName "PrivateIpAddress" -NotePropertyValue "PrivateIpAddress"
                # Insert datas
                $NicsDetails = Get-AzNetworkInterface | Where-Object { $_.VirtualMachine.Id -eq $VirtualMachine.Id }  
                $infos.VirtualNetwork = ($NicsDetails.IpConfigurations.subnet.Id.Split("/")[-3] | Out-String).Trim()
                $infos.Subnet = ($NicsDetails.IpConfigurations.subnet.Id.Split("/")[-1] | Out-String).Trim()
                $infos.NicName = ($NicsDetails.Name | Out-String).Trim()
                $infos.MacAddress = ($NicsDetails.MacAddress | Out-String).Trim()
                $infos.PrivateIpAddress = ($NicsDetails.IpConfigurations.PrivateIpAddress | Out-String).Trim()
            }

            ## Disks Region
            if ($DisksInformation -eq $true) {
                # Add columns to array
                Add-Member -InputObject $infos -NotePropertyName "DiskType" -NotePropertyValue "DiskType"
                Add-Member -InputObject $infos -NotePropertyName "DiskSizeGB" -NotePropertyValue "DiskSizeGB"
                Add-Member -InputObject $infos -NotePropertyName "DiskProvisionnedIOPS" -NotePropertyValue "DiskProvisionnedIOPS"
                Add-Member -InputObject $infos -NotePropertyName "DiskMBpsReadWrite" -NotePropertyValue "DiskMBpsReadWrite" 
                # Insert datas
                $DisksDetails = Get-AzDisk | Where-Object { $_.ManagedBy -eq $VirtualMachine.Id }
                # OS Disk
                if ($VirtualMachineDetails.StorageProfile.OsDisk.ManagedDisk) {
                    $infos.DiskType = "Managed"
                    $infos.DiskSizeGB = $DisksDetails.DiskSizeGB | Where-Object {$_.Id -eq $VirtualMachine.StorageProfile.OsDisk.ManagedDisk.Id}
                    $infos.DiskProvisionnedIOPS = $DisksDetails.DiskIOPSReadWrite | Where-Object {$_.Id -eq $VirtualMachine.StorageProfile.OsDisk.ManagedDisk.Id}
                    $infos.DiskMBpsReadWrite = $DisksDetails.DiskMBpsReadWrite | Where-Object {$_.Id -eq $VirtualMachine.StorageProfile.OsDisk.ManagedDisk.Id}
                }
                elseif ($VirtualMachineDetails.StorageProfile.OsDisk.Vhd) {
                    $infos.DiskType = "VHD"
                    $infos.DiskSizeGB = $VirtualMachineDetails.StorageProfile.OsDisk.DiskSizeGB 
                }     
                # Data Disk
                $DataDisks = $VirtualMachineDetails.StorageProfile.DataDisks
                if ($DataDisks.CreateOption -eq "Attach") {
                    $infos.DiskType = "Managed"
                    $infos.DiskSizeGB = ($DisksDetails.DiskSizeGB |  Out-String).Trim()
                    $infos.DiskProvisionnedIOPS = ($DisksDetails.DiskIOPSReadWrite | Out-String).Trim()
                    $infos.DiskMBpsReadWrite = ($DisksDetails.DiskMBpsReadWrite | Out-String).Trim()
                }
                elseif ($DataDisks.CreateOption -eq "Empty") {
                    $infos.DiskType = "VHD"
                    $infos.DiskSizeGB = ($DataDisks.DiskSizeGB | Out-String).Trim()
                    $infos.DiskProvisionnedIOPS = "N/A"
                    $infos.DiskMBpsReadWrite = "N/A"  
                }
           }
           
           ## Metrics region
           # Add columns to array
           Add-Member -InputObject $infos -NotePropertyName "CPUAverage" -NotePropertyValue "CPUAverage"
           Add-Member -InputObject $infos -NotePropertyName "CPUMaximum" -NotePropertyValue "CPUMaximum"
           Add-Member -InputObject $infos -NotePropertyName "OSDiskAverageIOPS" -NotePropertyValue "OSDiskAverageIOPS"
           Add-Member -InputObject $infos -NotePropertyName "OSDiskMaximumIOPS" -NotePropertyValue "OSDiskMaximumIOPS"
           Add-Member -InputObject $infos -NotePropertyName "DataDiskAverageIOPS" -NotePropertyValue "DataDiskAverageIOPS"
           Add-Member -InputObject $infos -NotePropertyName "DataDiskMaximumIOPS" -NotePropertyValue "DataDiskMaximumIOPS"
           # Insert datas
           [Decimal]$infos.CPUAverage = ((Get-AzMetric -ResourceId $VirtualMachine.Id -TimeGrain 1.00:00:00 -MetricName "Percentage CPU" -StartTime $StartDate -EndTime $EndDate -WarningAction Ignore).Data.Average | Measure-Object -Average).Average
           if ([string]::IsNullOrEmpty($infos.CPUAverage) -eq $True) { $infos.CPUAverage = "VM Stopped" } else { $infos.CPUAverage = [math]::Round($infos.CPUAverage,5) }
           [Decimal]$infos.CPUMaximum = ((Get-AzMetric -ResourceId $VirtualMachine.Id -TimeGrain 1.00:00:00 -MetricName "Percentage CPU" -StartTime $StartDate -EndTime $EndDate -WarningAction Ignore).Data.Average | Measure-Object -Maximum).Maximum
           if ([string]::IsNullOrEmpty($infos.CPUMaximum ) -eq $True) { $infos.CPUMaximum  = "VM Stopped" } else { $infos.CPUMaximum = [math]::Round($infos.Maximum,5) }
           [Decimal]$infos.OSDiskAverageIOPS = ((Get-AzMetric -ResourceId $VirtualMachine.Id -TimeGrain 1.00:00:00 -MetricName "OS Disk IOPS Consumed Percentage" -StartTime $StartDate -EndTime $EndDate -WarningAction Ignore).Data.Average | Measure-Object -Average).Average
           if ([string]::IsNullOrEmpty($infos.OSDiskAverageIOPS) -eq $True) { $infos.OSDiskAverageIOPS = "VM Stopped" } else { $infos.OSDiskAverageIOPS = [math]::Round($infos.OSDiskAverageIOPS,5) }
           [Decimal]$infos.OSDiskMaximumIOPS = ((Get-AzMetric -ResourceId $VirtualMachine.Id -TimeGrain 1.00:00:00 -MetricName "OS Disk IOPS Consumed Percentage" -StartTime $StartDate -EndTime $EndDate -WarningAction Ignore).Data.Average | Measure-Object -Maximum).Maximum
           if ([string]::IsNullOrEmpty($infos.OSDiskMaximumIOPS) -eq $True) { $infos.OSDiskMaximumIOPS = "VM Stopped" } else { $infos.OSDiskMaximumIOPS = [math]::Round($infos.OSDiskMaximumIOPS,5) }
           [Decimal]$infos.DataDiskAverageIOPS = ((Get-AzMetric -ResourceId $VirtualMachine.Id -TimeGrain 1.00:00:00 -MetricName "Data Disk IOPS Consumed Percentage" -StartTime $StartDate -EndTime $EndDate -WarningAction Ignore).Data.Average | Measure-Object -Average).Average
           if ([string]::IsNullOrEmpty($infos.DataDiskAverageIOPS) -eq $True) { $infos.DataDiskAverageIOPS = "VM Stopped" } else { $infos.DataDiskAverageIOPS = [math]::Round($infos.CPUDataDiskAverageIOPSAverage,5) }
           [Decimal]$infos.DataDiskMaximumIOPS = ((Get-AzMetric -ResourceId $VirtualMachine.Id -TimeGrain 1.00:00:00 -MetricName "Data Disk IOPS Consumed Percentage" -StartTime $StartDate -EndTime $EndDate -WarningAction Ignore).Data.Average | Measure-Object -Maximum).Maximum
           if ([string]::IsNullOrEmpty($infos.DataDiskMaximumIOPS) -eq $True) { $infos.DataDiskMaximumIOPS = "VM Stopped" } else { $infos.DataDiskMaximumIOPS = [math]::Round($infos.CPUDataDiskMaximumIOPSAverage,5) }
        
           
           # Write to report
           $Report += $infos
  

           if ($VirtualMachine.Name -eq "azieoracle") {
               break
           }
         
        }

    } 
}

$Report | Format-Table VmName, ResourceGroupName, Region, VmSize, OsType , VirtualNetwork, Subnet, NicName, MacAddress, PrivateIpAddress, PublicIPAddress, DiskSizeGB, DiskProvisionnedIOPS, CPUAverage, CPUMaximum, OSDiskAverageIOPS, OSDiskMaximumIOPS, DataDiskAverageIOPS, DataDiskMaximumIOPS
$Report | Export-CSV "$ExportFolder/$reportName"



