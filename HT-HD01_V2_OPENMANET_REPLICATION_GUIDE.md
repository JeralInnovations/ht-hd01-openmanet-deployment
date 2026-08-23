# HT-HD01 V2 OpenMANET Bomb-Squad Mesh Replication Guide

Last updated: 2026-08-19

## Purpose and current status

This guide records the exact process used to flash and configure the first HT-HD01 V2 as an OpenMANET Mesh Gate for a low-latency video mesh. It includes the problems encountered and the fixes that worked so another operator can repeat the setup without losing Internet access or being trapped by the Ethernet VLAN configuration.

Current first node:

| Item | Value |
|---|---|
| Physical label / hostname | `Bombs1` |
| Hardware | Heltec HT-HD01 **V2**, MM6108 |
| Firmware | OpenMANET 1.8.0 |
| Role | Mesh Gate |
| Mesh ID | `bombs-mesh` |
| Country | US |
| HaLow width / channel | 2 MHz / channel 42 (923 MHz) |
| Local client AP | `Bombs1-24G` |
| Local management address | `10.41.0.1/16` |
| Ethernet uplink device | `eth0.1`, DHCP client |
| Observed router-side lease | `192.168.50.183/24` |
| Current result | Ethernet uplink, client DHCP isolation, radio Internet/DNS, client NAT, and LuCI system reboot passed; physical cold power-cycle pending |

Passwords created during setup are intentionally not recorded here. Store the admin, mesh, and local-AP passwords in the approved password manager.

## Equipment and cabling

- One confirmed HT-HD01 **V2** at a time
- Correct US 915 MHz antenna, attached before power is applied
- Stable USB-C 5 V power and a known-good cable
- One Ethernet cable from the radio to the upstream router for the Mesh Gate
- Windows computer with both Ethernet and Wi-Fi

Working final topology:

```text
Internet
   |
Upstream router (DHCP/NAT)
   |-- Ethernet --> Bombs1 Ethernet jack (`eth0.1` uplink)
   |-- Ethernet --> setup PC (keeps Internet access)

Bombs1 `Bombs1-24G` Wi-Fi --> setup PC (radio management only)
Bombs1 HaLow `bombs-mesh`  --> later mesh points / relays
```

Keeping the PC wired to the router while its Wi-Fi is connected to the radio prevents the setup session from losing Internet whenever Windows changes Wi-Fi networks.

## Firmware package and integrity

- Image: `firmware/openmanet-1.8.0-heltec_ht-hd01-v2-mm6108-squashfs-sysupgrade.bin`
- Required SHA-256: `3c515848c9335e2dd9810e6f577b184030c3a3e036e4f3937865a65eff05962f`
- Verified locally before flashing: **match**

Never flash this V2 image onto an unmarked unit or a V1. Do not proceed until the enclosure/board marking positively identifies V2.

PowerShell verification command:

```powershell
Get-FileHash -Algorithm SHA256 '.\firmware\openmanet-1.8.0-heltec_ht-hd01-v2-mm6108-squashfs-sysupgrade.bin'
```

## Factory and fresh-install access

| State | SSID | Wi-Fi password | Web address | Web login |
|---|---|---|---|---|
| Factory Heltec firmware | `HT-HD01-xxxx` | `heltec.org` | Use the Wi-Fi adapter's assigned default gateway | `root` / `heltec.org` |
| Fresh OpenMANET | `openmanet` | `openmanet` | `http://10.41.254.1` | setup wizard |
| Configured Bombs1 | `Bombs1-24G` | operator-created | `http://10.41.0.1` | operator-created admin password |

The factory and fresh-install passwords are vendor defaults, not the passwords created for the operational mesh.

Factory management subnets vary by installed Heltec/Morse image. Radio 1 used `10.42.0.1`; unflashed Radio 2 (`HT-HD01-2384`, stock version `2.8.5-20260420`) used `192.168.100.1` and assigned the setup PC `192.168.100.161/24`. Always inspect the Wi-Fi adapter's DHCP default gateway instead of assuming the address.

## Flash procedure that proved reliable

1. Label the radio and confirm `V2` before applying power.
2. Attach the 915 MHz antenna.
3. Power only this radio.
4. Connect to the factory `HT-HD01-xxxx` Wi-Fi using `heltec.org`.
5. Inspect the Wi-Fi adapter's DHCP default gateway, browse to that address, and log in as `root` with `heltec.org`.
6. Open **System -> Reset / Flash Firmware**.
7. Upload the verified OpenMANET image.
8. Clear **Keep settings** so this is a clean installation.
9. A board-name capitalization mismatch warning may appear. Reconfirm the physical V2 marking, then enable **Force Upgrade**.
10. Start the upgrade and leave USB-C power connected until `openmanet` appears.
11. Join `openmanet` with password `openmanet` and browse to `http://10.41.254.1`.

### If browser upload disconnects

The first browser upload over the factory Wi-Fi failed because Windows dropped the radio AP while switching network paths. The reliable recovery was:

1. Connect the PC directly to the radio by Ethernet for management.
2. Keep the PC on normal Wi-Fi only for Internet.
3. Upload the image again, or use the already uploaded `/tmp/firmware.bin` over SSH.
4. Verify the image on the radio before installing:

```sh
sha256sum /tmp/firmware.bin
```

5. Only if the hash matches and the unit is confirmed V2, run:

```sh
sysupgrade -n -F /tmp/firmware.bin
```

`-n` discards the factory configuration. `-F` forces installation past the known board-name mismatch, so it must not be used on unconfirmed hardware.

## Bombs1 wizard values

Enter these values exactly for the first Mesh Gate:

