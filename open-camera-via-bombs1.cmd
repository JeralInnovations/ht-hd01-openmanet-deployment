@echo off
title Bombs1 Camera Tunnel
cd /d "%~dp0"
echo Opening camera HTTP on http://127.0.0.1:18080/admin/
echo Opening camera RTSP on rtsp://127.0.0.1:18554/
echo Keep this window open while using the camera. Press Ctrl+C to stop.
echo.
ssh.exe -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -i "%~dp0openmanet_diag_rsa_nopass" -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=%~dp0openmanet_diag_known_hosts" -L "127.0.0.1:18080:[fe80::dec2:c9ff:feae:50de%%br-ahwlan]:80" -L "127.0.0.1:18554:[fe80::dec2:c9ff:feae:50de%%br-ahwlan]:554" root@10.41.0.1
echo.
echo Tunnel stopped.
pause
