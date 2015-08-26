Param (
	[Parameter(ParameterSetName='ContainerNative')]
	[Switch]$RunNative,
    [Parameter(ParameterSetName='ContainerPowerShell')]
    [Switch]$CreateContainerImageUsingPowerShell,
    [Parameter(ParameterSetName='ContainerPowerShell')]
    [string]$InternetVirtualSwitchName = "Virtual Switch"
)

$containerImageName = "IIS"
$containerImagePublisher = $env:Username
$containerImageVersion = 10.0

$containerScript = {
    $tempdir = Join-Path -Path $env:temp -ChildPath "$(Get-Date -format 'yyyyMMddhhmmss')"

    # run Add-WindowsFeature for the first time - this will hit a bug, therefore using ErrorAction SilentlyContinue
    Write-Output "[container] Running installer: Add-WindowsFeature Web-Server"
    Add-WindowsFeature Web-Server -ErrorAction SilentlyContinue

	# run Add-WindowsFeature a second time to work around a bug
	Write-Output "[container] Running installer a second time: Add-WindowsFeature Web-Server"
    Add-WindowsFeature Web-Server
}

If ($RunNative)
{
    Write-Output "Running natively (or inside a Container) - simply executing the script block"
    Invoke-Command -ScriptBlock $containerScript
}
ElseIf ($CreateContainerImageUsingPowerShell)
{
      Write-Output "Creating new Container using PowerShell"
      $c1 = New-Container "$containerImageName Container" -ContainerImageName "WindowsServerCore" -Switch $internetVirtualSwitch

      Write-Output "Starting $($c1.Name)"
      Start-Container $c1

      Write-Output "Running Script Block inside Container"
      Invoke-Command -ContainerId $c1.Id -RunAsAdministrator -ScriptBlock $containerScript

      Write-Output "Collecting the Internal IP Address of the Container"
      $containerInternalIPAddress = Invoke-Command -ContainerId $c1.Id -RunAsAdministrator -ScriptBlock $getInternalIPScript

      Write-Output "Container IP Address is $containerInternalIPAddress"
      Write-Output "Creating NAT Mapping Rule and Firewall Port Exception"
      Add-NetNatStaticMapping -NatName (Get-NetNat).Name -Protocol TCP -ExternalIPAddress 0.0.0.0 -InternalIPAddress $containerIPAddress -InternalPort 80 -ExternalPort 80
      if (!(Get-NetFirewallRule | where {$_.Name -eq "TCP80"})) {
        New-NetFirewallRule -Name "TCP80" -DisplayName "HTTP on TCP/80" -Protocol tcp -LocalPort 80 -Action Allow -Enabled True
      }

      #Try to load default IIS web page
      try{
        $statusCode = (wget -uri http://$containerIPAddress -UseBasicParsing).statuscode
        Write-Output "Testing IIS default page succedeed with status code $statusCode"
      }
      catch{
        Write-Output "Testing IIS default page failed with error: $_"
      }

      Write-Output "Stopping $($c1.Name)"
      Stop-Container $c1

      Write-Output "Creating new image $containerImageName from $($c1.Name)"
      Do {New-ContainerImage -Container $c1 -Publisher $containerImagePublisher -Name $containerImageName -Version 1.0 -EA 0} Until ($?)

      Write-Output "Removing Container $($c1.Name)"
      Remove-Container $c1 -Force
}
Else
{
    Write-Output "Please specify either -RunNative or -CreateContainerImageUsingPowerShell"
}