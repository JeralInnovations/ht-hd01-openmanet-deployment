# HT-HD01 V2 OpenMANET Deployment

Private deployment notes and operator tooling for an HT-HD01 V2 OpenMANET
HaLow mesh with a local IP-camera video feed.

## What this repository is

This is an independent **deployment/configuration repository**, not a fork of
OpenMANET. It records the firmware baseline, radio roles, network settings,
Windows recovery utilities, test results, and a small phone camera launcher.
It does not contain or modify the upstream OpenMANET source tree.

If OpenMANET source is later cloned and changed, that source repository should
be maintained as an actual fork. Changes made through LuCI, UCI, DHCP, routing,
or local helper scripts belong here as deployment configuration.

## Start here

1. Read [HT-HD01_V2_OPENMANET_REPLICATION_GUIDE.md](HT-HD01_V2_OPENMANET_REPLICATION_GUIDE.md).
2. Confirm every radio is physically marked **V2** before flashing.
3. Obtain the exact approved OpenMANET image separately.
4. Verify it against [firmware/SHA256SUMS.txt](firmware/SHA256SUMS.txt).
5. Record new radio settings in [RADIO_SETUP_LOG.csv](RADIO_SETUP_LOG.csv).
6. Record camera identity and reservations in [CAMERA_INVENTORY.csv](CAMERA_INVENTORY.csv).

The broader design and remaining work are tracked in
[OPENMANET_HT-HD01_V2_VIDEO_PLAN.md](OPENMANET_HT-HD01_V2_VIDEO_PLAN.md).

## Included tooling

- `set-*.ps1` - Windows interface, DHCP, route, metric, and MTU helpers.
- `mesh-throughput-http-server.ps1` - dependency-free mesh throughput target.
- `open-camera2-video.*` - credential-prompted local camera stream launcher.
- `open-camera*-*.cmd` - SSH tunnel helpers for the recorded test topology.
- `radio-tools/` - checked, reversible radio-side firmware workarounds.
- `camera-launcher-webapp/radio/` - dependency-free phone launcher deployed to
  the radio web root.

Most network-changing PowerShell helpers require an elevated terminal. Review
their interface aliases and addresses before running them on another computer.

## Security and excluded files

This repository intentionally excludes:

- operator passwords and camera passwords;
- private SSH keys and known-host state;
- exported Wi-Fi profiles;
- generated diagnostic/result files;
- the OpenMANET firmware binary; and
- experimental Android application repositories and build output.

Store operational credentials in the approved password manager. Generate a new
SSH key pair for each deployment rather than sharing a private key through Git.

## Firmware baseline

- Hardware: Heltec HT-HD01 **V2**, MM6108
- Recorded firmware: OpenMANET 1.8.0
- Image name: `openmanet-1.8.0-heltec_ht-hd01-v2-mm6108-squashfs-sysupgrade.bin`

The checksum file is the integrity reference. The firmware binary is not
redistributed by this repository.
