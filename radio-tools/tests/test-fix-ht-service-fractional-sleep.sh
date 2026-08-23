#!/bin/sh
set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TOOL_DIR=$(CDPATH= cd -- "${TEST_DIR}/.." && pwd)
FIXTURE_DIR="${TEST_DIR}/fixtures"
SANDBOX=$(mktemp -d)

cleanup() {
    rm -rf "$SANDBOX"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$SANDBOX/ht-service"
cp "$FIXTURE_DIR/checkkey" "$SANDBOX/ht-service/checkkey"
cp "$FIXTURE_DIR/checkstatus" "$SANDBOX/ht-service/checkstatus"
chmod +x "$SANDBOX/ht-service/checkkey" "$SANDBOX/ht-service/checkstatus"

run_tool() {
    HT_SERVICE_DIR="$SANDBOX/ht-service" \
    SKIP_SERVICE_RESTART=1 \
    sh "$TOOL_DIR/fix-ht-service-fractional-sleep.sh" "$1"
}

run_tool --check | grep -q 'FIX REQUIRED'
run_tool --apply | grep -q 'APPLIED'

! grep -Eq 'sleep[[:space:]][[:space:]]*0\.[0-9]+' "$SANDBOX/ht-service/checkkey"
! grep -Eq 'sleep[[:space:]][[:space:]]*0\.[0-9]+' "$SANDBOX/ht-service/checkstatus"
grep -q 'sleep 1' "$SANDBOX/ht-service/checkkey"
[ "$(grep -c 'sleep 1' "$SANDBOX/ht-service/checkstatus")" -eq 2 ]
cmp "$FIXTURE_DIR/checkkey" "$SANDBOX/ht-service/checkkey.pre-openmanet-fix"
cmp "$FIXTURE_DIR/checkstatus" "$SANDBOX/ht-service/checkstatus.pre-openmanet-fix"

KEY_SUM=$(cksum "$SANDBOX/ht-service/checkkey")
STATUS_SUM=$(cksum "$SANDBOX/ht-service/checkstatus")
run_tool --apply | grep -q 'ALREADY APPLIED'
[ "$KEY_SUM" = "$(cksum "$SANDBOX/ht-service/checkkey")" ]
[ "$STATUS_SUM" = "$(cksum "$SANDBOX/ht-service/checkstatus")" ]

run_tool --check | grep -q 'OK: no fractional sleeps'
run_tool --restore | grep -q 'RESTORED'
cmp "$FIXTURE_DIR/checkkey" "$SANDBOX/ht-service/checkkey"
cmp "$FIXTURE_DIR/checkstatus" "$SANDBOX/ht-service/checkstatus"

cp "$FIXTURE_DIR/checkstatus-unknown" "$SANDBOX/ht-service/checkstatus"
if run_tool --apply >/dev/null 2>&1; then
    echo 'FAIL: unexpected fractional sleep was accepted' >&2
    exit 1
fi
cmp "$FIXTURE_DIR/checkstatus-unknown" "$SANDBOX/ht-service/checkstatus"

echo 'PASS: check, apply, idempotence, backup, restore, and unknown-value guard'
