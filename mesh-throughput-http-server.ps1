[CmdletBinding()]
param(
    [string]$ListenAddress = '10.41.0.123',
    [int]$Port = 8080,
    [long]$PayloadBytes = 10000000
)

$ErrorActionPreference = 'Stop'
$listener = [System.Net.Sockets.TcpListener]::new(
    [System.Net.IPAddress]::Parse($ListenAddress),
    $Port
)

try {
    $listener.Start()
    Write-Output "READY http://${ListenAddress}:${Port}/mesh-test.bin"

    $client = $listener.AcceptTcpClient()
    try {
        $client.NoDelay = $true
        $stream = $client.GetStream()
        $requestBuffer = [byte[]]::new(4096)
        $requestText = ''

        while ($requestText -notmatch "\r\n\r\n") {
            $read = $stream.Read($requestBuffer, 0, $requestBuffer.Length)
            if ($read -le 0) { throw 'Client closed before sending a complete HTTP request.' }
            $requestText += [System.Text.Encoding]::ASCII.GetString($requestBuffer, 0, $read)
        }

        $header = "HTTP/1.1 200 OK`r`nContent-Type: application/octet-stream`r`nContent-Length: $PayloadBytes`r`nConnection: close`r`n`r`n"
        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
        $stream.Write($headerBytes, 0, $headerBytes.Length)

        $payload = [byte[]]::new(65536)
        for ($i = 0; $i -lt $payload.Length; $i++) { $payload[$i] = $i % 251 }

        $remaining = $PayloadBytes
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        while ($remaining -gt 0) {
            $count = [int][Math]::Min($payload.Length, $remaining)
            $stream.Write($payload, 0, $count)
            $remaining -= $count
        }
        $stream.Flush()
        $timer.Stop()

        $megabitsPerSecond = if ($timer.Elapsed.TotalSeconds -gt 0) {
            [Math]::Round(($PayloadBytes * 8 / 1000000) / $timer.Elapsed.TotalSeconds, 3)
        } else { 0 }
        Write-Output "SENT bytes=$PayloadBytes seconds=$([Math]::Round($timer.Elapsed.TotalSeconds,3)) rate_mbps=$megabitsPerSecond"
    } finally {
        if ($stream) { $stream.Dispose() }
        $client.Dispose()
    }
} finally {
    $listener.Stop()
}
