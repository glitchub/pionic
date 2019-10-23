#!/bin/bash
source ${0%/*}/cgi.inc

((!UID)) || die "Must be root!"

usage="Usage:

    mkfm [options]
    -or-
    curl http://172.31.255.1/cgi/mkfm[?option[&option...]]

Options are:

    freq=XXX.X - transmit frequency in MHz, 88.1 to 107.9, default is 99.9
    tone=X     - modulation frequency in Hz, 10-8000, default is 1000
    time=X     - transmit time in seconds, 0-120, default is 30. 0 just kills the current transmission.
"

sox=$(type -P sox) || die "Need executable sox"

pifm=$pionic/pifm/pifm
[ -x $pifm ] || die "Need executable $pifm"

pifm_sh=$pionic/pifm/pifm.sh
[ -x $pifm_sh ] || die "Need executable $pifm_sh"

freq=99.9
tone=1000
time=30

(($#)) && for a in "$@"; do case $a in
    freq=*) freq=${a#*=}; echo $freq | awk '{exit !(match($1,/^[0-9]+(.[0-9])?$/) && $1 >= 87.9 && $1 <= 107.9)}' || die "Invalid frequency '$freq'";;
    tone=*) tone=${a#*=}; echo $tone | awk '{exit !(match($1,/^[0-9]+$/) && $1 >= 10 && $1 <= 8000)}' || die "Invalid tone '$tone'";;
    time=*) time=${a#*=}; echo $time | awk '{exit !(match($1,/^[0-9]+$/) && $1 >= 0 && $1 <= 120)}' || die "Invalid time '$time'";;
    *) exit 1 # die "$usage"
esac; done

pkill -f ${pifm##*/} || true
if ((time)); then
    # close popen'd stdio or cgiserver will stall
    [ -t 1 ] || exec 0<&- 1>&- 2>&- 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
    ( set +E; $pifm_sh -f $freq -t $tone -s $time & )
fi
