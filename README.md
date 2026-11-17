# mycrmsim-android-setup

Unofficial Claude Code plugin for setting up and health-checking an Android phone that runs the myCRMSIM SMS Gateway app. Not made or endorsed by myCRMSIM.

**This works on my end but is not guaranteed for every device.**

## 1. Scope

The plugin lets Claude Code do three things:

1. Connect to the gateway phone over USB with adb (Android Debug Bridge) and run read-only health checks.
2. Walk the [myCRMSIM Android setup guide](https://support.mycrmsim.com/article/setting-up-your-android-device-with-mycrmsim-sms-gateway) from start to finish, using adb for the phone and Claude in Chrome for the myCRMSIM dashboard and the HighLevel connection.
3. Watch the phone and re-read message statuses while a batch of texts goes out.

Out of scope: sending texts, storing credentials, rooting the phone, and any change to billing.

## 2. Requirements

| Requirement | Used by |
| --- | --- |
| Claude Code | everything |
| `adb` on the same computer as Claude Code | both skills, all scripts |
| USB cable that carries data | both skills |
| Claude in Chrome extension, with the owner signed in to the myCRMSIM dashboard and HighLevel | `gateway-setup` |
| HighLevel private integration token in the `GHL_TOKEN` environment variable | `scripts/recheck_status.py` only |
| Python 3, standard library only | `scripts/recheck_status.py` |

Gateway app package name: `com.mysmsgateway.v2`. Override it with the `GATEWAY_PKG` environment variable.

## 3. Install

```text
/plugin marketplace add ai-agents-for-agencies-coaches/mycrmsim-android-setup
/plugin install mycrmsim-android-setup@mycrmsim-android-setup
```

Trigger phrases: "check the gateway phone", "set up this Android as a myCRMSIM gateway".

## 4. Components

| Path | Type | Writes to the phone | Purpose |
| --- | --- | --- | --- |
| `skills/gateway-health/SKILL.md` | skill | no | Connect over adb, run the health check, watch a batch |
| `skills/gateway-setup/SKILL.md` | skill | yes, with owner approval per step | Run the 17 guide steps and verify each one |
| `scripts/health_check.sh` | script | no | Prints `PASS`, `WARN` or `FAIL` per check. Exit 0 when nothing failed, 1 on a failure, 2 when adb is missing |
| `scripts/watch_gateway.sh [seconds]` | script | no | Polls every 60 seconds by default. Prints one line only when the state changes |
| `scripts/recheck_status.py <ids file>` | script | no | Reads one HighLevel message id per line and prints each status. Exit 1 when any message is `failed` |

## 5. Reference device

| Field | Value |
| --- | --- |
| Model | Samsung Galaxy A14 |
| Android | 15 |
| Gateway app version | 10.9.19 |
| Result | adb connection made, `scripts/health_check.sh` run, all checks passed |

## 6. Connecting the phone

1. On the phone: Settings, About phone, Software information, tap Build number 7 times.
2. Settings, Developer options, turn USB debugging on.
3. Plug the unlocked phone into the computer. Tap Allow on "Allow USB debugging?" and tick "Always allow from this computer".
4. `adb devices` returns `device`.

Known issue: `adb devices` returns `unauthorized` and the Allow prompt never appears. Restarting adb and replugging did not clear it on the reference device. Turning USB debugging off and back on with the phone unlocked made the prompt appear.

## 7. Health checks

All checks are read-only.

| Check | Command | Pass condition |
| --- | --- | --- |
| Authorized | `adb get-state` | `device` |
| App installed | `adb shell pm list packages` | package listed |
| App running | `adb shell pidof com.mysmsgateway.v2` | a process id |
| Default SMS app | `adb shell cmd role get-role-holders android.app.role.SMS` | `com.mysmsgateway.v2` |
| Standby bucket | `adb shell am get-standby-bucket com.mysmsgateway.v2` | `5` (exempt from battery limits) |
| Battery whitelist | `adb shell dumpsys deviceidle whitelist` | package listed |
| Permissions | `adb shell dumpsys package com.mysmsgateway.v2` | SMS, phone state, call log, contacts and notifications show `granted=true` |
| Restricted settings | `adb shell appops get com.mysmsgateway.v2` | `ACCESS_RESTRICTED_SETTINGS: allow` |
| Power | `adb shell dumpsys battery` and `adb shell settings get global low_power` | charging, power saving off |

The default SMS app check carries the RCS risk. RCS runs only inside Google Messages and Samsung Messages. When the gateway holds the SMS role, neither app can take an inbound reply.

## 8. Setup procedure

Step numbers match the myCRMSIM guide. After every step the skill runs the verification listed. When verification does not pass, the skill stops and asks the owner to do that step by hand.

| Guide step | Actor | Method | Verification |
| --- | --- | --- | --- |
| Prerequisite: HighLevel connected, sub-account added | Claude in Chrome, owner signs in and approves | myCRMSIM dashboard | sub-account is listed |
| 1. Play Protect off | Owner | Play Store, profile icon, Play Protect | `adb shell settings get global package_verifier_user_consent` |
| 2. RCS off | Owner | Messages app settings, as in the guide | SMS role check after step 15 |
| 3 and 4. Download and install | Claude, adb | APK from `https://get.mysmsgateway.app`, then `adb install -r` | package listed |
| 5. Home screen shortcut | skipped | optional in the guide | none |
| 6. Permissions and battery | Claude, adb | `adb shell pm grant` per runtime permission, `adb shell dumpsys deviceidle whitelist +<package>` | `granted=true` lines, whitelist entry |
| 7. Restricted settings, app pausing | Claude, adb | `adb shell appops set <package> ACCESS_RESTRICTED_SETTINGS allow`, `adb shell appops set <package> AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore` | `adb shell appops get <package>` |
| 8. Log in on the phone | Owner | scans the QR code shown in step 9 | app shows logged in |
| 9. Add the device | Claude in Chrome | Devices, Android Devices, Add New Device, name it, Save | device row shows Active |
| 10 to 13. SIM assignment | Claude in Chrome | Subaccount SIM, Assign SIMs, Workspace SIM, optional per-user SIMs | assignment rows match what the owner named |
| 14. Message routing | Claude in Chrome | Message Routing, SMS in the order the owner wants, Save | saved order read back to the owner |
| 15. Default SMS app | Claude, adb | `adb shell cmd role add-role-holder android.app.role.SMS <package>` | role holder is the gateway |
| 16. In-app switches | Owner | Keep Alive in Background on, Sync Received on, SIM choice on dual SIM | owner confirms, app still running |
| 17. Test | Owner approves, Claude verifies | one text from the CRM to the owner's own number | status re-read after two minutes is not `failed`, reply shows in the CRM |

The skill file marks which adb commands have not yet been confirmed on a device.

## 9. Safety constraints

1. Claude asks before every change to the phone or a dashboard.
2. The owner does every login. Claude never types, reads out or stores a password, a login token, an API key or the contents of a QR code.
3. No text is sent without the owner approving the exact words and the recipient. The test text goes to the owner's own number.
4. The device serial, phone numbers and contact names are never printed or written to a file.
5. Claude in Chrome never deletes a device, removes a SIM, disconnects HighLevel or opens a billing page.
6. USB debugging is turned off when the work is finished.

## 10. Observed behaviour

Recorded on the reference device during one run of 56 texts on 16 Nov 2026. Texts went through the HighLevel API to the gateway, the first 20 spaced 3 to 5 minutes apart and the rest a random 60 to 90 seconds apart. The phone stayed connected and the gateway app stayed running for the whole run.

| # | Observation | Handling |
| --- | --- | --- |
| 1 | One text failed and the carrier replied "You have been blocked from originating messages to [number]". Only that recipient was affected. Later texts still showed delivered. | Mark the contact do-not-text |
| 2 | One send failed with "All channels failed: SMS: No_service". Cause not determined, either a brief loss of signal or a dead number. | Check signal, retry once by hand |
| 3 | HighLevel reported `sent` about 8 seconds after sending. A `failed` status arrived later for the carrier-blocked text. | Re-read statuses after two minutes with `scripts/recheck_status.py` |
| 4 | Most texts stayed at `sent`. 4 of 56 showed `delivered` when the send log read them. | Treat `sent` as normal and `failed` as the signal |
| 5 | The myCRMSIM Custom Location API key only sends. The documented REST API answered 401 "Invalid or expired access token" because it expects an OAuth token. | Read statuses and replies from HighLevel |
| 6 | `package_verifier_user_consent` read `1` while the gateway app was installed and sending. This is believed to mean Play Protect scanning was on. Not confirmed. | Follow guide step 1 for installs and updates |

## 11. License

MIT.
