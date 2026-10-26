{ writers }:
writers.writePython3Bin "osu-focus-watcher" { } (builtins.readFile ./osu-focus-watcher.py)