| Wizard setting | Bombs1 value |
|---|---|
| Hostname | `Bombs1` |
| Role | Mesh Gate |
| Mesh ID | `bombs-mesh` |
| Mesh encryption | WPA3/SAE with shared operator-created mesh passphrase |
| Country | US |
| Bandwidth | 2 MHz |
| Channel | 42 (923 MHz) |
| Upstream | Ethernet |
| Local Wi-Fi AP | Enabled |
| AP SSID | `Bombs1-24G` |
| AP security | WPA2/WPA3 mixed |
| Admin password | Operator-created; do not reuse the mesh or AP password |

After applying the wizard, reconnect to `Bombs1-24G` and use `http://10.41.0.1`. A temporary loss of the browser connection during network reload is normal.

## Critical HT-HD01 V2 Ethernet correction

### Symptoms seen

- Both Ethernet port LEDs were green.
- The OpenMANET home page still reported **Uplink (Ethernet): Disconnected**.
- Interface `lan` was a DHCP client on `eth0` but received no IPv4 address or gateway.
- A computer connected to `Bombs1-24G` incorrectly received a router-side `192.168.50.x` lease instead of a Bombs1 `10.41.x.x` lease.
- The LuCI device counters showed real traffic on `eth0.1`.

### Cause

The HT-HD01 switch delivers the physical Ethernet jacks through VLAN 1 as `eth0.1`. The Mesh Gate wizard instead placed parent device `eth0` on the DHCP uplink and left `eth0.1` inside local bridge `br-ahwlan`. This bridged upstream router DHCP directly into the local AP and prevented the intended uplink interface from receiving a lease.

Observed switch configuration was internally consistent and did **not** need editing:

- VLAN 1
- CPU `eth0`: tagged
- LAN1 and LAN2: untagged

The firewall was also already correct: zone `lan` had masquerading enabled and `ahwlan` forwarded to `lan`.

### Exact correction in LuCI

1. Open **Advanced Config -> Network -> Interfaces**.
2. Open the **Devices** tab.
3. Find `br-ahwlan` and select **Configure**.
4. Under **Bridge ports**, remove `eth0.1`.
5. Retain `bat0` in the bridge. The wireless AP remains associated through Wireless configuration and does not need to appear as a wired bridge-port selection.
6. Select the dialog **Save** button. This stages the edit.
7. Return to the **Interfaces** tab.
8. Find interface `lan` and select **Edit**.
9. Keep protocol **DHCP client**.
10. Change **Device** from `eth0` to `eth0.1`.
11. Keep the existing `lan` firewall-zone assignment.
12. Select the dialog **Save** button.
13. Review both staged changes, then select **Save & Apply**.
14. Wait for network services to reload, reconnect to `Bombs1-24G` if necessary, and reload `http://10.41.0.1`.

Do not modify the Switch or Firewall pages for this correction.

### Verified result on Bombs1

- `br-ahwlan` contains `bat0` and the local AP, not `eth0.1`.
- `lan` is DHCP client on connected device `eth0.1`.
- Bombs1 received `192.168.50.183/24` from the upstream router.
- Local management remained reachable at `10.41.0.1/16`.
- LuCI Diagnostics pinged `openwrt.org`: 5 transmitted, 5 received, 0% packet loss. Successful hostname lookup and ping confirm both DNS and Internet connectivity from the radio.
- After returning the PC Wi-Fi adapter to DHCP, Bombs1 assigned `10.41.0.107/16`, gateway `10.41.0.1`, and DNS `10.41.0.1`. No router-side `192.168.50.x` lease leaked into the AP.
- A source-bound client ping from `10.41.0.107` to `1.1.1.1` returned 4/4 replies, and a source-bound HTTPS request to Google's connectivity endpoint returned HTTP 204. These tests forced traffic through Bombs1 Wi-Fi and confirmed client NAT, independent of the PC's wired router connection.

## Windows setup-computer network handling

### Normal final state

- PC Ethernet: automatic DHCP from the upstream router; carries Internet.
- PC Wi-Fi: connected to `Bombs1-24G`; automatic DHCP from Bombs1.
- Set PC Ethernet interface metric to 10 and radio Wi-Fi interface metric to 500. A fresh OpenMANET node advertised its own default route with route metric 10; leaving both Windows interfaces at metric 500 caused Windows to prefer the radio and lose Internet even though Ethernet remained connected.
- The included `set-radio-network-priority.ps1` applies the working Ethernet-10/Wi-Fi-500 values and must be run as administrator.

### Temporary management address used during diagnosis

Router DHCP initially leaked into `Bombs1-24G`, so the PC Wi-Fi was temporarily set to:

- Address: `10.41.254.2`
- Prefix: `/16`
- Gateway: none
- DNS: none
- Interface metric: 500

That static address keeps management traffic on Wi-Fi while Ethernet remains the only Internet/default-gateway path. After correcting Bombs1, run `set-bombs1-wifi-dhcp.ps1` as administrator to restore automatic client addressing.

## Verification checklist for each Mesh Gate

- [x] Hardware positively marked V2
- [x] Firmware SHA-256 matched before installation
- [x] OpenMANET 1.8.0 booted and fresh wizard loaded
- [x] Hostname, mesh ID, country, width, channel, and AP recorded
- [x] Local management UI reachable at `10.41.0.1`
- [x] Local bridge does not include the upstream Ethernet VLAN
- [x] `lan` DHCP client is bound to `eth0.1`
- [x] Upstream router assigned an IPv4 lease
- [x] Radio-originated DNS and Internet ping passed
- [x] Wi-Fi client receives `10.41.x.x`, not router-side `192.168.50.x`
- [x] Wi-Fi client reaches the Internet through Bombs1 NAT
- [x] LuCI system reboot restores AP, mesh, management, upstream DHCP, and Internet
- [ ] Full removal and reapplication of USB-C power restores all services (true cold boot)
- [x] Second node joins `bombs-mesh` and appears as a BATMAN-V neighbor
- [x] Bidirectional sustained application transfers pass (3.15 Mbps toward Bombs1; 4.43 Mbps toward Bombs2 at close range)
- [ ] Bombs2 reboot and cold-power recovery restore its AP and live mesh neighbor without intervention
- [x] Third node joins `bombs-mesh`, directly sees Bombs1 and Bombs2, and passes zero-loss ping to both
- [x] Unsupported fractional-sleep workaround applied and verified on Bombs1, Bombs2, and Bombs3
- [ ] Ten-minute 720p/15 fps H.264 video test passes

