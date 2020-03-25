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

trap 'x=$?;
      set +eu;
      echo "$0 exit $x";
      kill $(jobs -p) &>/dev/null && wait $(jobs -p);
      $PIONIC/fbtools/vtbind -b 1
      exit $x' EXIT

$PIONIC/fbtools/vtbind -u 1

# use logo image in the base directory if it exists
image=$PIONIC/logo.jpg
[ -f $image ] || unset image
./logo ${image:+-i $image} TEST STATION $STATION READY
