#!/bin/bash
# Prints the UDID of an available iPhone simulator, preferring the given device names in order.
# The example's UI tests tap where the sample document lays out on a 402-point-wide iPhone,
# so they ask for those models; the package tests run on any iPhone.
set -euo pipefail

xcrun simctl list devices available --json | python3 -c '
import json, sys
preferred = sys.argv[1:]
devices = [
    device
    for runtime, entries in json.load(sys.stdin)["devices"].items() if "iOS" in runtime
    for device in entries if device["name"].startswith("iPhone")
]
for name in preferred:
    for device in devices:
        if device["name"] == name:
            print(device["udid"])
            sys.exit(0)
if preferred:
    sys.exit("None of these simulators is available: " + ", ".join(preferred))
if not devices:
    sys.exit("No iPhone simulator is available")
print(devices[0]["udid"])
' "$@"
