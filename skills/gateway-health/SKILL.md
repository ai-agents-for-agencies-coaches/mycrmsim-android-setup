---
name: gateway-health
description: Read-only health check of an Android phone running the myCRMSIM SMS Gateway app, over USB with adb. Use before sending a batch of texts, when texts stop sending or replies stop arriving, or when asked "is the gateway phone ok", "check the SMS phone", "watch the phone while this batch runs".
---

# Gateway health check

Everything in this skill only reads from the phone. Never change a phone setting from this skill.

## Rules

- Never print, log or commit the device serial, a phone number, a contact name, an API key or a login token.
- If a check fails, tell the owner what to flip and where. Do not flip it yourself. The `gateway-setup` skill is the only place writes are allowed, and only with the owner's yes.
- Remind the owner to turn USB debugging off when the work is finished.

## Connect

1. The owner enables USB debugging once: Settings, About phone, Software information, tap Build number 7 times. Then Settings, Developer options, USB debugging on.
2. The owner plugs the phone into the computer Claude Code runs on, unlocked, taps Allow on "Allow USB debugging?" and ticks "Always allow from this computer".
3. Run `adb devices`. `device` means authorized.

**If it says `unauthorized` and no popup shows:** restarting adb and replugging did not fix this on a Galaxy A14. Turning USB debugging off and back on, with the phone unlocked, brought the popup up at once. Try that before anything else.

## Check

Run `${CLAUDE_PLUGIN_ROOT}/scripts/health_check.sh`. It prints PASS, WARN or FAIL per line:

| Check | Command it runs | Good result |
|---|---|---|
| Authorized | `adb get-state` | `device` |
| App running | `adb shell pidof com.mysmsgateway.v2` | a process id |
| Default SMS app | `adb shell cmd role get-role-holders android.app.role.SMS` | `com.mysmsgateway.v2` |
| Battery exempt | `adb shell am get-standby-bucket com.mysmsgateway.v2` | `5` |
| Battery whitelist | `adb shell dumpsys deviceidle whitelist` | package listed |
| Permissions | `adb shell dumpsys package com.mysmsgateway.v2` | SMS, phone, call log, contacts, notifications granted |
| Restricted settings | `adb shell appops get com.mysmsgateway.v2` | `ACCESS_RESTRICTED_SETTINGS: allow` |
| Power | `adb shell dumpsys battery` | charging, power saving off |

The default SMS app check matters most. RCS only runs inside Google Messages and Samsung Messages. When the gateway holds the SMS role, neither of them can take an inbound reply.

Set `GATEWAY_PKG` if the app's package name differs.

## Watch a batch

While texts are going out, run `${CLAUDE_PLUGIN_ROOT}/scripts/watch_gateway.sh 60` in the background. It prints a line only when the phone drops, the app dies, or things recover.

HighLevel shows "sent" about 8 seconds after a send and "failed" can arrive later. Save the message ids, wait two minutes, then run `${CLAUDE_PLUGIN_ROOT}/scripts/recheck_status.py ids.txt` with `GHL_TOKEN` set in the environment. Most texts stay at "sent" and never reach "delivered", so treat "sent" as normal and "failed" as the signal.

## Failures seen in the field

- Carrier reply `You have been blocked from originating messages to <number>`: one recipient only. Later texts still delivered. Mark that contact do-not-text.
- `All channels failed: SMS: No_service`: the phone had no signal at that moment, or the number is dead. Check signal, then retry once by hand.