Do not configure the next radio as accepted production hardware until the unchecked first-node tests are complete.

## Problem and resolution log

| Problem | Evidence | Resolution |
|---|---|---|
| Connecting to the radio Wi-Fi removed Codex/Internet access | Windows used one Wi-Fi adapter for either the radio or normal Internet | Wired the PC to the router for Internet and reserved Wi-Fi for radio management |
| Router Ethernet initially did not provide PC Internet | PC Ethernet had stale/manual addressing | Restored Ethernet IPv4 and DNS to DHCP using `set-ethernet-dhcp.ps1` |
| Browser firmware upload disappeared mid-process | Factory AP disconnected during the upload/transition | Used direct Ethernet management and verified/flashed `/tmp/firmware.bin` through SSH |
| Firmware compatibility warning | Image/device board names differed in capitalization | Reconfirmed physical V2 marking and used forced sysupgrade with the verified V2 image |
| New OpenMANET address appeared unreachable | Windows routing/DHCP state changed after the wizard | Used temporary Wi-Fi address `10.41.254.2/16` with no gateway and reloaded `10.41.0.1` |
| Green Ethernet LEDs but OpenMANET uplink disconnected | `lan` used `eth0`; live switch traffic was on `eth0.1` | Moved `eth0.1` from `br-ahwlan` to the `lan` DHCP interface |
| Router handed `192.168.50.x` to a client on `Bombs1-24G` | `eth0.1` was bridged into the local AP/mesh LAN | Removing `eth0.1` from `br-ahwlan` restored the intended routed/NAT boundary |
| Browser timed out and Windows did not immediately rejoin during reboot | `Bombs1-24G` disappeared for the expected boot interval, then returned at full signal | Waited without power-cycling, rejoined the saved AP profile, and renewed DHCP; all dashboard and client tests passed |
| Fresh Radio 2 OpenMANET connection displaced wired Internet | Fresh node supplied gateway `10.41.254.1` with route metric 10 while both Windows interfaces had metric 500 | Ran `set-radio-network-priority.ps1` as administrator: Ethernet metric 10, radio Wi-Fi metric 500; first traceroute hop returned to router `192.168.50.1` |
| Bombs2 blinked red and disappeared after initially joining | `Bombs2-24G` and the HaLow neighbor both vanished during a delayed post-wizard restart | Left power connected and did not press Reset; `Bombs2-24G` returned after about 20 seconds and Bombs1 again showed one mesh node at 7.5 Mbps |
| Bombs2 client initially pinged and resolved DNS while external TCP applications stalled | Source-bound ICMP and DNS passed, but TCP sessions intermittently timed out. DF probes from both the mesh client and the PC's direct router Ethernet connection found the same exact IPv4 PMTU ceiling: 1400-byte ICMP payload passed and 1401 failed, proving an upstream 1428-byte path rather than a HaLow-only limit. | Set Bombs1's WAN VLAN device `eth0.1` MTU to 1428 in **Network -> Interfaces -> Devices**. With Windows Wi-Fi restored to MTU 1500, 10/10 HTTPS connections passed. A SYN capture proved Bombs1 rewrote the WAN MSS to 1388 (`1428 - 40`). A 10 MB Internet download then passed at 4.05 Mbps. |
| First temporary SSH keys appeared installed but authentication failed | Dropbear accepted the public-key offer, then rejected the signature | PowerShell/native argument quoting had created passphrased private keys instead of empty-passphrase keys. Generated a clean RSA-3072 key with `.NET ProcessStartInfo.ArgumentList`, verified SSH, and removed all three unusable public-key entries. Only `openmanet-temporary-diagnostics-final` remains temporarily. |
| The MTU helper script was blocked by Windows | PowerShell reported that running scripts is disabled by the system execution policy | Used the equivalent one-time elevated native command: `netsh interface ipv4 set subinterface "Wi-Fi" mtu=1500 store=active`. This changes only the active MTU and does not weaken the system execution policy. |
| Bombs2 failed its first deliberate LuCI reboot recovery test | `Bombs2-24G` remained absent for more than two minutes; `10.41.122.244` stopped answering; Bombs1 showed the last HaLow neighbor update aging out and logged repeated `Phantom meshnode detected` messages | Cold-powering Bombs2 restored its AP and a live 7.2 Mbps HaLow neighbor. A later ordinary-curl test used a temporary `1.1.1.1/32` route through Bombs2 and passed 10/10 HTTPS plus 5/5 HTTP requests; traceroute showed Bombs2, Bombs1, then the upstream router. This proved the earlier source-bound curl failure was a dual-homed Windows test artifact. A subsequent software reboot recovered without cold power, but slowly: the AP returned at about three minutes and the mesh became live around 3:10. |
| HD01 button/LED services consumed nearly all CPU and flooded the log | `/ht-service/checkkey` uses `sleep 0.1`; `/ht-service/checkstatus` uses `sleep 0.3` and `sleep 0.5`; the installed BusyBox `sleep` rejects all fractional values. Bombs3 reproduced the issue with load average 4.71/5.94/3.41, two `checkstatus` loops, and 0% CPU idle. | On every radio, backed up both scripts as `.pre-openmanet-fix`, replaced fractional sleeps with `sleep 1`, syntax-checked them, and left exactly one `checkkey` plus one `checkstatus` process. Bombs3 produced no new sleep errors and returned to 90% idle. The status service is named `/etc/init.d/checkstat` even though the script is `/ht-service/checkstatus`. |
| Bombs3 AP disappeared shortly after its first connection | The client initially joined `Bombs3-24G`, then the AP cycled while the HaLow interface converged; early pings to Bombs1/Bombs2 failed | Left power connected. Windows automatically rejoined, DHCP renewed, and the final test passed 10/10 pings to Bombs1 and 10/10 to Bombs2. Treat a brief first-boot AP cycle as expected, but verify the mesh after it returns. |
| Windows did not automatically rejoin Bombs3 after the deliberate reboot | `Bombs3-24G` was visible at full signal, but `netsh wlan show interfaces` remained disconnected and all IP tests failed | Ran `netsh wlan connect name="Bombs3-24G" interface="Wi-Fi"`, renewed DHCP, then repeated the tests. Do not diagnose the mesh from pings until Windows reports the expected SSID as connected. |
| Camera Ethernet link was up on Bombs2 but no camera IPv4 address appeared | Bombs2 (`10.41.122.244`) learned camera MAC `DC:C2:C9:AE:50:DE` directly on its `eth0.1`, but the camera never sent DHCPv4 and did not appear in `/tmp/dhcp.leases`. | Used the camera's link-local IPv6 address `fe80::dec2:c9ff:feae:50de` on bridge interface `br-ahwlan`. It passed 4/4 local pings at 1-3 ms, and TCP ports 80, 443, and 554 were open. Bombs1 then learned the MAC through `bat0` and passed 4/4 cross-mesh pings at 22-44 ms. The data path works; camera IPv4 configuration, credentials, and RTSP path remain. |
| Entering `10.41.0.50` produced no camera page | `10.41.0.50` was only checked as an unused candidate; it had not been assigned to the camera. The camera had previously been configured on the Peplink `192.168.50.0/24` router network and likely retained that IPv4 configuration or lease when moved to Bombs2. | Bombs1 reservation `camera-bombs2` was created for MAC `DC:C2:C9:AE:50:DE` at `10.41.0.50`. Reconnect the camera temporarily to the Peplink router, power-cycle it, find it under **Status -> Client List**, log into the camera, and select IPv4 DHCP. Return it to Bombs2, power-cycle it, and verify the new `10.41.0.50` lease before using the address. |
| Camera login challenge crossed the mesh but the authenticated settings/video page stalled from Bombs1 or Bombs3 | Small HTTP `401`/Digest responses succeeded, while larger authenticated content loaded immediately only for clients local to Bombs2. Camera and client interfaces used MTU 1500, but `br-ahwlan`/`bat0` use MTU 1460. | Changed the camera Ethernet MTU from 1500 to 1460. The settings page then loaded across the mesh and live 1280x720 video worked through Bombs3, confirming a bridged HaLow MTU black hole rather than an RF association or authentication fault. |
| Camera reservation `.50` failed after an all-equipment cold start | Bombs1's reservation persisted, but its lease file had no camera. Bombs2 learned the camera at `10.41.0.125`, which was reachable and returned the camera login challenge. Each radio was running an active forced DHCP service: Bombs1 pool `.100-.115`, Bombs2 `.116-.131`, and Bombs3 `.100-.115`. | Installed the identical `camera-bombs2` MAC reservation for `DC:C2:C9:AE:50:DE -> 10.41.0.50` on Bombs2 and Bombs3 as well as Bombs1, with dated backups, then reloaded each Mesh Point's `dnsmasq`. The camera must renew DHCP or reboot once; until then it remains reachable at `.125`. The overlapping Bombs1/Bombs3 dynamic pools are a separate OpenMANET configuration risk to resolve before production acceptance. |
| Second camera from an older setup was unknown after connection to Bombs2 | Bombs2 learned new MAC `E0:62:90:A3:0A:4A` directly on `eth0.1` and issued lease `10.41.0.121` with hostname `rtthread`. It passed 4/4 pings at 18-45 ms. HTTP 80 redirected to `/index.html`; HTTPS 443 and standard RTSP 554 were closed. | Use `http://10.41.0.121/index.html` while connected locally to `Bombs2-24G`. The larger page timed out across HaLow after the small redirect, consistent with the known camera MTU problem; set this camera's MTU to 1460 before cross-mesh testing. Do not assume the first camera's RTSP path or protocol applies to this device. |
| Chromium automation would not open the camera's IPv6 link-local or local tunnel URL | Both embedded-browser and Chrome automation returned a client-side block even though `curl` reached the page and received the expected Digest login challenge | Created a loopback-only SSH local forward, first through Bombs2 for discovery and then through Bombs1 to prove the full mesh path. HTTP `127.0.0.1:18080` and RTSP `127.0.0.1:18554` both reached the camera. Enter the HTTP tunnel URL manually, or configure the camera for DHCP/static IPv4 on `10.41.0.0/16` so it has a normal mesh-wide address. |

