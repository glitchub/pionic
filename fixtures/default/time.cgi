#!/bin/bash
# Return current time in epoch seconds and HHMMmmddYYYY.SS (UCT)

die() { echo $* >&2; exit 1; }
set -o pipefail -E -u
trap 'die "line $LINE: exit status $?"' ERR

date -u +"%s %H%M%m%d%Y.%S"
