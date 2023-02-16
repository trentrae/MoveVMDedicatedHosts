# Sumit Kumar
# 14 April 2020
# Script to move Azure IaaS VMs to Dedicated Hosts

# Disclaimer - The sample scripts provided here are not supported under any Microsoft standard support program or service. 
# All scripts are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without limitation, 
# any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the 
# sample scripts and documentation remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, 
# production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, 
# business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or 
# documentation, even if Microsoft has been advised of the possibility of such damages.

# Specific VM Name that you want to move from IaaS to Dedicated Host
$subscription = ''
$VM = 'vmtest01'

# Specific your Dedicated Host, Host Group and Resource Group details where dedicated host has been deployed
$hostname = 'dHosts01'
$HGName = 'HostGroup1'
$resourceGroupName = 'testing'

#select the proper subscription
Set-AzContext -SubscriptionName $subscription

# below commands captures the existing VM configuration

$VMName = Get-AzVM -Name $VM
$VMName.HardwareProfile.VmSize

$dhInfo = Get-AzHost -ResourceGroupName $resourceGroupName -Name $hostname -HostGroupName $HGName -InstanceView

$hostGrouInfo = Get-AzHostGroup -ResourceGroupName $resourceGroupName -HostGroupName $HGName

#test and see if they are in the same Zone
if (!([string]::IsNullOrEmpty($hostGroupInfo.Zones) -AND [string]::IsNullOrEmpty($VMName.Zones)))
{ 
    write-host "Both the Host group and Vm Zones aren't Empty"
    write-host $VM "=" $VMName.Zones
    write-host $HGName "=" $hostGroupInfo.Zones
    if (!($hostGroupInfo.Zones -Contains $VMName.Zones))
    {
        write-host "The Host group and Vm Zones aren't the same"
        write-host $VM "=" $VMName.Zones
        write-host $HGName "=" $hostGroupInfo.Zones
		exit 0
    }
}else{
	write-host "All good. Both are in the same Zone"
    write-host $VM "=" $VMName.Zones
    write-host $HGName "=" $hostGroupInfo.Zones	
}
#Test and see if the server size is on the Designated host. 
$found=0
foreach ($i in $dhinfo.InstanceView.AvailableCapacity.AllocatableVMs) {
    write-host $i.VmSize
	if ($i.VmSize -Contains $VMName.HardwareProfile.VmSize)
	{
		$found = 1
		 write-host "Machine Size Found"
		 write-host $i.VmSize
		 write-host $VMName.HardwareProfile.VmSize
		 break
	}
}
if ($found -eq 0)
{
	write-host $VMName.HardwareProfile.VmSize "not found"
	exit 0
}else{
	write-host $VMName.HardwareProfile.VmSize "found"

}


#Provide the size of the virtual machine
#D2s_v3,D4s, D8x, D16s, D32-8x, D32-16s, D32s, D48s, D64-16s, D64-32s D64s are supported on DSv3-Type2 dedicated host
$virtualMachineSize = $VMName.HardwareProfile.VmSize

$virtualMachineName = $VMName.Name
$osdisk = Get-AzDisk -Name ($VMName).StorageProfile.OsDisk.name
$vmdisks = ($VMName).StorageProfile.DataDisks


# Initialize virtual machine configuration
$dhost = Get-AzHost -Name $hostname -ResourceGroupName $resourceGroupName -HostGroupName $HGName
$VirtualMachine = New-AzVMConfig -VMName $virtualMachineName -HostId $dhost.id -VMSize $virtualMachineSize

# Use the Managed Disk Resource Id to attach it to the virtual machine
# Change the OS type to linux, if OS disk have linux OS installed

$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $osdisk.Id -CreateOption Attach -Windows

$count = 0

foreach ($disk in $vmDisks)
{

    $ddisk = Get-AzDisk -Name $disk.name
    $ddisks = Add-AzVMDataDisk -CreateOption Attach -Lun $count -VM $VirtualMachine -ManagedDiskId $ddisk.Id
    $count++
    
}

$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id (($VMName).NetworkProfile.NetworkInterfaces).id

# Delete existing VM from Azure IaaS

Remove-AzVM -Name $VM -ResourceGroupName $VMName.ResourceGroupName -Force

#wait 2 minutes for everything to be fully removed from azure
Start-Sleep -Seconds 120

# Create virtual machine with Managed Disk on dedicated host specific earlier

New-AzVM -VM $VirtualMachine -ResourceGroupName ($VMName).ResourceGroupName -Location ($VMName).Location
