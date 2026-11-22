# Phone target

What changes when the software runs on the phone. The criteria are `preferences.md` →
Phone; reaching the phone is the `phone` skill.

## Research

These replace the nixpkgs and desktop sources of step 2:

- **Stores**: F-Droid, IzzyOnDroid, and the Play listing (Data safety, permissions, last
  update, minimum Android version).
- **Trackers and permissions**: the app's Exodus Privacy report. When Exodus refuses the
  fetch, scan the APK for SDK names instead and say the result is a local scan
  (`docs/research/phone-automation-app.md` did).
- **Community**: r/fossdroid, r/androidapps, awesome-android lists, the upstream repo.
- **Already installed**: `adb shell pm list packages -3 --user 0`; a candidate the user
  already has, or has paid for, says so in the table.
- **Build our own** is a Tasker project with a Termux script (`phone` skill → Termux
  scripts), or a page opened in the phone's browser.

In place of `nix build`: each finalist's listing supports the phone's Android version
(`adb shell getprop ro.build.version.release`).

## Preview

1. **Listing screenshots**: the upstream repo's
   `fastlane/metadata/android/en-US/images/phoneScreenshots/`, or the store listing's,
   linked with the version they show.
2. **Own shots**, only for a finalist installed for the smoke test: `adb exec-out screencap
   -p`, resized as the `phone` skill says, into the preview directory.

The trial config has no phone equivalent; the demo video applies unchanged.

## Smoke test

Installing changes the phone, so ask before the first install, naming the app and its
source. Then drive its core job through the `phone` skill and read the UI dump to confirm
it worked. Leave the top pick installed for the user's trial and say so; every other app
installed along the way is listed with an offer to uninstall it.

## Write-up

- **Try it** is each finalist's store link, F-Droid first, with the two or three things to
  try; `scrcpy` when the user wants to watch a run from the desktop.
- **Adoption** names where its settings export lands in `phone/` and which Tasker or Termux
  pieces it needs.
- With a desktop counterpart, a row for **sync**: the path the data takes between the two
  (Syncthing, KDE Connect, a self-hosted service, a vendor cloud).
