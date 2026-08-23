$ErrorActionPreference = 'Stop'

$resultPath = Join-Path $PSScriptRoot 'bombs1-wifi-management-result.txt'

try {
    Set-NetIPInterface -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -Dhcp Disabled

    Get-NetIPAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    Get-NetRoute -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

    New-NetIPAddress -InterfaceAlias 'Wi-Fi' -IPAddress '10.41.254.2' -PrefixLength 16 | Out-Null
    Set-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -ResetServerAddresses
    Set-NetIPInterface -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 500

    @(
        'SUCCESS'
        "Completed: $(Get-Date -Format o)"
        (netsh interface ipv4 show config name='Wi-Fi')
    ) | Set-Content -LiteralPath $resultPath -Encoding utf8
}
catch {
    @(
        'FAILED'
        "Completed: $(Get-Date -Format o)"
        $_.Exception.Message
    ) | Set-Content -LiteralPath $resultPath -Encoding utf8
    exit 1
}
