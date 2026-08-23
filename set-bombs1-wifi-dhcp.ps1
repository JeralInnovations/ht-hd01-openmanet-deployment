$ErrorActionPreference = 'Stop'

$resultPath = Join-Path $PSScriptRoot 'bombs1-wifi-dhcp-result.txt'

try {
    Set-NetIPInterface -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -Dhcp Enabled

    Get-NetIPAddress -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object PrefixOrigin -eq 'Manual' |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    Get-NetRoute -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Where-Object Protocol -eq 'NetMgmt' |
        Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

    Set-DnsClientServerAddress -InterfaceAlias 'Wi-Fi' -ResetServerAddresses
    Set-NetIPInterface -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 500

    ipconfig.exe /renew 'Wi-Fi' | Out-Null
    Start-Sleep -Seconds 4

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
        (netsh interface ipv4 show config name='Wi-Fi')
    ) | Set-Content -LiteralPath $resultPath -Encoding utf8
    exit 1
}
