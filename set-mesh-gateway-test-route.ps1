[CmdletBinding()]
param(
    [ValidateSet('Add', 'Remove')]
    [string]$Action = 'Add',
    [string]$Destination = '1.1.1.1/32',
    [string]$Gateway = '10.41.0.1',
    [string]$InterfaceAlias = 'Wi-Fi'
)

$ErrorActionPreference = 'Stop'
$interface = Get-NetIPInterface -AddressFamily IPv4 -InterfaceAlias $InterfaceAlias

if ($Action -eq 'Add') {
    Get-NetRoute -AddressFamily IPv4 -DestinationPrefix $Destination -ErrorAction SilentlyContinue |
        Where-Object InterfaceIndex -eq $interface.InterfaceIndex |
        Remove-NetRoute -Confirm:$false

    New-NetRoute -AddressFamily IPv4 `
        -DestinationPrefix $Destination `
        -InterfaceIndex $interface.InterfaceIndex `
        -NextHop $Gateway `
        -RouteMetric 1 `
        -PolicyStore ActiveStore | Out-Null
} else {
    Get-NetRoute -AddressFamily IPv4 -DestinationPrefix $Destination -ErrorAction SilentlyContinue |
        Where-Object InterfaceIndex -eq $interface.InterfaceIndex |
        Remove-NetRoute -Confirm:$false
}

Get-NetRoute -AddressFamily IPv4 -DestinationPrefix $Destination -ErrorAction SilentlyContinue |
    Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric, PolicyStore
