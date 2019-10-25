#!/bin/bash
# clear display or write image or text

die() { echo $0: $* >&2; exit 1; }
set -o pipefail -E -u
trap 'die "line $LINE: exit status $?"' ERR

fbclear=$PIONIC/fbtools/fbclear
[ -x $fbclear ] || die "Need executable $fbclear"

fbimage=$PIONIC/fbtools/fbimage
[ -x $fbimage ] || die "Need executable $fbimage"

fbtext=$PIONIC/fbtools/fbtext
[ -x $fbtext ] || die "Need executable $fbtext"

command=clear
fg=white
bg=black
point=20
align=nw
font=mono
wrap=

if (($#)); then
    command=$1
    shift

    for o in "$@"; do
        arg=${o#*=}
        [[ $arg ]] || die "Invalid option $o"
        case $o in
            fg=?*)              fg=$arg ;;
            bg=?*)              bg=$arg ;;
            size=?*|point=?*)   point=$arg ;;
            align=?*)           align=$arg ;;
            mono*)              font=mono ;;
            prop*)              font=prop ;;
            badge)              point=80; align=c; font=prop ;;
            wrap)               wrap=-w ;;
            *)                  die "Invalid option $o" ;;
        esac
    done
fi

case $command in
    clear)
        $fbclear -c $bg
        ;;

    image)
        image=-
        ((${CONTENT_LENGTH:-0})) || image=${0%/*}/colorbars.jpg
        $fbimage -c $bg -s $image
        ;;

    text)
        $fbtext -c $fg:$bg -s $point -g $align -f $font $wrap -b1 -
        ;;

    *) die "Invalid command $command";;
esac
