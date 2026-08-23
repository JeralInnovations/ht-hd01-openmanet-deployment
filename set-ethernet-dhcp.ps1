$ErrorActionPreference = 'Stop'

$backupPath = Join-Path $PSScriptRoot 'ethernet-config-backup.txt'
$resultPath = Join-Path $PSScriptRoot 'ethernet-dhcp-result.txt'

try {
    @(
        "Captured: $(Get-Date -Format o)"
        (netsh interface ipv4 show config name='Ethernet')
    ) | Set-Content -LiteralPath $backupPath -Encoding utf8

    Set-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -Dhcp Enabled

    Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object PrefixOrigin -eq 'Manual' |
        Remove-NetIPAddress -Confirm:$false

    Get-NetRoute -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Where-Object Protocol -eq 'NetMgmt' |
        Remove-NetRoute -Confirm:$false

    Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ResetServerAddresses
    ipconfig.exe /renew 'Ethernet' | Out-Null
    Start-Sleep -Seconds 3

    @(
        'SUCCESS'
        "Completed: $(Get-Date -Format o)"
        (netsh interface ipv4 show config name='Ethernet')
    ) | Set-Content -LiteralPath $resultPath -Encoding utf8
}
catch {
    @(
        'FAILED'
        "Completed: $(Get-Date -Format o)"
        $_.Exception.Message
        (netsh interface ipv4 show config name='Ethernet')
    ) | Set-Content -LiteralPath $resultPath -Encoding utf8
    exit 1
}
