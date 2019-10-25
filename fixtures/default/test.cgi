#!/bin/bash
# Dump the CGI environment
source ${0%/*}/cgi.inc

echo This is to STDOUT
echo This is to STDERR >&2

echo -------------------------------

set

echo -------------------------------

if (($#)); then
    echo $# arguments:
    printf "  %s\n" "$@"
fi

[[ ${1:-} != choke ]] || die "Death by bunga!"
