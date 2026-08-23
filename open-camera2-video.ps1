param(
    [string]$CameraUser = 'admin',
    [string]$CameraWebUrl = 'http://127.0.0.1:18081',
    [string]$RtspHost = '127.0.0.1',
    [int]$RtspPort = 18554
)

$ErrorActionPreference = 'Stop'

$ffplay = (Get-Command ffplay.exe -ErrorAction Stop).Source
$securePassword = Read-Host 'Camera password' -AsSecureString
$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)

try {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
    $digestText = $CameraUser + 'get_stream_url' + $plainPassword
    $md5 = [Security.Cryptography.MD5]::Create()
    try {
        $digestBytes = $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($digestText))
    }
    finally {
        $md5.Dispose()
    }

    $digest = ([BitConverter]::ToString($digestBytes)).Replace('-', '').ToLowerInvariant()
    $requestObject = [ordered]@{
        method = 'get_stream_url'
        user = [ordered]@{
            name = $CameraUser
            digest = $digest
        }
        param = [ordered]@{
            channelid = 0
        }
    }
    $requestJson = $requestObject | ConvertTo-Json -Compress -Depth 5
    $endpoint = $CameraWebUrl.TrimEnd('/') + '/cgi-bin/jvsweb.cgi'
    $response = Invoke-RestMethod -UseBasicParsing -Method Get -Uri $endpoint -Body @{ cmd = $requestJson } -TimeoutSec 15

    if ($null -eq $response.error -or [int]$response.error.errorcode -ne 0) {
        $code = if ($null -ne $response.error) { $response.error.errorcode } else { 'unknown' }
        throw "Camera rejected stream discovery (error $code). Recheck the camera password."
    }

    $streams = @($response.result.list)
    if ($streams.Count -eq 0) {
        throw 'Camera returned no RTSP streams.'
    }

    $streamUris = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $streams) {
        foreach ($propertyName in @('stream1', 'stream0')) {
            $value = $entry.$propertyName
            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                $streamUris.Add([string]$value)
            }
        }
    }

    if ($streamUris.Count -eq 0) {
        throw 'Camera stream discovery succeeded but returned no usable RTSP URL.'
    }

    Write-Host 'Camera returned these stream paths:' -ForegroundColor Cyan
    foreach ($streamUri in $streamUris) {
        $parsed = [Uri]$streamUri
        Write-Host ('  ' + $parsed.AbsolutePath)
    }

    # Prefer the camera's substream (stream1) for the constrained HaLow link.
    $selected = [Uri]$streamUris[0]
    $escapedUser = [Uri]::EscapeDataString($CameraUser)
    $escapedPassword = [Uri]::EscapeDataString($plainPassword)
    $localRtspUrl = 'rtsp://{0}:{1}@{2}:{3}{4}' -f $escapedUser, $escapedPassword, $RtspHost, $RtspPort, $selected.PathAndQuery

    Write-Host ('Opening low-bandwidth stream ' + $selected.AbsolutePath + ' with FFplay over TCP...') -ForegroundColor Green
    Start-Process -FilePath $ffplay -ArgumentList @('-rtsp_transport', 'tcp', $localRtspUrl)
}
finally {
    $plainPassword = $null
    $digestText = $null
    $digest = $null
    $localRtspUrl = $null
    if ($passwordPtr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
    }
}
