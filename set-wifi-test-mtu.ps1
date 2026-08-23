param(
    [ValidateRange(1280, 1500)]
    [int]$Mtu = 1400
)

$ErrorActionPreference = 'Stop'
$resultPath = Join-Path $PSScriptRoot 'wifi-test-mtu-result.txt'

try {
    & netsh.exe interface ipv4 set subinterface 'Wi-Fi' mtu=$Mtu store=active | Out-Null

    @(
        'SUCCESS'
        "Completed: $(Get-Date -Format o)"
        "Requested IPv4 MTU: $Mtu"
        (& netsh.exe interface ipv4 show subinterfaces)
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
