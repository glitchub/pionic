#!/bin/bash -eu

# Default fixture is no fixture at all, just start cgiserver and show the logo

echo "Default fixture driver"

die() { echo $@ >&2; exit 1; }

((!UID)) || die "Must be root!"

# directory containing this script
here=${0%/*}

(($#==2)) || die "Usage: $0 pionic_dir station_id"
PIONIC=$1
STATION=$2

# point to fbtools, if they are installed
fbtools=$PIONIC/fbtools
[ -f $fbtools/fb.bin ] || fbtools=

cgiserver=$here/cgiserver
[ -x $cgiserver ] || die "Need executable $cgiserver"

echo "Starting CGI server on station $STATION"
pkill -f cgiserver &>/dev/null || true
env -i PATH=$PATH STATION=$STATION PIONIC=$PIONIC $cgiserver $here 80 2>&1 &
sleep .5
pgrep -f cgiserver &>/dev/null || die "cgiserver did not start"

trap 'x=$?;
      set +eu;
      echo "$0 exit $x";
      kill $(jobs -p) &>/dev/null && wait $(jobs -p);
      [[ -z $fbtools ]] || $fbtools/vtbind -b 1
      exit $x' EXIT

# take over the framebuffer, if we're using it
[[ -z $fbtools ]] || $fbtools/vtbind -u 1

# figure out what to say
[[ $STATION == local ]] && label="TEST STATION READY" || label="TEST STATION $STATION READY"

# use logo image in the base directory if it exists
image=$PIONIC/logo.jpg
[ -f $image ] || unset image

# run the logo program, it shouldn't return
PIONIC=$PIONIC $here/logo ${image:+-i $image} $label
