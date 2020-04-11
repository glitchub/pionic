#!/bin/bash -eu

# Default fixture is no fixture at all, just start cgiserver and show the logo

echo "Default fixture driver"

die() { echo $@ >&2; exit 1; }

((!UID)) || die "Must be root!"

# directory containing this script
here=${0%/*}

(($#==2)) || die "Usage: $0 pionic_dir station_id"
export PIONIC=$1
export STATION=$2

echo PIONIC=$PIONIC, STATION=$STATION

vtbind=$PIONIC/fbtools/vtbind
[[ -x $vtbind ]] || vtbind=

dispmanx=$PIONIC/dispmanx/dispmanx
[[ -x $dispmanx ]] || dispmanx=

cgiserver=$here/cgiserver
[ -x $cgiserver ] || die "Need executable $cgiserver"

(
    # Start the cgi server, if it exits within 2 seconds four times in a row then kamikaze
    pkill -f cgiserver &>/dev/null || true
    tries=0
    while true; do
        started=$SECONDS
        echo "CGI server started at T$SECONDS"
        env -i PATH=$PATH STATION=$STATION PIONIC=$PIONIC $cgiserver $here 80 || true
        stopped=$SECONDS
        echo "CGI server stopped at T$SECONDS"
        ((stopped-started <= 2)) || tries=0
        if ((++tries >= 4)); then
            echo "CGI server is borked, kamikaze"
            while true; do kill $$; done # the parent pid!
        fi
        echo "CGI server retry $tries"
    done
) &

trap 'x=$?;
      set +eu;
      echo "$0 exit $x";
      kill $(jobs -p) &>/dev/null && wait $(jobs -p);
      [[ -z $vtbind ]] || $vtbind -b 1
      exit $x' EXIT

[[ -z $vtbind ]] || $vtbind -u 1                # unbind vtcon1 from the framebuffer
[[ -z $dispmanx ]] || $here/hdmi.cgi timeout=0  # show colorbars on hdmi

# figure out what to say
[[ $STATION == local ]] && label="TEST STATION READY" || label="TEST STATION $STATION READY"

# show logo.img in pi home directory if it exists
image=~pi/logo.img
[ -f $image ] || unset image

# run the logo program, it shouldn't return
$here/logo ${image:+-i$image} $label
