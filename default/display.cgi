#!/bin/bash
# clear display or write image or text

die() { echo $* >&2; exit 1; }
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
wrap=0


if (($#)); then
    command=$1
    shift

    for o in "$@"; do
        arg=${o#*=}
        [[ $arg ]] || die "Invalid option $o"
        case $o in
            fg=?*)              fg=$arg ;;
            bg=?*)              bg=$arg ;;
            badge)              point="<80"; align="c"; wrap=1 ;;
            size=?*|point=?*)   point=$arg ;;
            align=?*)           align=$arg ;;
            wrap)               wrap=1 ;;
            mono*|prop*)        ;;
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
        # A font with good Spanish and Chinese support
        font=${0%/*}/WenQuanYiMicroHeiMono.ttf
        style=
        [[ $point ]] && style+=$point
        [[ $align ]] && style+="@$align"
        (( wrap )) && style+="#"
        $fbtext -c $fg:$bg -f $font -s $style -b1 -
        ;;

    *) die "Invalid command $command";;
esac
