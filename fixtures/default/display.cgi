#!/bin/bash
source ${0%/*}/cgi.inc

fbclear=$pionic/fbtools/fbclear
[ -x $fbclear ] || die "Need executable $fbclear"

fbimage=$pionic/fbtools/fbimage
[ -x $fbimage ] || die "Need executable $fbimage"

fbtext=$pionic/fbtools/fbtext
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