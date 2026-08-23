$ErrorActionPreference = 'Stop'

$resultPath = Join-Path $PSScriptRoot 'openmanet-direct-static-result.txt'

try {
    Set-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -Dhcp Disabled

    Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne '10.41.254.2' } |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    if (-not (Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -IPAddress '10.41.254.2' -ErrorAction SilentlyContinue)) {
        New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress '10.41.254.2' -PrefixLength 16 | Out-Null
    }
    elseif ((Get-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -IPAddress '10.41.254.2').PrefixLength -ne 16) {
        Remove-NetIPAddress -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -IPAddress '10.41.254.2' -Confirm:$false
        New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress '10.41.254.2' -PrefixLength 16 | Out-Null
    }

    Set-NetIPInterface -InterfaceAlias 'Ethernet' -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 500

    $state = Get-NetIPConfiguration -InterfaceAlias 'Ethernet'
    @(
        'SUCCESS'
        "Completed: $(Get-Date -Format o)"
        ($state | Format-List InterfaceAlias,IPv4Address,IPv4DefaultGateway,DNSServer | Out-String).TrimEnd()
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
