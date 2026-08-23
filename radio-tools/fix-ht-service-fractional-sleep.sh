#!/bin/sh
# OpenMANET 1.8.0 HT-HD01 V2 runtime workaround for BusyBox fractional sleeps.

set -eu

MODE="${1:---check}"
SERVICE_DIR="${HT_SERVICE_DIR:-/ht-service}"
INIT_DIR="${HT_INIT_DIR:-/etc/init.d}"
BACKUP_SUFFIX='.pre-openmanet-fix'
KEY_SCRIPT="${SERVICE_DIR}/checkkey"
STATUS_SCRIPT="${SERVICE_DIR}/checkstatus"
KEY_BACKUP="${KEY_SCRIPT}${BACKUP_SUFFIX}"
STATUS_BACKUP="${STATUS_SCRIPT}${BACKUP_SUFFIX}"
KEY_TEMP="/tmp/checkkey.openmanet-fix.$$"
STATUS_TEMP="/tmp/checkstatus.openmanet-fix.$$"

cleanup() {
    rm -f "$KEY_TEMP" "$STATUS_TEMP"
}

trap cleanup EXIT HUP INT TERM

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: fix-ht-service-fractional-sleep.sh [--check|--apply|--restore]

  --check    Inspect both HT service scripts without changing them (default).
  --apply    Back up, patch, syntax-check, install, and restart the services.
  --restore  Restore both original .pre-openmanet-fix backups and restart.
EOF
}

require_script() {
    [ -f "$1" ] || fail "Required script not found: $1"
    [ -r "$1" ] || fail "Required script is not readable: $1"
}

require_writable_script() {
    [ -w "$1" ] || fail "Required script is not writable; run as root: $1"
}

has_fractional_sleep() {
    grep -Eq 'sleep[[:space:]][[:space:]]*0\.[0-9]+' "$1"
}

has_known_defect() {
    grep -Eq 'sleep[[:space:]][[:space:]]*0\.(1|3|5)([^0-9]|$)' "$1"
}

report_file() {
    if has_known_defect "$1"; then
        echo "FIX REQUIRED: $1"
        grep -nE 'sleep[[:space:]][[:space:]]*0\.(1|3|5)([^0-9]|$)' "$1" || true
    elif has_fractional_sleep "$1"; then
        echo "REVIEW REQUIRED: unexpected fractional sleep remains in $1" >&2
        grep -nE 'sleep[[:space:]][[:space:]]*0\.[0-9]+' "$1" >&2 || true
    else
        echo "OK: no fractional sleeps in $1"
    fi
}

make_patched_copy() {
    sed \
        -e 's/sleep[[:space:]][[:space:]]*0\.1\([^0-9]\)/sleep 1\1/g' \
        -e 's/sleep[[:space:]][[:space:]]*0\.1$/sleep 1/' \
        -e 's/sleep[[:space:]][[:space:]]*0\.3\([^0-9]\)/sleep 1\1/g' \
        -e 's/sleep[[:space:]][[:space:]]*0\.3$/sleep 1/' \
        -e 's/sleep[[:space:]][[:space:]]*0\.5\([^0-9]\)/sleep 1\1/g' \
        -e 's/sleep[[:space:]][[:space:]]*0\.5$/sleep 1/' \
        "$1" > "$2"

    /bin/sh -n "$2" || fail "Patched syntax check failed for $1"
    if has_fractional_sleep "$2"; then
        fail "An unrecognized fractional sleep remains in patched copy of $1"
    fi
}

create_backup_once() {
    if [ -e "$2" ]; then
        echo "KEEP: existing backup $2"
    else
        cp -p "$1" "$2" || fail "Could not create backup $2"
        echo "BACKUP: $2"
    fi
}

restore_backups_after_error() {
    echo 'Install failed; restoring both backups.' >&2
    [ ! -f "$KEY_BACKUP" ] || cp -p "$KEY_BACKUP" "$KEY_SCRIPT"
    [ ! -f "$STATUS_BACKUP" ] || cp -p "$STATUS_BACKUP" "$STATUS_SCRIPT"
}

