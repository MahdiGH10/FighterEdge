#!/usr/bin/env bash
# Installs the release APK on the running emulator, launches it, and fails if
# it crashes or stops at the boot failure screen.
#
# Why: CI built the release APK for weeks without ever opening it. R8 stripped
# Room's WorkDatabase_Impl constructor (crash before Flutter starts, PR #33),
# and a build without GeneratedPluginRegistrant showed "Could not start
# Fighter Edge". Both only surfaced on a tester's phone.
#
# Usage: launch_release_apk.sh path/to/app-release.apk
set -euo pipefail

apk="$1"
package="com.fighteredge.fighter_edge"
log="release-launch-logcat.txt"
crash_log="release-launch-crash.txt"
wait_seconds="${LAUNCH_WAIT_SECONDS:-30}"

adb wait-for-device
adb install -r "$apk"
adb logcat -c
adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep "$wait_seconds"

pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
adb logcat -d > "$log"
adb logcat -b crash -d > "$crash_log" || true

failed=0
# The device log is full of other processes' noise (Settings, Bluetooth and
# Play services log ClassNotFoundException routinely), so generic patterns
# are only checked inside a crash of OUR process. The main log is searched
# only for lines no other app writes.
if grep -A4 "FATAL EXCEPTION" "$crash_log" | grep -q "Process: $package"; then
  grep -A20 "FATAL EXCEPTION" "$crash_log" | head -40
  echo "::error::The release APK crashed during launch (crash log above)."
  failed=1
fi
# Plugins never registered (no GeneratedPluginRegistrant), our own boot
# failure line (lib/observability/boot_failure.dart), or Room's database
# missing its constructor (PR #33).
if grep -E "Tried to automatically register plugins|\[boot\] failed|Failed to create an instance of androidx\.work" "$log"; then
  echo "::error::The release APK failed during startup (lines above)."
  failed=1
fi
if [ -z "$pid" ]; then
  echo "::error::The app process is not running ${wait_seconds}s after launch."
  failed=1
fi

if [ "$failed" -eq 0 ]; then
  echo "Release APK launched and is still running (pid $pid)."
fi
exit "$failed"
