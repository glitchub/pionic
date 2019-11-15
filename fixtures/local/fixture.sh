#!/bin/bash -eu

# Local test fixture, just start the cgi-server and spin.

echo "Local fixture driver"

die() { echo $@ >&2; exit 1; }

((!UID)) || die "Must be root!"

(($#==1)) || die "Usage: $0 pionic_dir"

PIONIC=$1
BASE=$(realpath ${0%/*})

# nuke children on exit
trap 'x=$?;
      set +eu;
      kill $(jobs -p) &>/dev/null && wait $(jobs -p);
      $PIONIC/fbtools/fbclear
      (($x)) && echo EXIT $x;
      exit $x' EXIT

cgiserver=$BASE/cgiserver
[ -x $cgiserver ] || die "Need executable $cgiserver"

echo "Starting CGI serverON"
pkill -f cgiserver &>/dev/null || true
env -i BASE=$BASE PATH=$PATH STATION=$STATION PIONIC=$PIONIC $cgiserver $BASE 80 2>&1 | logger &
sleep 1
pgrep -f cgiserver &>/dev/null || die "cgiserver did not start"
wait
