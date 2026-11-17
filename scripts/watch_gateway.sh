#!/usr/bin/env bash
# Read-only watcher. Run it while a batch of texts is going out.
# Prints one line only when something changes: phone dropped, gateway app died, or back to normal.
# Usage: scripts/watch_gateway.sh [seconds between checks, default 60]
set -u
PKG="${GATEWAY_PKG:-com.mysmsgateway.v2}"
EVERY="${1:-60}"
last=""
while true; do
  if [ "$(adb get-state 2>/dev/null | tr -d '\r')" != "device" ]; then now="PHONE: disconnected or unauthorized"
  elif [ -z "$(adb shell pidof "$PKG" 2>/dev/null | tr -d '\r')" ]; then now="GATEWAY: app is not running"
  else now="OK: phone connected, gateway app running"; fi
  if [ "$now" != "$last" ]; then echo "$(date '+%H:%M:%S') $now"; last="$now"; fi
  sleep "$EVERY"
done
