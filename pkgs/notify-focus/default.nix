{ writers }:
writers.writePython3Bin "notify-focus" { } (builtins.readFile ./notify-focus.py)