## Radio 2 flash evidence

Radio 2 factory identity was `HT-HD01-2384`, and its stock dashboard reported `Heltec HT-HD01-V2` with firmware `2.8.5-20260420`. The physical V2 marking and attached 915 MHz antenna were confirmed before flashing.

- The OpenMANET 1.8.0 upload reported 20.25 MiB and SHA-256 `3c515848c9335e2dd9810e6f577b184030c3a3e036e4f3937865a65eff05962f`.
- **Keep settings** was cleared and **Force upgrade** was enabled only for the known capitalization mismatch.
- The old `HT-HD01-2384` SSID disappeared, then `openmanet` appeared at strong signal after the slow post-flash boot.
- Fresh management answered at `10.41.254.1`; login was `root` with a blank password until the initial wizard set an operator password.
- The initial hostname was changed to `Bombs2`.
- Bombs2 was configured as **Mesh Point** on `bombs-mesh`, 2 MHz, channel 42. OpenMANET 1.8.0 forces **Bridge** traffic mode for Mesh Points; Extender and None were disabled. Bridge keeps client devices on the shared `10.41.0.0/16` mesh without an extra NAT layer.
- Its local AP was enabled as `Bombs2-24G` with WPA2/WPA3 mixed mode and an operator-entered passphrase.
- Bombs1 initially showed one node, briefly refreshed to zero during convergence, then showed one node for all six samples over 25 seconds.
- Bombs2 then performed a delayed post-wizard restart: its red LED blinked, AP and mesh neighbor disappeared, `Bombs2-24G` returned after about 20 seconds, and the HaLow node automatically rejoined. Do not interrupt power during this behavior.
- Bombs1 reported the associated HaLow MAC `90:30:D6:33:04:72`, signal `-5 dBm`, noise `-91 dBm`, and approximately 7.5 Mbps average link speed at close bench range.
- A client on `Bombs2-24G` received `10.41.0.123/16`; Bombs2's randomized management/default-gateway address was `10.41.122.244`, with DNS hostname `Bombs2.lan`. Do not assume sequential node addresses—read the client's DHCP gateway.
- From the Bombs2 client, 5/5 pings reached Bombs2 locally, 5/5 crossed HaLow to Bombs1 (`10.41.0.1`), DNS resolved through Bombs2, and 5/5 reached Internet target `1.1.1.1` through the Bombs1 Mesh Gate.
- End-to-end IPv4 path MTU measured 1428 bytes: a 1400-byte ICMP payload plus 28-byte IPv4/ICMP header passed with DF set, while 1401-byte payload failed. The same threshold occurred from the PC's direct router Ethernet connection, so the restriction is on the router/WAN path rather than the HaLow mesh.
- Windows Wi-Fi MTU was temporarily lowered to 1400 and verified operational: a 1372-byte ICMP payload plus 28-byte IPv4/ICMP header passed, while a 1373-byte payload was rejected locally because fragmentation would be required.
- Bombs1 firewall inspection showed NAT enabled on the `lan` uplink zone and MSS clamping enabled on both the `lan` and `ahwlan` zones. The WAN VLAN device itself initially inherited a larger MTU, so Bombs1 did not have the correct route MTU from which to calculate the clamp.
- Set **Network -> Interfaces -> Devices -> eth0.1 -> MTU** to `1428`, then **Save** and **Save & Apply**. Runtime and UCI both reported `eth0.1` at MTU 1428.
- A header-only SYN capture showed the client-side MSS as 1420 and the NAT/WAN-side MSS as 1388. That is the correct IPv4/TCP MSS for a 1428-byte route and proves the existing firewall clamp is acting on the corrected route MTU.
- Read-only SSH inspection on Bombs1 verified IPv4 forwarding enabled, reverse-path filtering disabled on the relevant interfaces, correct routes, NAT on `eth0.1`, and active `ahwlan` to `lan` forwarding. BATMAN-V reported Bombs2 at approximately 7.1 Mbps. No forwarding setting was changed.
- The previously stalled path later recovered without a radio-network change. Five consecutive source-bound HTTP requests returned 301 in 0.18-0.21 seconds, and five HTTPS requests completed TLS and returned 301 in 0.31-0.43 seconds.
- After the radio-side fix and with Windows Wi-Fi at its normal MTU 1500, ten consecutive HTTPS requests returned HTTP 301 in 0.31-0.40 seconds each.
- A source-bound 10 MB HTTPS download completed in 19.74 seconds at 506,560 bytes/second (about 4.05 Mbps).
- A local camera-direction test served 10 MB from the Bombs2 Wi-Fi client to Bombs1 across HaLow at 3.15 Mbps. The reverse direction served 5 MB from Bombs1 to the Bombs2 client at 4.43 Mbps. These are close-range bench results; cap the initial H.264 stream near 1 Mbps and still perform the ten-minute real-video test.
- Windows Wi-Fi was restored to MTU 1500. If a future test changes it, restore it from an elevated PowerShell prompt with the native command (works even when `.ps1` execution is disabled):

