#!/bin/bash -eu

# Default fixture is no fixture at all, just start cgiserver and watch for display touch

echo "Default fixture driver"

die() { echo $@ >&2; exit 1; }

((!UID)) || die "Must be root!"

(($#==2)) || die "Usage: $0 pionic_dir station_id"

PIONIC=$1
STATION=$2
BASE=$(realpath ${0%/*})

cgiserver=$BASE/cgiserver
[ -x $cgiserver ] || die "Need executable $cgiserver"

echo "Starting CGI server on station $STATION"
pkill -f cgiserver &>/dev/null || true
env -i BASE=$BASE PATH=$PATH STATION=$STATION PIONIC=$PIONIC $cgiserver $BASE 80 2>&1 &
sleep 1
pgrep -f cgiserver &>/dev/null || die "cgiserver did not start"

# use if installed
fbtext=$PIONIC/fbtools/fbtext
evdump=$PIONIC/evdump/evdump

if [ -x $fbtext ]; then
    trap 'x=$?;
          set +eu;
          echo "$0 exit $x";
          kill $(jobs -p) &>/dev/null && wait $(jobs -p);
          echo 1 > /sys/class/vtconsole/vtcon1/bind;
          tput -T linux clear > /dev/tty1;
          systemctl restart getty@tty1;
          exit $x' EXIT

    # detach console from framebuffer
    echo 0 > /sys/class/vtconsole/vtcon1/bind

    logo() { printf "TEST STATION $STATION READY" | $fbtext -cwhite:blue -gc -s40 -b1 -; }

    if [[ -x $evdump && -e /dev/input/mouse0 ]]; then
        echo "Starting logo loop"
        # We have touch, show logo and refresh on two taps within one second
        while true; do
            logo
            while true; do
                read || die "evdump unexpected EOF"
                read -t1 && break
            done
        done < <($evdump -t1 -c272 -v1 mouse0 2>/dev/null)
    else
        echo "Showing static logo"
        logo
        wait
    fi
else
    # no frame buffer, just print message and wait
    trap 'x=$?;
          set +eu;
          echo "$0 exit $x";
          kill $(jobs -p) &>/dev/null && wait $(jobs -p);
          exit $x' EXIT

    echo "Test station $STATION ready"
    wait
fi
