#!/bin/bash

die() { echo $* >&2; exit 1; }
set -o pipefail -E -u
trap 'die "line $LINE: exit status $?"' ERR

# Options are:

#    freq=XXX.X - transmit frequency in MHz, 88.1 to 107.9, default is 99.9
#    tone=X     - modulation frequency in Hz, 10-8000, default is 1000
#    time=X     - transmit time in seconds, 0-120, default is 30. 0 just kills the current transmission.

sox=$(type -P sox) || die "Need executable sox"

pifm_sh=$PIONIC/pifm/pifm.sh
[ -x $pifm_sh ] || die "Need executable $pifm_sh"

freq=99.9
tone=1000
time=30

(($#)) && for a in "$@"; do case $a in
    freq=*) freq=${a#*=}; echo $freq | awk '{exit !(match($1,/^[0-9]+(.[0-9])?$/) && $1 >= 87.9 && $1 <= 107.9)}' || die "Invalid frequency '$freq'";;
    tone=*) tone=${a#*=}; echo $tone | awk '{exit !(match($1,/^[0-9]+$/) && $1 >= 10 && $1 <= 8000)}' || die "Invalid tone '$tone'";;
    time=*) time=${a#*=}; echo $time | awk '{exit !(match($1,/^[0-9]+$/) && $1 >= 0 && $1 <= 120)}' || die "Invalid time '$time'";;
    *) die "Invalid option $a";;
esac; done

pkill -f pifm || true
rm -f /tmp/mkfm.out

if ((time)); then
    echo "Starting '$pifm_sh -f $freq -t $tone -s $time'"
    # close popen'd stdio or cgiserver will stall
    exec 0<&- 1>&- 2>&- 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
    $pifm_sh -f $freq -t $tone -s $time > /tmp/mkfm.out 2>&1 &
fi