```powershell
netsh interface ipv4 set subinterface "Wi-Fi" mtu=1500 store=active
```

- The temporary SSH key `openmanet-temporary-diagnostics-final` must be removed from **System -> Administration -> SSH-Keys** on Bombs1, Bombs2, and Bombs3 after diagnostics are complete.
- Bidirectional application testing passed before reboot. After recovery, a temporary `1.1.1.1/32` route through Bombs2 plus ordinary curl passed 10/10 HTTPS and 5/5 HTTP requests, proving forwarding works and the earlier source-bound curl result was a Windows test artifact. The temporary route must be removed after testing.

## Radio 3 flash and mesh evidence

Radio 3 factory identity was `HT-HD01-CDC2`; its dashboard reported `Heltec HT-HD01-V2` with firmware `2.8.5-20260420`, management `10.42.0.1`, and factory AP MAC `E4:38:19:69:CD:C2`.

- The verified OpenMANET 1.8.0 image had SHA-256 `3c515848c9335e2dd9810e6f577b184030c3a3e036e4f3937865a65eff05962f` and uploaded as 20.25 MiB.
- **Keep settings** was cleared. **Force upgrade** was enabled only for the confirmed capitalization-only board-name mismatch.
- The factory AP disappeared, and fresh `openmanet` appeared about 5.5 minutes after flashing began. Power was not interrupted.
- Bombs3 was configured as **Mesh Point**, forced **Bridge**, mesh `bombs-mesh`, country US, 2 MHz, channel 42, with local WPA2/WPA3 AP `Bombs3-24G`.
- The post-wizard configuration cycle took about four minutes before `Bombs3-24G` appeared. The AP briefly cycled again during HaLow convergence; Windows then rejoined automatically.
- A connected client received `10.41.0.107/16`; Bombs3's management/default-gateway address is `10.41.233.218`. The AP BSSID is `E4:38:19:69:CD:C2`; the HaLow/BATMAN interface MAC is `F8:D8:11:3C:CA:D6`.
- The dashboard reported mesh status active, two connected mesh nodes, and about 7.5 Mbps average. BATMAN-V showed direct neighbors Bombs1 at 7.1 Mbps and Bombs2 at 7.2 Mbps.
- Post-fix ping passed 10/10 locally (2-8 ms), 10/10 to Bombs1 across HaLow (11-38 ms), and 10/10 to Bombs2 (20-48 ms).
- Before the service workaround, CPU was 0% idle and load average reached 4.71/5.94/3.41. After backing up and patching both service scripts, no fractional sleeps or new errors remained, exactly one watcher of each type ran, and CPU was 90% idle.
- A deliberate software reboot was genuine: the AP disappeared, returned after about 3:08, and required an explicit Windows profile reconnect. The same management address, both BATMAN neighbors, temporary SSH key, and both service-script fixes survived. Initial startup load was high, but CPU returned to 90% idle by eight minutes.
- After reboot and convergence, ping again passed 10/10 locally, 10/10 to Bombs1, and 10/10 to Bombs2.
- A 10 MB client-to-Bombs1 transfer completed end-to-end in 20.50 seconds (about 3.90 Mbps); the payload writer reported 4.65 Mbps. The reverse 10 MB Bombs1-to-client transfer completed in 18.95 seconds at 527,667 bytes/second (about 4.22 Mbps). The temporary HTTP server, payload, log, and PID files were removed.
- True cold-power recovery and the ten-minute video test remain pending for Bombs3.

