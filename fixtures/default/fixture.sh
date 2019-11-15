#!/bin/bash -eu

# Default fixture is no fixture at all
# Start cgiserver then just watch for display touch

echo "Default fixture driver"

die() { echo $@ >&2; exit 1; }

((!UID)) || die "Must be root!"

(($#==2)) || die "Usage: $0 pionic_dir station_id"

PIONIC=$1
STATION=$2
BASE=$(realpath ${0%/*})

# nuke children on exit
trap 'x=$?;
      set +eu;
      kill $(jobs -p) &>/dev/null && wait $(jobs -p);
      $PIONIC/fbtools/fbclear
      (($x)) && echo EXIT $x;
      exit $x' EXIT

fbtext=$PIONIC/fbtools/fbtext
[ -x $fbtext ] || die " Need executable $fbtext"

evdump=$PIONIC/evdump/evdump
[ -x $evdump ] || die "Need executable $evdump"

cgiserver=$BASE/cgiserver
[ -x $cgiserver ] || die "Need executable $cgiserver"

echo "Starting CGI server on station $STATION"
pkill -f cgiserver &>/dev/null || true
env -i BASE=$BASE PATH=$PATH STATION=$STATION PIONIC=$PIONIC $cgiserver $BASE 80 2>&1 | logger &
sleep 1
pgrep -f cgiserver &>/dev/null || die "cgiserver did not start"

logo() { printf "TEST STATION $STATION READY" | $fbtext -cwhite:blue -gc -s40 -b1 -; }

if [ -e /dev/input/mouse0 ]; then
    # We have touch, show logo and refresh on two taps within one second
    echo "Starting logo loop"
    while true; do
        logo
        while true; do
            read || die "evdump unexpected EOF"
            read -t1 && break
        done
    done < <($evdump -t1 -c272 -v1 mouse0 2>/dev/null)
else
    # No touch, just show logo and wait
    logo
    wait
fi
