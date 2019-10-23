#!/bin/bash -eu

# Default fixture is no fixture at all
# Start cgiserver then just watch for display touch

# nuke children on exit
trap 'x=$?; kill $(jobs -p) &>/dev/null && wait $(jobs -p) || true; exit $x' EXIT

echo "Default fixture driver"

die() { echo $@ >&2; exit 1; }

((!UID)) || die "Must be root!"

(($#==1)) || die "Usage: $0 station_id"
station=$1

echo "Station ID is $station"

fbtext=~pi/pionic/fbtools/fbtext
[ -x $fbtext ] || die " Need executable $fbtext"

evdump=~pi/pionic/evdump/evdump
[ -x $evdump ] || die "Need executable $evdump"

# Start cgi server
pkill -f cgiserver &>/dev/null
${0%/*}/cgiserver -p 80 &
sleep 1
pgrep -f cgiserver &>/dev/null || die "cgiserver did not start"

# Show default screen, refresh on two taps within one second
while true; do
    printf "TEST STATION $station READY" | $fbtext -cwhite:blue -gcenter -p40
    while true; do
        read || die "evdump unexpected EOF"
        read -t1 && break
    done
done < <($evdump -t1 -c272 -v1 mouse0 2>/dev/null)