## First wired-camera discovery evidence

The first camera was connected by Ethernet to Bombs2 on 2026-08-20 while Bombs1 remained the Mesh Gate and router uplink. Bombs3 was intentionally powered off and was not part of this first video-path test.

- Bombs2 reported carrier `1`; `ethtool eth0` reported **Link detected: yes**, and `eth0.1` was `UP/LOWER_UP`.
- The camera MAC `DC:C2:C9:AE:50:DE` was learned directly on Bombs2's `eth0.1` bridge port. RX and TX counters increased, proving two-way Layer-2 activity.
- The camera did not request DHCPv4, so it received no `10.41.x.x` lease. Do not assume that an illuminated Ethernet LED means an IPv4 camera address exists.
- A 20-second capture showed IPv6 router solicitations from link-local address `fe80::dec2:c9ff:feae:50de`. From Bombs2, `ping6 -I br-ahwlan` returned 4/4 replies with 1.1-3.1 ms latency.
- From the setup PC on `Bombs2-24G`, the same scoped address (`fe80::dec2:c9ff:feae:50de%3`, where interface index 3 was Windows Wi-Fi) returned 3/3 pings at 2-8 ms.
- Bombs1 learned the camera MAC on `bat0`, proving it arrived from the HaLow/BATMAN mesh rather than Bombs1's local Ethernet. Bombs1 reached the camera with 4/4 IPv6 pings at 21.6-44.0 ms. This confirms the complete camera-to-Bombs2-to-HaLow-to-Bombs1 data path.
- After the camera was changed to DHCP, Bombs1 issued the reserved lease `10.41.0.50` to MAC `DC:C2:C9:AE:50:DE`. Bombs1 reached it 4/4 at 15.5-28.5 ms.
- A phone joined `Bombs3-24G` as randomized MAC `86:C0:28:98:9B:6A`, received `10.41.0.109`, and associated at `-43 dBm`. Bombs3 had live direct BATMAN neighbors to Bombs1 and Bombs2 at approximately 7.1 Mbps.
- Bombs3 reached the camera at `10.41.0.50` with 4/4 pings at 14.3-34.1 ms. A raw HTTP request from Bombs3 received an immediate `307` redirect to `/admin/`. This proves phone AP, Bombs3, HaLow, Bombs2 Ethernet, and camera IPv4 connectivity; a phone page that continues loading is a browser/authentication/video-format issue rather than a mesh failure.
- Service probing found HTTP 80, HTTPS 443, and RTSP 554 open. HTTP redirected `/` to `/admin/`; `/admin/` returned a Digest authentication challenge with realm `Administrator`. No password was recorded or exposed.
- An RTSP `OPTIONS` request to `/` returned `404 Not Found`, so the camera is live but its vendor-specific stream path remains unknown.
- `tcpdump-mini` and dependency `libpcap1` were installed temporarily on Bombs2 because the base image had no packet-capture utility. `opkg update` returned a nonzero status only because three obsolete optional feeds (`gateworks`, `morse`, and duplicate `openmanet`) returned not found; the valid base/package indexes and signatures completed successfully.
- Chromium browser control refused private/local tunnel URLs even though command-line HTTP checks passed. A temporary tunnel can expose the camera page while diagnostics are active:

```powershell
ssh.exe -N `
  -i '.\openmanet_diag_rsa_nopass' `
  -o BatchMode=yes `
  -o StrictHostKeyChecking=yes `
  -o 'UserKnownHostsFile=.\openmanet_diag_known_hosts' `
  -L '127.0.0.1:18080:[fe80::dec2:c9ff:feae:50de%br-ahwlan]:80' `
  -L '127.0.0.1:18554:[fe80::dec2:c9ff:feae:50de%br-ahwlan]:554' `
  root@10.41.0.1
```

Then manually open `http://127.0.0.1:18080/admin/`. Once the vendor-specific stream path is known, a local player can use `rtsp://127.0.0.1:18554/<stream-path>`. Keep that SSH window open.

Bombs1's `ahwlan` DHCP pool is `10.41.0.100-10.41.0.115`. Address `10.41.0.50` did not answer three pings and remained an incomplete neighbor during the 2026-08-20 check, so it is the current candidate reserved address. **This check did not assign the address to the camera.** The preferred resolution is to put the camera in DHCP mode, create a Bombs1 reservation mapping MAC `DC:C2:C9:AE:50:DE` to `10.41.0.50`, reconnect/power-cycle the camera on Bombs2, and verify the resulting lease. If camera firmware requires manual static configuration instead, use IPv4 `10.41.0.50`, prefix `/16` (netmask `255.255.0.0`), gateway `10.41.0.1`, and DNS `10.41.0.1` only after rechecking the address is unused.

