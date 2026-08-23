# OpenMANET HT-HD01 V2 Video Mesh Plan

Prepared: 2026-08-19 (US/Colorado assumptions)

> Live build note: the first unit was configured as Mesh Gate `Bombs1` on mesh `bombs-mesh`, not the original self-contained `halo-video` example below. Use `HT-HD01_V2_OPENMANET_REPLICATION_GUIDE.md` as the source of truth for the actual flash, wizard values, HT-HD01 VLAN correction, troubleshooting, and current acceptance status.

## Goal

Build a repeatable HT-HD01 V2 HaLow mesh that transports one low-latency video feed, prove it on the bench, prove it survives reboots, and only then add relay nodes or raise video quality.

## Safety stop before flashing

- Confirm every unit is marked **HT-HD01 V2** on the device. Do not flash an unmarked unit or a V1. OpenMANET explicitly warns that the V2 image may not work on V1 and may brick it.
- Attach the 915 MHz antenna before applying power or transmitting.
- Use a stable 5 V USB-C supply and a sound cable. USB-C is power; routine flashing/configuration is through Wi-Fi and a web browser.
- Configure one stock radio at a time so identical factory SSIDs and gateway addresses cannot be confused.
- Select the actual regulatory country. This plan assumes **US**.

## Prepared firmware

- Release: OpenMANET 1.8.0
- Board image: `firmware/openmanet-1.8.0-heltec_ht-hd01-v2-mm6108-squashfs-sysupgrade.bin`
- Expected SHA-256: `3c515848c9335e2dd9810e6f577b184030c3a3e036e4f3937865a65eff05962f`
- Local verification on 2026-08-19: **matched**

This image is specifically for `heltec_ht-hd01-v2` and includes the required `bcf_HD01_v2.bin` radio calibration file.

## Recommended topology

For a self-contained video link, start with **no Mesh Gate**:

| Unit | Hostname | Role and mode | Client AP | Attached equipment |
|---|---|---|---|---|
| 1 | `video-src-01` | Mesh Point / Extender | `video-src-01-24G` | IP camera/encoder by Ethernet or Wi-Fi |
| 2 | `video-view-01` | Mesh Point / Extender | `video-view-01-24G` | Viewer laptop/tablet by Ethernet or Wi-Fi |
| 3+ | `video-relay-01`, etc. | Mesh Point / No uplink (mesh-only) | Disabled unless needed | Relay only |

Use a **Mesh Gate** only if the mesh needs Internet or another upstream network. OpenMANET currently expects one gate. On an HT-HD01, an Ethernet gate uses the unit's only Ethernet port as WAN, so do not make the camera's Ethernet-attached node the gate.

## Common mesh settings

Every node must use exactly the same values in this section:

| Setting | Baseline value | Reason |
|---|---|---|
| Mesh ID | `halo-video` | Shared mesh name; change once now if desired |
| Encryption | WPA3 (SAE) | Encrypted 802.11s mesh |
| Mesh passphrase | Record offline; 16+ random characters | Must match on every node |
| Country | `US` | Legal US channel list |
| Bandwidth | `2 MHz` | Conservative, documented baseline |
| Channel | `42` (923 MHz) | Fixed documented baseline; never Auto |

Do not use 8 MHz for the initial build; the OpenMANET setup documentation explicitly advises against 8 MHz and Auto channel. If bench testing proves 2 MHz is the video bottleneck, retest all nodes together at **4 MHz / channel 40 (922 MHz)**. Never mix bandwidths or channels within one mesh.

## Stage 1 - Inventory and preflight

- [ ] Count the radios and assign a physical label to each.
- [ ] Photograph or read the model marking and record `V2` for every unit.
- [ ] Record each MAC address/serial label if present.
- [ ] Confirm each antenna is for the US 915 MHz band and is attached.
- [ ] Decide the video source: RTSP IP camera, phone, SBC, or other encoder.
- [ ] Decide whether the source uses Ethernet or the radio's 2.4 GHz client AP.
- [ ] Decide whether Internet/upstream access is required. Default: no.
- [ ] Choose and securely record the mesh, client-AP, and admin passwords. Do not put live passwords in this repository.

