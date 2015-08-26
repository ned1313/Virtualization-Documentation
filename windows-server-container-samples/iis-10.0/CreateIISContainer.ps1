#Create IIS from Container Image
Param(
    [string]$IISImageName = "IIS",
    [string]$IISContentDirectory

)

#Test the presence of the Image
try{
    $IISImage = Get-ContainerImage $IISImageName
}
catch{
    Write-Output "Could not locate Container Image $IISImageName"
    throw "No Image"
}

#Test the presence of the Content Directory

#Verify that VM switch is NAT
$vmswitch = Get-VMSwitch | ?{$_.SwitchType -eq "NAT"}
if($vmswitch.Count -ge 1){
    $vmswitch = $vmswitch[0]
}
else{
    Write-Output "No NAT VMSwitch Found.  Exiting"
    throw "No NAT VMSwitch"
}


$getInternalIPScript = {
        #Get the IPv4 Address of the Container NIC
        Get-NetIPAddress | ?{$_.InterfaceAlias -like "vEthernet*" -and $_.AddressFamily -eq "IPv4"} -ov netip | Out-Null

        #Return the output to the pipeline
        Write-Output $netip.IPAddress
    }

$setIISContentScript = {

}