Bombs1 DHCP reservation applied on 2026-08-20:

```text
dhcp.camera_bombs2=host
dhcp.camera_bombs2.name='camera-bombs2'
dhcp.camera_bombs2.mac='DC:C2:C9:AE:50:DE'
dhcp.camera_bombs2.ip='10.41.0.50'
```

The prior radio configuration is backed up at `/etc/config/dhcp.pre-camera-reservation-20260820`. `dnsmasq` reloaded successfully without rebooting Bombs1. The reservation remains inactive until the camera is changed from its prior Peplink/static configuration to DHCP.

On the 2026-08-21 cold-start test, Bombs1's reservation survived but the camera appeared at `10.41.0.125` with no Bombs1 lease. Bombs2's active forced DHCP pool covers `.116-.131`, while Bombs1 and Bombs3 both advertised the overlapping `.100-.115` pool. To make the camera deterministic regardless of which radio responds first, the same named reservation was added to Bombs2 and Bombs3:

```text
dhcp.camera_bombs2=host
dhcp.camera_bombs2.name='camera-bombs2'
dhcp.camera_bombs2.mac='DC:C2:C9:AE:50:DE'
dhcp.camera_bombs2.ip='10.41.0.50'
```

Backups on Bombs2 and Bombs3 are `/etc/config/dhcp.pre-camera-reservation-20260821`. The camera remained continuously reachable at `.125` during a three-minute watch, proving it had not yet restarted or renewed. Power-cycle only the camera or use its settings-page reboot, then verify `.50` before declaring address persistence passed.

### First live-video field observations

After changing the camera MTU to 1460, the operator confirmed that the camera settings and live 1280x720 stream loaded through the mesh:

- Approximately 10 fps at about 30 ft with one wall in the path.
- Approximately 2 fps outdoors at about 150 ft with multiple walls in the path.
- Camera was wired to Bombs2; the viewing phone used Bombs3's 2.4 GHz AP.
- These are operator-observed frame rates. Stream codec, encoded bitrate, keyframe interval, exact wall construction, test duration, RSSI, and BATMAN throughput were not captured for this run.
- The successful 1460-byte camera MTU change confirms that the earlier post-login stall was caused by oversized TCP traffic on the 1460-byte bridged mesh path.

Treat this as functional video proof, not the final ten-minute acceptance test. Before changing RF bandwidth or channel, reduce and record the encoder load: H.264, 1280x720, 8-10 fps, constant bitrate around 500-800 kbps, keyframe interval 1-2 seconds, and audio disabled unless required. If the 150 ft/multi-wall case remains unacceptable, test a 640x360 or 640x480 substream around 300-500 kbps. Change only one encoder variable at a time and record results.

### Second wired-camera discovery

On 2026-08-21, a different camera from an older setup replaced the first camera on Bombs2's Ethernet cable:

- MAC `E0:62:90:A3:0A:4A` was learned directly on Bombs2 `eth0.1`; the old `DC:C2:C9:AE:50:DE` entries were stale neighbor history.
- Bombs2 DHCP assigned `10.41.0.121` and recorded hostname `rtthread`.
- The setup PC reached it 4/4 at 18-45 ms through the mesh.
- HTTP port 80 returned `302` to `http://10.41.0.121/index.html`.
- HTTPS 443 and standard RTSP 554 did not accept connections. The authenticated **Port** page later showed that this camera uses RTSP port `8554`, not `554`.
- The 2694-byte index page did not complete across the mesh, while the small redirect did. Configure MTU 1460 from a client local to `Bombs2-24G`, then repeat web and video discovery.
- The second camera was assigned `.51`; do not reuse `.50` while the first camera reservation remains active.
- The second camera was intended to be configured static at `10.41.0.51/16`, gateway/DNS `10.41.0.1`, and connected to Bombs2. An authenticated readback on 2026-08-21 initially showed subnet mask `255.255.255.0` (`/24`) and **IP Self-Adaption** still enabled. The mask was corrected to `255.255.0.0`, IP Self-Adaption was disabled, and an authenticated reload verified both changes persisted. DHCP remains off; gateway/DNS remain `10.41.0.1`. From the router-only PC (`192.168.50.144`), direct `.51` access was correctly blocked by the routed/NAT boundary, while Bombs1's uplink `192.168.50.183` accepted authenticated SSH.
- Bombs1 reached camera `.51` with 4/4 pings at 20-32 ms and learned MAC `E0:62:90:A3:0A:4A`. A loopback-only SSH forward `127.0.0.1:18081 -> Bombs1 -> 10.41.0.51:80` returned the full 2694-byte Jovision login page. Use `open-camera2-from-router.cmd` while the PC is connected only to the Peplink router, keep its window open, and browse to `http://127.0.0.1:18081/index.html`.
- The page identifies a Jovision/CloudSEE-style camera. Authenticated read-only inspection found CloudSEE transport port `18320`, HTTP `80`, and RTSP `8554`. A loopback RTSP tunnel `127.0.0.1:18554 -> Bombs1 -> 10.41.0.51:8554` reached the RTSP server and received the expected `401 Unauthorized` challenge without credentials, proving the service path is alive.
- The camera's web viewer embeds the retired VLC ActiveX/NPAPI browser plug-in and redirected the iframe to a VLC 3.0.3 download page. Modern Chromium browsers cannot render that plug-in. Use a current desktop VLC/ffplay/ONVIF client against the RTSP service instead of expecting video inside LuCI or the camera's web configuration page.
- Firmware JavaScript shows the camera obtains stream URLs through `get_stream_url` and contains the vendor path forms `live0.264`/`live0.h264`; confirm the authenticated main/substream URL in a desktop player. Never record camera credentials in this guide or embed them in a helper command.
- Current encoder readback: main stream H.265, `2304x1296`, 25 fps, VBR Good, 3072 kbps; substream H.265, `720x480`, 25 fps, VBR Good, 512 kbps. For mesh testing, prefer the substream first. For broad player compatibility and reduced mesh load, test H.264 at 10-15 fps and a controlled bitrate before increasing quality.
- The secure `open-camera2-video.cmd` launcher successfully queried the camera's authenticated `get_stream_url` API and opened decoded video with FFplay. The confirmed low-bandwidth stream path is `/profile1`, not the firmware's example `live1.264` path. The direct mesh URL format is `rtsp://10.41.0.51:8554/profile1`; let the player prompt for credentials, or add the username and operator-entered password locally if the player requires URL credentials. Do not put the password in this guide.
- A phone associated with `Bombs1-24G`, `Bombs2-24G`, or `Bombs3-24G` should use the camera's direct mesh address, not the PC's `127.0.0.1` tunnel. In VLC Mobile choose **Network / Open Network Stream** (or **New Stream**) and open `rtsp://10.41.0.51:8554/profile1`. If the phone warns that the Wi-Fi has no Internet, choose to remain connected and disable automatic switching to cellular for the test. Confirm the phone received a `10.41.x.x/16` address.
- During the first phone attempt, the Galaxy S24 changed its per-network randomized MAC from the earlier `86:C0:28:98:9B:6A`/`.109` identity to `EA:AB:9D:40:C8:AB` and received `10.41.0.123` from Bombs2. Bombs2 showed it actively associated at -42 dBm and about 60.2 Mbps expected 2.4 GHz throughput. The camera MAC was learned through Bombs3; Bombs2 reached `10.41.0.51` 6/6 times at 18-48 ms. Therefore the failed mobile playback was not an Internet dependency or broken RF mesh path; continue by verifying the camera HTTP login page from the phone, then check embedded RTSP credentials and H.265 client support.
- The phone still could not load even the camera HTTP page. Inspection showed `phy0-ap0` at MTU 1500 while `bat0`, `eth0`, and `eth0.1` were MTU 1460. This is the same oversized-TCP failure class previously fixed at the first camera. DHCP option 26 (`1460`) was therefore added to `dhcp.ahwlan.dhcp_option` on Bombs1, Bombs2, and Bombs3, with `/etc/config/dhcp.pre-phone-mtu-20260821` backups, and dnsmasq was restarted. Reconnect each phone/client Wi-Fi after this change so it accepts MTU 1460 before repeating HTTP and RTSP tests.
- After reconnecting, the phone successfully played `/profile1`. A dependency-free **Bombs Camera** launcher was installed on Bombs1 at `/www/camera`; Bombs2 and Bombs3 each fetched the complete 1891-byte page successfully. From an Android phone on any node, open `http://10.41.0.1/camera/`, enter the camera password once, allow VLC to open, then use the browser's **Add to Home screen** command. Later icon taps automatically send the authenticated RTSP URI to the VLC Android package and show one fallback **Open camera** button if Android blocks automatic handoff.
- The launcher source is under `camera-launcher-webapp/radio/`. It contains no camera password. The operator-entered password is stored only in that phone browser's local storage so one-tap launching is possible; use a camera-only password and tap **Change camera password** in the launcher after rotating it. Because the app is served over the isolated radio's plain HTTP address, some browsers will create a home-screen shortcut instead of labeling it an installable PWA; the shortcut is sufficient and still uses the supplied Bombs Camera icon.

Before final acceptance, remove temporary capture packages if they are no longer needed and verify no other installed package depends on `libpcap1`:

```sh
opkg remove tcpdump-mini
opkg remove libpcap1
```

The second camera's ten-minute video test is still pending. Its RTSP service is confirmed on port 8554, the `/16` mask correction is verified, and authenticated FFplay video succeeded on `/profile1` through the Bombs1 loopback tunnel. VLC 3.0.23 failed RTSP session setup on the guessed `live0.264` and `live0.h264` paths; the guesses were wrong for this firmware. For a router-side pull client, use `open-camera2-video.cmd` and keep the SSH tunnel open during testing, then configure a narrowly scoped RTSP port forward or router route/firewall rule on Bombs1 if permanent router-side viewing is required. A camera-initiated push stream can traverse Bombs1's existing NAT without an inbound port forward.

## Reboot recovery evidence

The LuCI **Perform reboot** test completed successfully on 2026-08-19:

- `Bombs1-24G` disappeared and the setup PC disconnected, proving the radio actually restarted.
- The AP returned after the HT-HD01's slow boot interval and Windows rejoined the saved profile.
- The client retained/reacquired `10.41.0.107/16` with gateway and DNS `10.41.0.1`.
- The dashboard showed mesh `bombs-mesh` active, local network `10.41.0.1/16`, Ethernet device `eth0.1` connected, upstream `192.168.50.183`, one DHCP lease, and one AP client.
- Source-bound client ping to `1.1.1.1` again returned 4/4 replies.
- Source-bound HTTPS connectivity check again returned HTTP 204.

This proves configuration persistence through an operating-system reboot. A true cold-boot acceptance test still requires removing USB-C power, waiting several seconds, reconnecting power, and repeating the same checks.

## Next-node rules

- Give every radio a unique hostname and client AP SSID.
- Use the exact same mesh ID, mesh passphrase, country, width, and channel on all nodes.
- Use only one Mesh Gate unless OpenMANET documentation for the installed release explicitly supports the intended multi-gate design.
- Configure relay-only nodes as mesh points with no uplink and disable their 2.4 GHz AP unless a local client needs it.
- After each new node, verify direct neighbors, BATMAN-V originators, bidirectional ping, throughput, reboot recovery, and then video.
- Change only one RF or encoder variable per field test and record the result in `RADIO_SETUP_LOG.csv`.