Gate: do not flash until the V2 marking is positively confirmed.

## Stage 2 - Flash the first radio

1. Power only Radio 1 with its antenna attached.
2. On Windows, join the stock HT-HD01 Wi-Fi. Factory Wi-Fi password: `heltec.org`.
3. Open Wi-Fi Properties and note **IPv4 default gateway**, or run `ipconfig` in PowerShell and find the Wi-Fi Default Gateway.
4. Browse to `http://<default-gateway>` and log in. The stock password should be `heltec.org`.
5. Close the opening overlay with the **X** at upper right.
6. Open **System -> Reset / Flash Firmware**.
7. Select **Flash Image**, then **Browse**.
8. Select only `openmanet-1.8.0-heltec_ht-hd01-v2-mm6108-squashfs-sysupgrade.bin`.
9. Select **Upload**.
10. On the confirmation page, uncheck **Keep settings and retain the current configuration**.
11. Check **Force Upgrade** only after reconfirming that the physical unit says V2.
12. Select **Continue**. Do not remove power or press Reset.
13. Wait a full 10 minutes. The HT-HD01 processor and web UI are slow; patience is expected.
14. When the `openmanet` Wi-Fi appears, join it with password `openmanet`.
15. Browse to `http://10.41.254.1`. If that does not answer, check the Wi-Fi default gateway and browse to it.

Gate: the `openmanet` SSID must appear and the OpenMANET setup wizard must load.

## Stage 3 - Run the first-radio wizard

Use these screens and values:

1. **Identity & Role**
   - Hostname: `video-src-01`
   - Role: **Mesh Point**
2. **Mesh Configuration**
   - Mesh radio: leave the detected HaLow radio selected
   - Mesh ID: `halo-video`
   - Encryption: **WPA3 (SAE)**
   - Mesh passphrase: the shared mesh passphrase
   - Country: **US**
   - Bandwidth: **2 MHz**
   - Channel: **42**
   - Mesh point mode: **Extender (bridges Wi-Fi clients onto the mesh)**
3. **Client Device Wi-Fi**
   - Enable the non-HaLow 2.4 GHz AP
   - SSID: `video-src-01-24G`
   - Encryption: WPA2/WPA3 mixed if all endpoints support it; otherwise WPA2
   - AP passphrase: record offline
4. **Admin Password**
   - Set and record a password of at least 8 characters; use 16+ characters in practice
5. **Review & Apply**
   - Confirm role, mesh ID, country, channel/bandwidth, encryption, and AP SSID
   - Apply; losing the browser connection while networking reloads is expected
6. Reconnect to `video-src-01-24G`, renew DHCP if needed, and try:
   - `https://video-src-01.local:8081/login`
   - the new `10.41.x.x` address shown after setup

Gate: log back into the node after its automatic reboot and record its assigned address.

## Stage 4 - Flash and configure the remaining radios

- Leave the configured first node powered and nearby while later nodes finish their wizard/address reservation.
- Flash each stock unit separately using the same verified image and the same precautions.
- Give every unit a unique hostname and unique client AP SSID.
- Copy the mesh ID, mesh passphrase, country, bandwidth, and channel exactly.
- Choose **Extender** only for source/viewer nodes that need a 2.4 GHz client AP.
- Choose **No uplink (mesh-only)** and disable client APs on relay-only nodes.
- Do not configure a Mesh Gate unless an upstream Internet/LAN connection is actually required.
- Record results in `RADIO_SETUP_LOG.csv`.

Gate: all nodes appear in the topology/neighbor view, have unique addresses, and remain reachable after every node is power-cycled.

