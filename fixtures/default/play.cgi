#!/bin/bash

me=${0##*/}
here=${0%/*}
die() { echo $me: $* >&2; exit 1; }
set -o pipefail -E -u
trap 'die "line $LINE: exit status $?"' ERR

runfor=$PIONIC/runfor/runfor
[ -x $runfor ] || die "Need executable $runfor"

# Options are:
#     video=file  - file to play, default is coloarbars.mp4
#     time=X      - play time in seconds, 0-120, default is 30. 0 just kills the current play.
#     lcd         - if specified, output on lcd instead of hdmi

omxplayer=$(type -P omxplayer) || die "Need executable omxplayer"

# video files arein the same directory as this script
video=$here/colorbars.mp4
time=30
output="--display 5 -o hdmi"
display=hdmi

(($#)) && for a in "$@"; do case $a in
    video=*) video=$here/${a#*=};;
    time=*) time=${a#*=}; echo $time | awk '{exit !(match($1,/^[0-9]+$/) && $1 >= 0 && $1 <= 120)}' || die "Invalid time '$time'";;
    lcd) output="--display 4 -o local"; display=lcd;;
    *) die "Invalid option '$a'";;
esac; done

pkill -f ${omxplayer##*/} || true

if ((time)); then
    [ -f $video ] || die "No such file '$video'"
    echo "Playing $video on $display for $time seconds"
    # close popen'd stdio or cgiserver will stall
    exec 0<&- 1>&- 2>&- 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
    ( set +E; $runfor $time $omxplayer $output --blank --no-keys --no-osd --loop $video & )
fi
