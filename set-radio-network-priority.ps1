$ErrorActionPreference = 'Stop'

$resultPath = Join-Path $PSScriptRoot 'network-admin-result.txt'

try {
    Set-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 10
    Set-NetIPInterface -InterfaceAlias 'Wi-Fi' -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 500

    $state = Get-NetIPInterface -AddressFamily IPv4 -InterfaceAlias 'Ethernet', 'Wi-Fi' |
        Select-Object InterfaceAlias, AutomaticMetric, InterfaceMetric, ConnectionState

    @(
        'SUCCESS'
        "Completed: $(Get-Date -Format o)"
        ($state | Format-Table -AutoSize | Out-String).TrimEnd()
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