## Stage 5 - Prove the network before video

1. Put the source and viewer radios on the same bench, antennas separated by at least a few feet.
2. Connect the viewer computer to `video-view-01-24G` or its Ethernet port.
3. Verify that Windows receives a `10.41.x.x` address.
4. Ping both node hostnames/addresses for at least 50 packets.
5. From a node SSH shell, inspect:
   - `batctl n` for direct neighbors
   - `batctl o` for BATMAN-V originators/routes
   - `batctl dc` for mesh/client address visibility
6. Power-cycle both nodes, reconnect the viewer, and repeat the reachability test.

Acceptance gate:

- 50/50 replies on the bench, or no more than one isolated lost packet during convergence
- both nodes visible to BATMAN-V
- management UI and addressing recover after a cold reboot

## Stage 6 - Add one controlled video feed

The HT-HD01 transports IP packets; it does not encode a camera itself. Start with one hardware-encoded H.264 stream:

| Encoder setting | Initial value |
|---|---|
| Resolution | 1280 x 720 |
| Frame rate | 15 fps |
| Rate control | CBR |
| Video bitrate | 800-1200 kbps |
| Keyframe/GOP interval | 1 second |
| Audio | Off initially |
| Concurrent viewers | 1 |

- Give a wired IP camera a DHCP reservation or a static address in OpenMANET's safe `10.41.253.0/24` or `10.41.254.0/24` ranges.
- First prove its RTSP feed locally at the source node.
- Then view the exact same RTSP URL from the receiver side of the mesh.
- This PC already has FFmpeg/FFplay. A typical test is:

  `ffplay -rtsp_transport tcp -fflags nobuffer -flags low_delay rtsp://<camera-ip>/<camera-path>`

- After reliable TCP viewing, try UDP for lower latency if the camera/player supports it:

  `ffplay -rtsp_transport udp -fflags nobuffer -flags low_delay rtsp://<camera-ip>/<camera-path>`

Acceptance gate:

- 10 minutes of continuous bench video
- no freeze longer than 2 seconds
- usable latency for the intended task
- management access remains responsive during the stream
- stream automatically recovers after restarting the source, receiver, and both radios

## Stage 7 - Add relays and field distance

1. Add only one relay node at a time.
2. Confirm in `batctl o` or the topology view that traffic is actually taking the relay path; mere presence of three radios does not prove multi-hop routing.
3. Repeat the 10-minute video test and record loss, latency, bitrate, and link metrics.
4. Raise antennas, preserve line of sight/Fresnel clearance, and keep antennas vertical and away from the computer, battery, metal, and the 2.4 GHz antenna.
5. If video quality is limited at good signal, test every node at 4 MHz/channel 40 and compare.
6. If range/reliability is limited, keep 2 MHz/channel 42 and reduce the stream toward 500-800 kbps before considering 1 MHz.

Do not change bandwidth, channel, video bitrate, antenna, and topology in the same test. Change one variable, rerun the acceptance test, and log the result.

## Recovery rules

- During a normal V2 flash, wait at least 10 minutes before concluding it failed.
- If neither the stock nor `openmanet` SSID appears, do not repeatedly power-cycle or flash another board image. Stop and diagnose the exact LED/network behavior first.
- Avoid hand-editing OpenWrt network files during the initial build. If configuration becomes inconsistent, use the supported clean reset/reflash workflow and rerun the wizard.
- Keep all nodes on the same OpenMANET release; upgrade the whole set together.

## Live setup workflow with this computer

When a confirmed V2 unit is ready:

1. Connect its 915 MHz antenna.
2. Power it by USB-C near this computer.
3. Say `Radio 1 is powered and marked V2`.
4. We will inspect the Windows Wi-Fi/gateway state, open the correct local page, and walk screen-by-screen through the flash and wizard.
5. We will stop after each acceptance gate and record the resulting hostname, address, role, and test outcome before moving to the next unit.
