# The remapper owns every digital keyboard feature

Status: accepted

Caps → Esc, mod-tap and Fn layers lived in the Wooting's firmware, so the
lenovo's built-in keyboard had none of them and got a host-wide xkb
`caps:escape` as a stand-in. Every digital feature now lives in one place,
kanata, applied to every keyboard on a workstation; each keyboard's firmware
keeps only its onboard features. For the Wooting that means actuation, rapid
trigger, and selecting its stored profiles from the physical Fn key. Its
profiles are reset to stock remaps and differ only in analog settings.

## Considered options

- **Leave the Wooting's firmware alone and remap only keyboards without their
  own** (the laptop keyboard). Rejected: two keymaps that drift, in two tools,
  and the Wooting plugged into the lenovo would have been remapped twice.
- **xkb options.** Rejected: host-wide rather than per-device, only reaches
  xkb-aware clients, and has no tap-hold.
- **keyd.** Also per-device at the evdev level and lighter, but has no
  opposite-hand resolution or prior-idle typing-streak detection, and those
  are what make home-row mods tolerable. Home-row mods are the reason the
  remapper exists at all.

## Consequences

- osu needs every key unprocessed. The remapper switches to a passthrough
  layer while osu has focus, driven by a watcher on niri's event stream over
  kanata's TCP server. The cost of that passthrough has a limit: p99 under
  0.5 ms added over the Wooting's raw device. Past that, the Wooting gets its
  own kanata instance (it does anyway) and the watcher stops it while osu has
  focus, so the keyboard reaches the system untouched.
- Chording keyboards (the CharaChorder) are excluded by device name: their
  output is bursts of keystrokes that tap-hold keys would corrupt.
- The keymap is a dotfile, linked out-of-store, so the kanata service's
  `ProtectHome` is loosened to read-only. Tuning tap-hold timings is
  iterative, and live reload beats a rebuild per change.
