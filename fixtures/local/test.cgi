#!/bin/bash
# Dump the CGI environment

echo -------------------------------

ls -al $BASE

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

true
