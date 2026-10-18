# tcl-tv — Claude Code skill

Claude Code skill for TCL Google TV / Android TV 11 sets over ADB from a Mac:
connect over the network despite macOS Local Network privacy, keep a third-party launcher
(Projectivy) as the home screen after reboots, find and disable TCL telemetry/ads, speed up the UI.

Tested on TCL Smart TV Pro (BeyondTV4, Android TV 11, 2 GB RAM).

Install: clone into `~/.claude/skills/tcl-tv`, enable developer mode + USB debugging on the TV,
then ask Claude about your TCL TV.

## Layout

- `SKILL.md` — workflow and verified gotchas (in Russian).
- `scripts/adb-relay.sh <tv-ip>` — relays `127.0.0.1:15555` to the TV through system `nc`,
  because macOS blocks adb from the LAN (`No route to host`).
- `scripts/debloat.sh [status|disable|enable]` — disables TCL telemetry/ads and unused services
  for user 0 (`VOICE=1` also disables Google Assistant). Fully reversible with `enable`.

## Key findings

- TCL firmware re-enables Google TV Home and resets `APP_AUTO_START` app-ops on every boot.
  The persistent fix is the TCL Guard autostart whitelist
  (`am start -a com.tcl.guard.action.PermissionManager`).
- `com.tcl.bi` reports app usage and TCL system services keep connections to Alibaba Cloud
  even when diagnostics sharing is declined.

No device identifiers or credentials are stored here.
