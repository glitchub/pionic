#!/bin/bash -eu

# Default fixture is no fixture at all
# Start cgiserver then just watch for display touch

pionic=~pi/pionic

# nuke children on exit
trap 'x=$?;
      set +eu;
      kill $(jobs -p) &>/dev/null && wait $(jobs -p);
      $pionic/fbtools/fbclear
      (($x)) && echo EXIT $x;
      exit $x' EXIT

echo "Default fixture driver"

die() { echo $@ >&2; exit 1; }

((!UID)) || die "Must be root!"

(($#==1)) || die "Usage: $0 station_id"
station=$1

echo "Station ID is $station"

fbtext=$pionic/fbtools/fbtext
[ -x $fbtext ] || die " Need executable $fbtext"

evdump=$pionic/evdump/evdump
[ -x $evdump ] || die "Need executable $evdump"

echo "Starting CGI server"
pkill -f cgiserver &>/dev/null || true
cd ${0%/*}
./cgiserver -p 80 &
sleep 1
pgrep -f cgiserver &>/dev/null || die "cgiserver did not start"

# Show default screen, refresh on two taps within one second
echo "Starting logo loop"
while true; do
    printf "TEST STATION $station READY" | $fbtext -cwhite:blue -gc -s40 -
    while true; do
        read || die "evdump unexpected EOF"
        read -t1 && break
    done
done < <($evdump -t1 -c272 -v1 mouse0 2>/dev/null)
