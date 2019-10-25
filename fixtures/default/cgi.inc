die() { echo "$*" >&2; exit 1; }

# abort on command error or undefined variable
set -o pipefail -E -u

trap 'echo "$0: line $LINENO: exit status $?" >&2; exit 1' ERR

export pionic=~pi/pionic
