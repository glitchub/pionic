#!/bin/bash
# Dump the CGI environment

me=${0##*/}
here=${0%/*}
die() { echo $me: $* >&2; exit 1; }
set -o pipefail -E -u
trap 'die "line $LINE: exit status $?"' ERR

echo I am $me
echo This is to STDOUT
echo This is to STDERR >&2

echo -------------------------------

ls -al $here

echo -------------------------------

set

echo -------------------------------

if ((${CONTENT_LENGTH:-0})); then
    echo $CONTENT_LENGTH bytes from STDIN:
    cat
    echo -------------------------------
fi

if (($#)); then
    echo $# arguments:
    printf "  %s\n" "$@"
fi

# if first param is 'choke' then return error
[[ ${1:-} != choke ]] || die "Death by bunga!"

true
