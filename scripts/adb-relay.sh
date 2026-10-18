#!/bin/zsh
# macOS Local Network privacy blocks adb ("No route to host"); system nc is allowed,
# so relay 127.0.0.1:15555 -> TV:5555 through it. One adb connection at a time.
# Usage: adb-relay.sh <tv-ip> &   then: adb connect 127.0.0.1:15555
TV=${1:?usage: adb-relay.sh <tv-ip>}
F=${TMPDIR:-/tmp}/tcl-adb-relay.fifo
while true; do
  rm -f $F; mkfifo $F
  nc -l 127.0.0.1 15555 < $F | nc $TV 5555 > $F
done
