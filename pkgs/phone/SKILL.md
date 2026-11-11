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

Record the old value before any `settings put`, and tell the user what changed and how to undo it.

## Toolbox

- Settings: `adb shell settings list|get|put {global,secure,system} <key> [value]`. To find a key behind a UI toggle, dump all three namespaces, flip it (yourself through the UI, or by asking), dump again, diff.
- Services: `adb shell cmd <service> ...` (`cmd wifi`, `cmd bluetooth_manager`, `cmd notification`, `cmd package`); `adb shell dumpsys <service>` to read state.
- Apps: `pm list packages [-3] --user 0`, `pm disable-user --user 0`, `pm enable`, `appops get|set`.
- Screen: `adb exec-out screencap -p > shot.png` then read the image; `adb exec-out uiautomator dump /dev/tty` for the UI tree with bounds; `adb shell input tap X Y|swipe|text|keyevent`. The mobile-mcp tools, when loaded, wrap the same thing.
- Files: `adb pull` / `adb push`, user storage under `/sdcard`.

## Gotchas

- `enabled=4` (disabled-until-used) in `dumpsys package` is Samsung putting an unused app to sleep, not the user disabling it; `pm list packages -d` lists these too. Leave them alone.
- Secure Folder is user 150 and Knox refuses the shell; pass `--user 0` to `pm` and `cmd package` so calls skip it.
- No root: anything needing it (`/data`, other apps' files, system partitions) is out of reach.
