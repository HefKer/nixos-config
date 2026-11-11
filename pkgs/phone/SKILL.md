---
name: phone
description: "Reach and drive the user's Android phone over adb. Use when a task reads or changes something on the phone: its settings, apps, files, notifications or screen."
---

# Phone

## Connect

```sh
export ANDROID_SERIAL=$(phone-connect)
```

`phone-connect` finds the phone (the tailnet's online Android peer, or `PHONE_HOST`), pins adb to port 5555 until the next reboot (reachable off Wi-Fi from then on), and prints the serial; every later `adb` call then targets the phone. When it exits non-zero, ask the user to turn on Settings → Developer options → Wireless debugging, with the phone on Wi-Fi, then rerun it. Pairing is already done; ask for a pairing code only when adb reports the device `unauthorized`.

## What needs the user's yes

The phone has no rollback, so act freely only where the step is easy to undo:

- **Free:** reading state, screenshots, UI dumps, toggles the user can flip back in one tap.
- **Ask first:** uninstalling, clearing app data, sending anything (SMS, calls, messages, posts), granting or revoking permissions, accessibility services, device admin, anything in Secure Folder or payment apps.

Change a setting only with `phone-set`, never `settings put` or `settings delete`: it records the value it replaced in the phone journal. Tell the user what changed and how to undo it.

## Reading state

Shell commands work with the screen off or locked.

- `dumpsys battery`, `dumpsys batterystats --charged` (per-UID drain; map a `u0aN` to its app as UID 10000+N via `pm list packages -U --user 0`).
- `dumpsys notification --noredact` (count `NotificationRecord` lines by `pkg=`), `dumpsys usagestats` (`lastTimeVisible` per package), `dumpsys package <pkg>`.
- `du -sk /sdcard/*`; the phone's toybox shell lacks GNU flags such as `sort -h`, so pipe output back and process it on the desktop.

## Settings

- Read with `adb shell settings list|get {global,secure,system} [key]`.
- Write with `phone-set {global,secure,system} <key> <value|--delete>`. It prints `old -> new` as read back from the phone, and exits non-zero when the phone holds something other than the value asked for.
- The phone journal is `~/.local/state/phone/journal.tsv`, one line per change: timestamp, namespace, key, old value, new value (`\t`, `\n` and `\\` escaped). To undo a change, `phone-set` the key back to its old value, or `--delete` it when the old value is `null` (the key was unset).
- Samsung's `system settings_change_history` names the last 10 keys changed through the Settings app, newest first: the quickest way to learn the key behind a toggle the user just flipped.
- Otherwise find a key by diffing: dump all three namespaces, flip the toggle (through the UI, or by asking), dump again, diff, flip it back.
- After a change, read the UI back to confirm the app picked it up. Screenshots are taken before display color filters (Eye comfort shield, grayscale), so those need the user's eyes.
- Services: `cmd notification set_dnd on|off`, `cmd wifi`, `cmd bluetooth_manager`, `cmd statusbar expand-settings|collapse`.

## Driving the screen

UI work needs the phone awake and unlocked. If `dumpsys window` shows `isKeyguardShowing=true`, ask the user to unlock it; the PIN stays with the user.

Every touch is grounded in a fresh UI dump: read the dump, act, dump again to confirm the screen moved where you meant. A swipe that doesn't register leaves you on the old screen, and a long-press then lands on whatever sits there.

- `adb exec-out uiautomator dump /dev/tty` prints the tree on one line; split it with `tr '>' '\n'` before grepping. `bounds` are in screen pixels (1440×3120), the same space `input` takes.
- `input tap X Y`, `input text 'a%sb'` (`%s` is a space), `input keyevent HOME|BACK|WAKEUP`.
- `input swipe X1 Y1 X2 Y2 350` changes launcher pages; durations under ~300 ms often register as nothing.
- `input swipe X Y X Y 1200` is a long-press; `input draganddrop X1 Y1 X2 Y2 2500` picks something up and moves it (an app from the drawer onto a homescreen).
- `am start -a android.intent.action.VIEW -d <url>` opens a link; `am start -a android.settings.<PAGE>_SETTINGS` jumps to a Settings page.
- `adb exec-out screencap -p | magick - -resize 40% shot.png`, then read the image; full size costs several times the context.
- The mobile-mcp tools, when loaded, wrap the same dump/tap/screenshot loop.

The launcher is Nova: it has no "add app" menu; an app reaches a homescreen by dragging it out of the drawer, which closes onto the page it was opened from.

## Apps and files

- `pm list packages [-3] --user 0`, `pm disable-user --user 0`, `pm enable`, `appops get|set`.
- `adb pull` / `adb push`, user storage under `/sdcard` (screenshots in `/sdcard/DCIM/Screenshots`).
- `scrcpy` mirrors the phone into a desktop window when the user wants to watch.

## Gotchas

- `enabled=4` (disabled-until-used) in `dumpsys package` is Samsung putting an unused app to sleep, not the user disabling it; `pm list packages -d` lists these too. Leave them alone.
- Secure Folder is user 150 and Knox refuses the shell; pass `--user 0` to `pm` and `cmd package` so calls skip it.
- No root: anything needing it (`/data`, other apps' files, system partitions) is out of reach.
