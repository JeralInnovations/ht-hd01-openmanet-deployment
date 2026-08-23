# HT-HD01 V2 radio-side tools

## Fractional-sleep firmware workaround

OpenMANET 1.8.0 on the tested HT-HD01 V2 image runs fractional `sleep`
commands in `/ht-service/checkkey` and `/ht-service/checkstatus`. The installed
BusyBox `sleep` rejects those values, causing tight error loops, excessive load,
and near-zero CPU idle time.

The script `fix-ht-service-fractional-sleep.sh` performs the recorded workaround
without embedding credentials. It is intentionally conservative:

- defaults to a read-only check;
- requires both expected radio files;
- builds and syntax-checks both patched copies before installation;
- preserves one-time `.pre-openmanet-fix` backups;
- replaces only `sleep 0.1`, `sleep 0.3`, and `sleep 0.5`;
- rejects any unrecognized fractional sleep;
- restarts `checkkey` and `checkstat`; and
- can restore both original backups.

This is a runtime firmware workaround, not an upstream OpenMANET source patch.
Reapply it after a clean reflash or factory reset unless a later firmware image
has corrected the defect.

### Copy and run

From the repository directory on a management computer, replace `<RADIO_IP>`
with the current radio management address:

```powershell
scp .\radio-tools\fix-ht-service-fractional-sleep.sh root@<RADIO_IP>:/tmp/
ssh root@<RADIO_IP> "sh /tmp/fix-ht-service-fractional-sleep.sh --check"
ssh root@<RADIO_IP> "sh /tmp/fix-ht-service-fractional-sleep.sh --apply"
```

Run those commands separately for every radio. Enter credentials locally when
prompted; do not add passwords or private keys to the repository.

Run the check again after applying:

```powershell
ssh root@<RADIO_IP> "sh /tmp/fix-ht-service-fractional-sleep.sh --check"
```

Expected result: both files report `OK: no fractional sleeps`.

### Restore

If rollback is required:

```powershell
ssh root@<RADIO_IP> "sh /tmp/fix-ht-service-fractional-sleep.sh --restore"
```

Restoring reintroduces the original fractional-sleep behavior. Use it only for
diagnosis or before installing a vendor-provided replacement.

### Post-fix acceptance checks

On each radio, verify:

```sh
logread | grep -i 'sleep'
ps | grep -E '[c]heckkey|[c]heckstatus'
top -bn1 | head -n 5
```

The tested radios had exactly one watcher of each type, stopped producing new
fractional-sleep errors, and recovered to approximately 90 percent CPU idle.
