# Specific VM Name that you want to move from IaaS to Dedicated Host
$subscription = ''
#$tenantid = ''
$VM = 'vm-test-004'

#select the proper subscription
Set-AzContext -SubscriptionName $subscription
#Set-AzContext -TenantId '7489987e-92f9-4f08-9828-2228010ca26f'

# Specific your Dedicated Host, Host Group and Resource Group details where dedicated host has been deployed
$hostname = ''
$HGName = ''
$resourceGroupName = ''


# KeyVault and Disk Encryption
$KVName = ''
$KeyVault = Get-AzKeyVault -VaultName $KVName
$DiskSetEncryptName = ''
$DiskEncryptionSet = Get-AzDiskEncryptionSet -Name $DiskSetEncryptName
# Resource group this VM will reside in.
$MoveToResourceGroupName =''

# below commands captures the existing VM configuration

$VMName = Get-AzVM -Name $VM
$VMName.HardwareProfile.VmSize

$dhInfo = Get-AzHost -ResourceGroupName $resourceGroupName -Name $hostname -HostGroupName $HGName -InstanceView

$hostGroupInfo = Get-AzHostGroup -ResourceGroupName $resourceGroupName -HostGroupName $HGName

#Test VM and Dedicated Host for current zone configuration then display results script will abort if not the same zone

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


# Gather the current size of the virtual machine 

$virtualMachineSize = $VMName.HardwareProfile.VmSize
$virtualMachineName = $VMName.Name
$osdisk = Get-AzDisk -Name ($VMName).StorageProfile.OsDisk.name
$vmdisks = ($VMName).StorageProfile.DataDisks


# Initialize virtual machine configuration
$dhost = Get-AzHost -Name $hostname -ResourceGroupName $resourceGroupName -HostGroupName $HGName
$virtualMachineSize = $VMName.HardwareProfile.VmSize

# Use the Managed Disk Resource Id to attach it to the virtual machine
# Change the OS type to linux, if OS disk have linux OS installed

$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $osdisk.Id -CreateOption Attach -Windows -DiskEncryptionSetId $DiskEncryptionSet.Id

#$count = 0
for ($lun=0;$lun -le 2;$lun=$lun+1)
  {
  foreach ($disk in $vmDisks)
    {

      $ddisk = Get-AzDisk -Name $disk.name
      $ddisks = Add-AzVMDataDisk -CreateOption Attach -Lun $lun -VM $VirtualMachine -ManagedDiskId $ddisk.Id -DiskEncryptionSetId $DiskEncryptionSet.Id
      #$count++
    
    }
}

#$VirtualMachine = Set-AzVmSecurityProfile -VM $VirtualMachine -SecurityType "TrustedLaunch" 
#$VirtualMachine= Set-AzVmUefi -VM $VirtualMachine -EnableVtpm $true -EnableSecureBoot $true
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id (($VMName).NetworkProfile.NetworkInterfaces).id -Primary

# Delete existing VM from Azure IaaS
write-host "Deleting Dedicated Host VM Creating new IaaS "
Remove-AzVM -Name $VM -ResourceGroupName $VMName.ResourceGroupName -Force

#wait 2 minutes for everything to be fully removed from azure
write-host "Wait 2 minutes for Azure Resources to clean up"
Start-Sleep -Seconds 120

# Create virtual machine with Managed Disk on dedicated host specific earlier
write-host "Creating New IaaS VM"
New-AzVM -VM $VirtualMachine -ResourceGroupName $MoveToResourceGroupName -Location ($VMName).Location -Zone $VMName.zones
 


#Set-AzVMExtension -Name AzureMonitorWindowsAgent -ExtensionType AzureMonitorWindowsAgent -Publisher Microsoft.Azure.Monitor -ResourceGroupName $MoveToResourceGroupName -VMName $VM -Location $vmname.location -TypeHandlerVersion 1.12 -EnableAutomaticUpgrade $true

