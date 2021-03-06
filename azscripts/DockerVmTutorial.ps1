# Variables for common values
$resourceGroup = "lcolab"
$location = "eastus"
$vmName = "dockerVm"

# Definer user name and blank password
$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

# Create a resource group
#New-AzResourceGroup -Name $resourceGroup -Location $location

# Create a subnet configuration
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name mySubnet -AddressPrefix 192.168.1.0/24

# Create a virtual network
$vnetParams = @{
    ResourceGroupName   = $resourceGroup
    Location            = $location
    Name                = 'MYvNET'
    AddressPrefix       = '192.168.0.0/16'
    Subnet              = $subnetConfig
}
$vnet = New-AzVirtualNetwork @vnetParams

# Create a public IP address and specify a DNS name
$pipParams = @{
    ResourceGroupName       = $resourceGroup
    Location                = $location
    Name                    = "mypublicdns$(Get-Random)"
    AllocationMethod        = 'Static'
    IdleTimeoutInMinutes    = 4
}
$pip = New-AzPublicIpAddress @pipParams

# Create an inbound network security group rule for port 22
$sshRuleParams = @{
    Name                        = 'myNetworkSecurityGroupRuleSSH'
    Protocol                    = 'TCP'
    Direction                   = 'Inbound'
    Priority                    = 1000
    SourceAddressPrefix         = '*'
    SourcePortRange             = '*'
    DestinationAddressPrefix    = '*'
    DestinationPortRange        = 22
    Access                      = 'Allow'
}
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig @sshRuleParams

# Create an inbound network security group rule for port 80
$httpRuleParams = @{
    Name                        = 'myNetworkSecurityGroupRuleHTTP'
    Protocol                    = 'TCP'
    Direction                   = 'Inbound'
    Priority                    = 2000
    SourceAddressPrefix         = '*'
    SourcePortRange             = '*'
    DestinationAddressPrefix    = '*'
    DestinationPortRange        = 80
    Access                      = 'Allow'
}
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig @httpRuleParams

# Create a network security group
$nsgParams = @{
    ResourceGroupName   = $resourceGroup
    Location            = $location
    Name                = 'myNetworkSecurityGroup'
}
$nsg = New-AzNetworkSecurityGroup @nsgParams -SecurityRules $nsgRuleSSH,$nsgRuleHTTP

# Create a virtual network card and associate with public IP address and NSG
$nicParams = @{
    Name                    = 'myNic'
    ResourceGroupName       = $resourceGroup
    Location                = $location
    SubnetId                = $vnet.Subnets[0].Id
    PublicIpAddressId       = $pip.Id
    NetworkSecurityGroupId  = $nsg.Id
}
$nic = New-AzNetworkInterface @nicParams

# Create a virtual machine configuration

$vmConfig = New-AzVMConfig -VMName $vmName -VMSize Standard_D1 |
            Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential $cred -DisablePasswordAuthentication |
            Set-AzVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 14.04.2-LTS -Version latest |
            Add-AzVMNetworkInterface -Id $nic.Id

# Configure SSH Keys
$sshPublicKey = Get-Content ~/.ssh/id_rsa.pub
#$sshPublicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"
Add-AzVMSshPublicKey -VM $vmConfig -KeyData $sshPublicKey -Path "/home/azureuser/.ssh/authorized_keys"

# Create a virtual machine
New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig

# Install Docker and run container
$PublicSettings = '{"docker": {"port": "2375"},"compose": {"web": {"image": "nginx","ports": ["80:80"]}}}'

<#
$azVmExtensionParams = @{
    ExtensionName       = 'Docker'
    ResourceGroupName   = $resourceGroup
    VMName              = $vmName
    Publisher           = 'Microsoft.Azure.Extensions'
    ExtensionType       = 'DockerExtension'
    TypeHandlerVersion  = 1.0
    SettingString       = $PublicSettings
    Location            = $location
}
Set-AzVMExtension @azVmExtensionParams
#>

Set-AzVMExtension -ExtensionName "Docker" -ResourceGroupName $resourceGroup -VMName $vmName `
  -Publisher "Microsoft.Azure.Extensions" -ExtensionType "DockerExtension" -TypeHandlerVersion 1.0 `
  -SettingString $PublicSettings -Location $location