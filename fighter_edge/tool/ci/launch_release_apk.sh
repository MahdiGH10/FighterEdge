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
wait_seconds="${LAUNCH_WAIT_SECONDS:-30}"

adb wait-for-device
adb install -r "$apk"
adb logcat -c
adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep "$wait_seconds"

pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
adb logcat -d > "$log"

failed=0
# A crash, a class R8 removed, plugins that never registered, or our own boot
# failure line (lib/observability/boot_failure.dart).
if grep -E "FATAL EXCEPTION|ClassNotFoundException|NoSuchMethodException|Tried to automatically register plugins|Failed to create an instance|\[boot\] failed" "$log"; then
  echo "::error::The release APK failed during launch (see the lines above)."
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
