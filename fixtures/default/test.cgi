#!/bin/bash
# Dump the CGI environment

die() { echo $0: $* >&2; exit 1; }
set -o pipefail -E -u
trap 'die "line $LINE: exit status $?"' ERR

echo This is to STDOUT
echo This is to STDERR >&2

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
