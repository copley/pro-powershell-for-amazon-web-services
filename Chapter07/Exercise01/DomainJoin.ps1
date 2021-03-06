
#This script will create a new instance and join it to the specified domain 

param
(
    [string][parameter(mandatory=$true)]$ServerName,
    [string][parameter(mandatory=$true)]$SubnetId,
    [string][parameter(mandatory=$false)]$DomainName = 'AWSLAB.local',
    [string][parameter(mandatory=$false)]$DomainUser = 'AWSLAB\AWSAdmin',
    [string][parameter(mandatory=$true)]$DomainPassword, 
    [string][parameter(mandatory=$false)]$InstanceType = 't1.micro',
    [string][parameter(mandatory=$false)]$KeyName = 'MyKey',
    [string][parameter(mandatory=$false)]$PemFile = 'C:\AWS\MyKey.pem',
    [string][parameter(mandatory=$false)]$AMI
)

If([System.String]::IsNullOrEmpty($AMI)){ $AMI = (Get-EC2ImageByName -Name "WINDOWS_2012_BASE")[0].ImageId}

$UserData = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(@'
<powershell>
Get-NetFirewallRule | Where { $_.DisplayName -eq "Windows Management Instrumentation (ASync-In)" } | Enable-NetFirewallRule 
Get-NetFirewallRule | Where { $_.DisplayName -eq "Windows Management Instrumentation (DCOM-In)" } | Enable-NetFirewallRule 
Get-NetFirewallRule | Where { $_.DisplayName -eq "Windows Management Instrumentation (WMI-In)" } | Enable-NetFirewallRule 
</powershell>
'@))

$Reservation = New-EC2Instance -ImageId $AMI -KeyName $KeyName -InstanceType $InstanceType -SubnetId $SubnetId -MinCount 1 -MaxCount 1 -UserData $UserData
$InstanceId = $Reservation.RunningInstance[0].InstanceId
Start-Sleep -s 60  #Wait for resource availability
$Reservation = Get-EC2Instance $InstanceId
$IP = $Reservation.RunningInstance[0].PrivateIpAddress

$Tag = New-Object Amazon.EC2.Model.Tag
$Tag.Key = 'Name'
$Tag.Value = $ServerName
New-EC2Tag -ResourceId $InstanceId -Tag $tag


$LocalPassword = $null
While( $LocalPassword -eq $null) {Try {Write-Host "Waiting for password."; $LocalPassword = Get-EC2PasswordData -InstanceId $InstanceId -PemFile $PemFile -ErrorAction SilentlyContinue }Catch{}; Start-Sleep -s 60}

#Add the computer to the domain
$DomainPasswordSecure = $DomainPassword | ConvertTo-SecureString -asPlainText -Force
$DomainCredential = New-Object System.Management.Automation.PSCredential($DomainUser, $DomainPasswordSecure)

$LocalComputer = $IP
$LocalPasswordSecure = $LocalPassword | ConvertTo-SecureString -asPlainText -Force
$LocalCredential = New-Object System.Management.Automation.PSCredential("administrator", $LocalPasswordSecure)

Add-Computer -ComputerName $LocalComputer -LocalCredential $LocalCredential -NewName $ServerName -DomainName $DomainName -Credential $DomainCredential -Restart -Force
