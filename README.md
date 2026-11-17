# mycrmsim-android-setup

Unofficial Claude Code plugin made by a myCRMSIM customer, neither made nor endorsed by myCRMSIM.

**This works on my end but is not guaranteed for every device.**

Hey Gary,

This is the walkthrough you asked for, showing how I connected Claude Code to my Android gateway phone and what I did with it.

## What I ran it on

On my Samsung Galaxy A14 running Android 15 and gateway app 10.9.19, I've proven the adb connection and every read-only check. I ran the health check script, and all checks passed.

The skill runs a read-only check after each step. If it doesn't pass, it asks the owner to complete that step by hand.

## Install the plugin

You need Claude Code, Anthropic's coding agent that runs in a terminal, plus adb on the same computer and a USB data cable. adb means Android Debug Bridge.

For setup, you also need Claude in Chrome, Anthropic's browser extension that lets Claude click through pages in your own logged-in Chrome. You must already be logged in to the myCRMSIM dashboard and HighLevel.

```text
/plugin marketplace add ai-agents-for-agencies-coaches/mycrmsim-android-setup
/plugin install mycrmsim-android-setup@mycrmsim-android-setup
```

Then say "check the gateway phone" or "set up this Android as a myCRMSIM gateway".

## What the plugin does

The plugin supplies two skills and three small scripts.

| Skill | What it does |
| --- | --- |
| `gateway-health` | Checks the phone over USB using adb. It's read-only and changes nothing. |
| `gateway-setup` | Walks [myCRMSIM's own 17-step Android setup guide](https://support.mycrmsim.com/article/setting-up-your-android-device-with-mycrmsim-sms-gateway) from start to finish, using adb for the phone and Claude in Chrome for the dashboard and HighLevel connection. |

| Script | What it does |
| --- | --- |
| `scripts/health_check.sh` | Runs read-only checks and prints PASS / WARN / FAIL per line. |
| `scripts/watch_gateway.sh` | Checks every 60 seconds that the phone is connected and the gateway app is alive. Prints only when something changes. |
| `scripts/recheck_status.py` | Re-reads HighLevel message statuses a couple of minutes after sending. Requires a HighLevel token in the `GHL_TOKEN` environment variable. |

## Connecting the phone

These are the connection steps I used.

1. On the phone, open Settings, About phone, Software information. Tap Build number 7 times.
2. Open Settings, Developer options, and turn USB debugging on.
3. Plug the unlocked phone into the computer. Tap Allow on "Allow USB debugging?" and tick "Always allow from this computer".

My snag was that adb showed `unauthorized`, but the Allow popup never appeared. Restarting adb and replugging didn't fix it. Turning USB debugging off and back on with the phone unlocked brought the popup up right away.

## Read-only checks

These are the checks that passed on my phone.

| Command | What a good result looks like |
| --- | --- |
| `adb devices` | `device` |
| `adb shell pidof com.mysmsgateway.v2` | A process id, meaning the app is running. |
| `adb shell cmd role get-role-holders android.app.role.SMS` | `com.mysmsgateway.v2`. The gateway is the default SMS app, so RCS in Google Messages or Samsung Messages cannot take replies. |
| `adb shell am get-standby-bucket com.mysmsgateway.v2` | `5`, exempt from battery limits. |
| `adb shell dumpsys deviceidle whitelist \| grep mysmsgateway` | Listed on the battery optimisation whitelist. |
| `adb shell appops get com.mysmsgateway.v2` | `ACCESS_RESTRICTED_SETTINGS: allow` |
| `adb shell dumpsys battery` | Charging, with power saving off. |

## How the 17 steps are split

The setup skill divides the guide this way.

| Who handles it | Guide steps |
| --- | --- |
| Claude over adb | Download and install the app (3 and 4), permissions and battery (6), restricted settings and app pausing (7), default SMS app (15). |
| Claude in Chrome | Add the device (9), SIM assignment (10 to 13), message routing (14). |
| Owner by hand | Play Protect off (1), RCS off (2), scan the login QR code (8), Keep Alive in Background and Sync Received switches (16), approve the test text (17). |

## Guard rails in the skills

Claude asks before every phone or dashboard change. The owner handles every login. Claude never types, reads out or stores a password, login token, API key or QR code.

No text goes out without approval of the exact words and recipient. The test text goes to the owner's own number. Device serials, phone numbers and contact names are never printed. USB debugging gets turned off at the end.

## What I used it for

On Monday 16 Nov 2026, I ran a reactivation batch to old leads. I queued 98 texts and sent 56. I stopped because the list was colder than I wanted, which had nothing to do with the gateway.

Texts went through the HighLevel API to the gateway. The first 20 were 3 to 5 minutes apart, then a random 60 to 90 seconds apart. The watcher ran throughout. The phone stayed connected and the gateway app stayed up.

## Field notes from a 56 text run

1. One recipient failed with "You have been blocked from originating messages to [number]". That affected only that recipient. Later texts still showed delivered.
2. One send failed with "All channels failed: SMS: No_service". I don't know whether signal dropped briefly or the number was dead.
3. HighLevel shows "sent" about 8 seconds after sending. The carrier-blocked text showed sent then failed later, which is why `recheck_status.py` exists.
4. Most texts stayed at "sent". Only 4 of 56 showed "delivered" when the send log read them.
5. The Custom Location API key only sends. The documented myCRMSIM REST API returned 401 "Invalid or expired access token", because it wants OAuth. I read statuses and replies from HighLevel.
6. `package_verifier_user_consent` reads `1` on my sending phone. I believe that means Play Protect scanning is on, but haven't confirmed it.

License: MIT.