# source this file at top of a cgi

die() { echo "$*" >&2; exit 1; }

# abort on command error or undefined variable
set -o pipefail -E -u
trap 'echo "$0: line $LINENO: exit status $?" >&2; exit 1' ERR

# split QUERY_STRING to command line
[[ -v QUERY_STRING ]] && { IFS='&'; set -- $QUERY_STRING; IFS=$' \t\n'; }

# unescape + and %xx... is there a better way?
o=("$@")
for ((n=0; n<${#o[@]}; n++)); do
    p=${o[$n]//+/ }
    o[n]=$(echo -e ${p//%/\\x})
done
set -- "${o[@]}"
unset n o p

export pionic=~pi/pionic

