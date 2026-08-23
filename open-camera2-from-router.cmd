@echo off
title Bombs1 Camera 2 Router Tunnel
cd /d "%~dp0"
echo Camera 2 web page: http://127.0.0.1:18081/index.html
echo Path: router PC -^> Bombs1 192.168.50.183 -^> Halo mesh -^> camera 10.41.0.51
echo Keep this window open. Press Ctrl+C to stop the tunnel.
echo.
ssh.exe -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -i "%~dp0openmanet_diag_rsa_nopass" -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=10.41.0.1 -o "UserKnownHostsFile=%~dp0openmanet_diag_known_hosts" -L "127.0.0.1:18081:10.41.0.51:80" root@192.168.50.183
echo.
echo Tunnel stopped.
pause
