#!/bin/zsh
# macOS Local Network privacy blocks adb ("No route to host"); system nc is allowed,
# so relay 127.0.0.1:15555 -> TV:5555 through it. One adb connection at a time.
# Usage: adb-relay.sh <tv-ip> [local-port] &   then: adb connect 127.0.0.1:<local-port>
TV=${1:?usage: adb-relay.sh <tv-ip> [local-port]}
PORT=${2:-15555}
F=${TMPDIR:-/tmp}/tcl-adb-relay-$PORT.fifo
while true; do
  rm -f $F; mkfifo $F
  nc -l 127.0.0.1 $PORT < $F | nc $TV 5555 > $F
done
