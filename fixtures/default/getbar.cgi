#!/bin/bash
# Read a barcode from /dev/ttyACM0

source ${0%/*}/cgi.inc

[ -c /dev/ttyACM0 ] || die "No /dev/ttyAMC0, scanner not attached?"

timeout=60
flush=0

if (($#)); then
    for o in "$@"; do
        arg=${o#*=}
        case $o in
            flush) flush=1;;
            timeout=?*) timeout=$arg;;
            *) die "Invalid option $o";;
        esac
    done
fi

{
    ((flush)) && while read -st 0; do read; done
    read -st $timeout bar || die "Timeout"
} < /dev/ttyACM0

echo $bar | tr -d $'\x0d'
