---
name: gateway-setup
description: Set up an Android phone as a myCRMSIM SMS Gateway device from start to finish. Claude drives the phone over USB with adb and drives the myCRMSIM and HighLevel dashboards with Claude in Chrome, following myCRMSIM's own 17-step setup guide. Use when asked to "set up the gateway phone", "connect a new Android to myCRMSIM", "add a SIM device", or "do the myCRMSIM setup for me".
---

# myCRMSIM Android gateway setup

Source guide: https://support.mycrmsim.com/article/setting-up-your-android-device-with-mycrmsim-sms-gateway
Read it first. If the guide and this file disagree, the guide wins, and tell the owner what changed.

## What is proven and what is not

- **Proven on a real phone** (Galaxy A14, Android 15, gateway app 10.9.19): connecting over adb and every read-only check in the `gateway-health` skill.
- **Not yet run end to end:** every command below marked UNTESTED, and every dashboard step. Treat each as a first attempt. Run it, verify with the read-only check next to it, and fall back to asking the owner to tap it by hand if the check does not pass.

Say this to the owner before starting. Do not present an untested step as certain.

## Rules

1. **Ask before every write.** Each step that changes the phone or a dashboard gets a one-line "about to do X, ok?" and waits for a yes. The owner can grant a blanket yes for the whole run.
2. **The owner logs in.** Never type, read aloud, store or log a password, a login token, an API key or a QR code's contents. The owner signs in to the dashboards and approves any HighLevel permission screen.
3. **Never send a text without the owner approving the exact words and the recipient.** The Step 17 test goes to the owner's own number only.
4. **Never print the device serial, phone numbers or contact names.** Nothing from this run gets committed anywhere.
5. **Verify after each step** with the read-only check listed. A command returning no error is not proof.
6. **A setup phone, not a personal phone, when there is a choice.** myCRMSIM advises a dedicated SIM for bulk sending.
7. When done, run the `gateway-health` skill, then tell the owner to turn USB debugging off.

## Tools needed

- `adb` on the computer Claude Code runs on, and a USB cable that carries data.
- Claude in Chrome, with the owner already signed in to the myCRMSIM dashboard and HighLevel.

Package name used below: `com.mysmsgateway.v2`. Call it `$PKG`.

## Phase 0: before the phone

Guide prerequisites: HighLevel is connected to the myCRMSIM dashboard, and the sub-account is added.

With Claude in Chrome, open the myCRMSIM dashboard and confirm the sub-account is listed. If HighLevel is not connected yet, open the connect screen and stop. The owner clicks through the HighLevel sign-in and approval. Then confirm the sub-account shows.

## Phase 1: connect the phone

Follow "Connect" in the `gateway-health` skill. The owner turns on USB debugging and taps Allow. That part cannot be automated.

## Phase 2: the guide's steps, one by one

| Guide step | Who does it | How | Verify |
|---|---|---|---|
| 1. Play Protect off | Owner, by hand | Play Store, profile icon, Play Protect, turn scanning off. UNTESTED adb route: `adb shell settings put global package_verifier_user_consent -1` | `adb shell settings get global package_verifier_user_consent` |
| 2. RCS off | Owner, by hand | Google Messages or Samsung Messages settings, as in the guide. No dependable adb switch is known. Step 15 covers the same risk. | after Step 15, the SMS role check |
| 3. Download the app | Claude | Download the APK from https://get.mysmsgateway.app on the computer, into a new empty folder. Do not commit it. | file exists, is an APK |
| 4. Install | Claude | UNTESTED: `adb install -r <file>.apk` | `adb shell pm list packages \| grep mysmsgateway` |
| 5. Shortcut | Skip | Optional in the guide. | |
| 6. Allow all permissions | Claude | UNTESTED: `adb shell pm grant $PKG android.permission.X` for each of SEND_SMS, RECEIVE_SMS, READ_SMS, RECEIVE_MMS, READ_PHONE_STATE, READ_PHONE_NUMBERS, CALL_PHONE, ANSWER_PHONE_CALLS, READ_CALL_LOG, READ_CONTACTS, POST_NOTIFICATIONS, CAMERA. Battery: `adb shell dumpsys deviceidle whitelist +$PKG` | `adb shell dumpsys package $PKG \| grep granted=true` and `adb shell dumpsys deviceidle whitelist \| grep mysmsgateway` |
| 7a. Allow restricted settings | Claude | UNTESTED: `adb shell appops set $PKG ACCESS_RESTRICTED_SETTINGS allow` | `adb shell appops get $PKG \| grep RESTRICTED` shows `allow` |
| 7b. Stop "pause app if unused" | Claude | UNTESTED: `adb shell appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore` | `adb shell appops get $PKG \| grep AUTO_REVOKE` |
| 8. Log in on the phone | Owner + Claude | Claude opens the app: `adb shell monkey -p $PKG 1`. The owner scans the QR from Step 9 with the phone. | app shows logged in |
| 9. Add the device | Claude in Chrome | Dashboard: Devices, Android Devices, Add New Device. Leave the QR on screen for the owner to scan. Never read out or copy the token. Once connected, name the device and Save. | device row shows Active |
| 10. Open SIM assignment | Claude in Chrome | Dashboard: Subaccount SIM, find the sub-account, click the orange plus in the SIM Card column. | Assign SIMs modal is open |
| 11. Default SIM | Claude in Chrome | Workspace SIM dropdown, pick the SIM the owner names. Ask which SIM. Do not guess. | dropdown shows it |
| 12 to 13. Per-user SIMs | Claude in Chrome | Only if the owner wants different SIMs per user: Assign new SIM, user, SIM, Assign. | rows listed |
| 14. Message routing | Claude in Chrome | Message Routing for the sub-account. Make sure SMS is in the order the owner wants. Read the order back to the owner, then Save. | saved order matches |
| 15. Default SMS app | Claude | UNTESTED: `adb shell cmd role add-role-holder android.app.role.SMS $PKG`. If it does nothing, the owner sets it in Settings, Default apps. | `adb shell cmd role get-role-holders android.app.role.SMS` returns `$PKG` |
| 16. In-app settings | Owner, by hand | In the app: Keep Alive in Background on, Sync Received on, pick the SIM on a dual SIM phone. | owner confirms. Then `adb shell pidof $PKG` |
| 17. Test | Owner + Claude | The owner approves one test text to their own number, sent from the CRM. Wait two minutes and re-read its status. The owner replies from another phone and Claude confirms the reply shows in the CRM. | status is not "failed", reply is visible |

For any by-hand step, give the owner the taps in one short numbered list and wait.

## Phase 3: close out

1. Run the `gateway-health` skill and show the PASS, WARN and FAIL lines.
2. In the dashboard, read the device row: status Active, battery, connection, permissions, last ping. Report anything off.
3. Report which UNTESTED commands worked and which needed the owner's hand, so the next run knows.
4. Tell the owner to turn USB debugging off.

## Observed on a working phone

On the test phone `package_verifier_user_consent` read `1` while the gateway app was installed and sending. That value is believed to mean Play Protect scanning is on. So treat Step 1 as needed for installing and updating, as the guide says, and do not assume a running gateway means it is off.

## Using Claude in Chrome on the dashboards

- Take a screenshot before and after each change and tell the owner what changed in one line.
- Use the menu names from the guide. If a menu is missing or renamed, stop and ask. Do not explore.
- Never click anything that deletes a device, removes a SIM or disconnects HighLevel.
- Do not open billing pages.
