#!/usr/bin/env bash
# Read-only health check for an Android phone running the myCRMSIM SMS Gateway app.
# Changes nothing on the phone. Never prints the device serial.
# Usage: scripts/health_check.sh            (package defaults to com.mysmsgateway.v2)
#        GATEWAY_PKG=other.package scripts/health_check.sh
set -u
PKG="${GATEWAY_PKG:-com.mysmsgateway.v2}"
fail=0
ok()   { echo "PASS  $*"; }
warn() { echo "WARN  $*"; }
bad()  { echo "FAIL  $*"; fail=1; }

command -v adb >/dev/null || { echo "FAIL  adb is not installed on this computer"; exit 2; }

state="$(adb get-state 2>&1 | tr -d '\r')"
case "$state" in
  device) ok "phone connected and authorized" ;;
  *unauthorized*) bad "phone is 'unauthorized': unlock it and tap Allow. No popup? Turn USB debugging off and back on with the phone unlocked."; exit 1 ;;
  *) bad "no phone found over adb ($state)"; exit 1 ;;
esac

sh() { adb shell "$@" 2>/dev/null | tr -d '\r'; }

echo "INFO  Android $(sh getprop ro.build.version.release), $(sh getprop ro.product.manufacturer) $(sh getprop ro.product.model)"

if sh pm list packages | grep -qx "package:$PKG"; then
  ok "gateway app installed ($(sh dumpsys package "$PKG" | grep -m1 versionName | xargs))"
else
  bad "gateway app $PKG is not installed"; exit 1
fi

[ -n "$(sh pidof "$PKG")" ] && ok "gateway app is running" || bad "gateway app is not running"

role="$(sh cmd role get-role-holders android.app.role.SMS)"
if [ "$role" = "$PKG" ]; then
  ok "gateway is the default SMS app, so RCS in Google or Samsung Messages cannot take replies"
else
  bad "default SMS app is '$role', not the gateway. Replies can be lost to RCS."
fi

bucket="$(sh am get-standby-bucket "$PKG")"
[ "$bucket" = "5" ] && ok "standby bucket 5 (exempt from battery limits)" || warn "standby bucket is $bucket (5 means exempt)"

sh dumpsys deviceidle whitelist | grep -q "$PKG" && ok "on the battery optimisation whitelist" || bad "not on the battery optimisation whitelist"

for p in SEND_SMS RECEIVE_SMS READ_SMS READ_PHONE_STATE READ_CALL_LOG READ_CONTACTS POST_NOTIFICATIONS; do
  if sh dumpsys package "$PKG" | grep -q "android.permission.$p: granted=true"; then ok "permission $p granted"
  else warn "permission $p not granted"; fi
done

ops="$(sh appops get "$PKG")"
echo "$ops" | grep -q "ACCESS_RESTRICTED_SETTINGS: allow" && ok "restricted settings allowed" || warn "restricted settings not shown as allowed"

batt="$(sh dumpsys battery)"
level="$(echo "$batt" | awk -F': ' '/^ *level/{print $2}')"
if echo "$batt" | grep -qE "(AC|USB|Wireless) powered: true"; then ok "battery ${level}% and charging"
else warn "battery ${level}% and NOT charging"; fi

[ "$(sh settings get global low_power)" = "1" ] && warn "power saving mode is ON" || ok "power saving mode is off"

exit $fail
