#!/bin/sh
# Disable TCL telemetry/ads and unused services for user 0. Reversible: pm enable <pkg>.
# Usage: debloat.sh [disable|enable|status]   (ANDROID_SERIAL selects the TV)
set -eu
ADB=${ADB:-adb}

TELEMETRY="com.tcl.bi com.tcl.overseasappshow com.tcl.waterfall.overseas com.tcl.channelplus
com.tcl.esticker com.tcl.logkit com.tcl.messagebox"
EXTRAS="com.tcl.smartalexa com.tcl.usercenter com.tcl.tv.tclhome_passive com.tcl.gamebar
com.tcl.hearaid com.tcl.browser com.tcl.gallery com.android.messaging com.android.camera2
com.google.android.play.games com.google.android.videos com.google.android.youtube.tvmusic"
# Breaks the remote's mic button and voice search — opt in with VOICE=1.
VOICE_PKG="com.google.android.katniss"

PKGS="$TELEMETRY $EXTRAS"
[ "${VOICE:-0}" = 1 ] && PKGS="$PKGS $VOICE_PKG"

case "${1:-status}" in
  disable) cmd='for p in $0; do pm disable-user --user 0 $p; am force-stop $p; done' ;;
  enable)  cmd='for p in $0; do pm enable $p; done' ;;
  status)  cmd='d=$(pm list packages -d); for p in $0; do echo "$d" | grep -qx "package:$p" && echo "disabled $p" || echo "ENABLED  $p"; done' ;;
  *) echo "usage: $0 [disable|enable|status]" >&2; exit 2 ;;
esac
# Pass the list as $0 of the remote sh so it survives adb's argument joining.
"$ADB" shell "sh -c '$cmd' '$(echo $PKGS)'"
