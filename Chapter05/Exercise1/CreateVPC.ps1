
#This script will create the VPC discussed throughout most of chapter 5

param
(
    [string][parameter(mandatory=$true)]$DomainName,
    [string][parameter(mandatory=$false)]$VPCCIDR = '192.168.0.0/16',
    [string][parameter(mandatory=$false)]$PublicSubnetCIDR = '192.168.1.0/24',
    [string][parameter(mandatory=$false)]$PrivateSubnetCIDR = '192.168.2.0/24'
)

#Create the new VPC
$VPC = New-EC2Vpc -CidrBlock $VPCCIDR
Start-Sleep -s 15 #This can take a few seconds

#Configure the DHCP Options
$Domain = New-Object Amazon.EC2.Model.DhcpConfiguration
$Domain.Key = 'domain-name'
$Domain.Value = $DomainName
$DNS = New-Object Amazon.EC2.Model.DhcpConfiguration
$DNS.Key = 'domain-name-servers'
$DNS.Value = 'AmazonProvidedDNS'
$DHCP = New-EC2DHCPOption -DhcpConfiguration $Domain, $DNS
Register-EC2DhcpOption -DhcpOptionsId $DHCP.DhcpOptionsId -VpcId $VPC.VpcId

#Pick the first availability zone in the region.
$AvailabilityZones = Get-EC2AvailabilityZone
$AvailabilityZone = $AvailabilityZones[0].ZoneName

#Create and tag the Public subnet.
$PublicSubnet = New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock $PublicSubnetCIDR -AvailabilityZone $AvailabilityZone
Start-Sleep -s 15 #This can take a few seconds
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = 'Name'
$Tag.Value = 'Public'
New-EC2Tag -ResourceId $PublicSubnet.SubnetId  -Tag $Tag

#Create and tag the Private subnet.
$PrivateSubnet = New-EC2Subnet -VpcId $VPC.VpcId -CidrBlock $PrivateSubnetCIDR -AvailabilityZone $AvailabilityZone
Start-Sleep -s 15 #This can take a few seconds
$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = 'Name'
$Tag.Value = 'Private'
New-EC2Tag -ResourceId $PrivateSubnet.SubnetId  -Tag $Tag

#Add an Internet Gateway and attach it to the VPC.
$InternetGateway = New-EC2InternetGateway
Add-EC2InternetGateway -InternetGatewayId $InternetGateway.InternetGatewayId -VpcId $VPC.VpcId

#Create a new routeTable and associate it with the public subnet
$PublicRouteTable = New-EC2RouteTable -VpcId $VPC.VpcId
New-EC2Route -RouteTableId $PublicRouteTable.RouteTableId -DestinationCidrBlock '0.0.0.0/0' -GatewayId $InternetGateway.InternetGatewayId
$NoEcho = Register-EC2RouteTable -RouteTableId $PublicRouteTable.RouteTableId -SubnetId $PublicSubnet.SubnetId

#Create a new Access Control List for the public subnet
$PublicACL = New-EC2NetworkAcl -VpcId $VPC.VpcId
New-EC2NetworkAclEntry -NetworkAclId $PublicACL.NetworkAclId -RuleNumber 50 -CidrBlock $VPCCIDR -Egress $false -PortRange_From 80 -PortRange_To 80 -Protocol 6 -RuleAction 'Deny'
New-EC2NetworkAclEntry -NetworkAclId $PublicACL.NetworkAclId -RuleNumber 50 -CidrBlock $VPCCIDR -Egress $true -PortRange_From 49152 -PortRange_To 65535 -Protocol 6 -RuleAction 'Deny' 
New-EC2NetworkAclEntry -NetworkAclId $PublicACL.NetworkAclId -RuleNumber 100 -CidrBlock '0.0.0.0/0' -Egress $false -PortRange_From 80 -PortRange_To 80 -Protocol 6 -RuleAction 'Allow' 
New-EC2NetworkAclEntry -NetworkAclId $PublicACL.NetworkAclId -RuleNumber 100 -CidrBlock '0.0.0.0/0' -Egress $true -PortRange_From 49152 -PortRange_To 65535 -Protocol 6 -RuleAction 'Allow' 
New-EC2NetworkAclEntry -NetworkAclId $PublicACL.NetworkAclId -RuleNumber 200 -CidrBlock $PrivateSubnetCIDR -Egress $true -PortRange_From 1433 -PortRange_To 1433 -Protocol 6 -RuleAction 'Allow' 
New-EC2NetworkAclEntry -NetworkAclId $PublicACL.NetworkAclId -RuleNumber 200 -CidrBlock $PrivateSubnetCIDR -Egress $false -PortRange_From 49152 -PortRange_To 65535 -Protocol 6 -RuleAction 'Allow' 
New-EC2NetworkAclEntry -NetworkAclId $PublicACL.NetworkAclId -RuleNumber 300 -CidrBlock '0.0.0.0/0' -Egress $false -PortRange_From 3389 -PortRange_To 3389 -Protocol 6 -RuleAction 'Allow' 

#Associate the ACL to the public subnet
$VPCFilter = New-Object Amazon.EC2.Model.Filter
$VPCFilter.Name = 'vpc-id'
$VPCFilter.Value = $VPC.VpcId
$DefaultFilter = New-Object Amazon.EC2.Model.Filter
$DefaultFilter.Name = 'default'
$DefaultFilter.Value = 'true'
$OldACL = (Get-EC2NetworkAcl -Filter $VPCFilter, $DefaultFilter )
$OldAssociation = $OldACL.Associations | Where-Object { $_.SubnetId -eq $PublicSubnet.SubnetId }
$NoEcho = Set-EC2NetworkAclAssociation -AssociationId $OldAssociation.NetworkAclAssociationId -NetworkAclId $PublicACL.NetworkAclId

#Log the most common IDs
Write-Host "The VPC ID is" $VPC.VpcId
Write-Host "The public subnet ID is" $PublicSubnet.SubnetId
Write-Host "The private subnet ID is" $PrivateSubnet.SubnetId