restart_services() {
    if [ "${SKIP_SERVICE_RESTART:-0}" = '1' ]; then
        echo 'TEST: service restart skipped'
        return
    fi

    restart_missing=0
    if [ -x "${INIT_DIR}/checkkey" ]; then
        "${INIT_DIR}/checkkey" restart
    else
        echo "WARNING: ${INIT_DIR}/checkkey not found; reboot required." >&2
        restart_missing=1
    fi

    # The service is named checkstat even though its script is checkstatus.
    if [ -x "${INIT_DIR}/checkstat" ]; then
        "${INIT_DIR}/checkstat" restart
    else
        echo "WARNING: ${INIT_DIR}/checkstat not found; reboot required." >&2
        restart_missing=1
    fi

    if [ "$restart_missing" -ne 0 ]; then
        echo 'Patch is installed, but reboot the radio before acceptance testing.' >&2
    fi
}

check_installed() {
    /bin/sh -n "$KEY_SCRIPT" || fail "Syntax check failed: $KEY_SCRIPT"
    /bin/sh -n "$STATUS_SCRIPT" || fail "Syntax check failed: $STATUS_SCRIPT"
    if has_fractional_sleep "$KEY_SCRIPT" || has_fractional_sleep "$STATUS_SCRIPT"; then
        fail 'Fractional sleep remains after installation.'
    fi
}

require_script "$KEY_SCRIPT"
require_script "$STATUS_SCRIPT"

case "$MODE" in
    --check)
        /bin/sh -n "$KEY_SCRIPT" || fail "Syntax check failed: $KEY_SCRIPT"
        /bin/sh -n "$STATUS_SCRIPT" || fail "Syntax check failed: $STATUS_SCRIPT"
        report_file "$KEY_SCRIPT"
        report_file "$STATUS_SCRIPT"
        ;;

    --apply)
        require_writable_script "$KEY_SCRIPT"
        require_writable_script "$STATUS_SCRIPT"
        if ! has_fractional_sleep "$KEY_SCRIPT" && ! has_fractional_sleep "$STATUS_SCRIPT"; then
            echo 'ALREADY APPLIED: both scripts are free of fractional sleeps.'
            check_installed
            exit 0
        fi

        make_patched_copy "$KEY_SCRIPT" "$KEY_TEMP"
        make_patched_copy "$STATUS_SCRIPT" "$STATUS_TEMP"
        create_backup_once "$KEY_SCRIPT" "$KEY_BACKUP"
        create_backup_once "$STATUS_SCRIPT" "$STATUS_BACKUP"

        if ! cp "$KEY_TEMP" "$KEY_SCRIPT"; then
            restore_backups_after_error
            fail "Could not install $KEY_SCRIPT"
        fi
        if ! cp "$STATUS_TEMP" "$STATUS_SCRIPT"; then
            restore_backups_after_error
            fail "Could not install $STATUS_SCRIPT"
        fi

        check_installed
        restart_services
        echo 'APPLIED: fractional sleeps replaced with one-second sleeps.'
        echo 'Verify CPU idle, log errors, and exactly one watcher process per service.'
        ;;

    --restore)
        require_writable_script "$KEY_SCRIPT"
        require_writable_script "$STATUS_SCRIPT"
        [ -f "$KEY_BACKUP" ] || fail "Backup not found: $KEY_BACKUP"
        [ -f "$STATUS_BACKUP" ] || fail "Backup not found: $STATUS_BACKUP"
        cp -p "$KEY_BACKUP" "$KEY_SCRIPT"
        cp -p "$STATUS_BACKUP" "$STATUS_SCRIPT"
        /bin/sh -n "$KEY_SCRIPT" || fail "Restored syntax check failed: $KEY_SCRIPT"
        /bin/sh -n "$STATUS_SCRIPT" || fail "Restored syntax check failed: $STATUS_SCRIPT"
        restart_services
        echo 'RESTORED: original service scripts are active.'
        ;;

    -h|--help)
        usage
        ;;

    *)
        usage >&2
        exit 2
        ;;
esac
