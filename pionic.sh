#!/bin/bash -eu

# This starts the test station operation. It runs in background at boot.

# Report errors before exit, this tries to look like the 'unbound variable' error
trap 'echo $0: line $LINENO: exit status $? >&2' ERR

# abort with a message
die() { echo "$0: $*" >&2; exit 1; }

grep -q Raspberry /etc/rpi-issue &>/dev/null || die "Requires a Raspberry Pi"
((UID==0)) || die "Must be run as root"

here=$(realpath ${0%/*})

# Return ip address for interface $1 and true, or false if no IP
ipaddr() { local s=$(ip -4 -o a show dev $1 2>/dev/null | awk '{print $4}'); [[ $s ]] && echo $s; }

# Where to put temp files, cgi/factory also needs to know this
tmp=/tmp/pionic

# curl timeout after 4 seconds, -q=disable curl.config, -s=silent (no status), -S=show error, -f=fail with exit status 22
curl="curl --connect-timeout 2 -qsSf"

# turn console on and off
console()
{
    case "$1" in
        off)
            setterm --cursor off > /dev/tty1
            echo 0 > /sys/class/vtconsole/vtcon1/bind
            dmesg -n 1
            ;;
        *)
            echo 1 > /sys/class/vtconsole/vtcon1/bind
            setterm --cursor on > /dev/tty1
            ;;
    esac
    true
}

case "${1:-}" in
    start)
        (
        # store the subshell pid
        mkdir -p $tmp
        echo $BASHPID > $tmp/.pid
        
        # after this point, kill shell children on exit and reinstate console
        trap 'exs=$?;
            kill $(jobs -p) &>/dev/null && wait $(jobs -p) || true;
            console on || true;
            exit $exs' EXIT

        # wait for ethernet and usb dongle
        while true; do
            wait=0
            if ! station_ip=$(ipaddr eth0); then
                if ! (($(cat /sys/class/net/eth0/carrier))); then
                    echo "Ethernet is unplugged"
                 else
                    echo "Waiting for DHCP on MAC $(cat /sys/class/net/eth0/address)"
                fi
                wait=1
            else
                station=${station_ip##*.}
                station=${station%/*}
            fi

            if ! lan_ip=$(ipaddr eth1); then
                if ! [ -d /sys/class/net/eth1 ]; then
                    echo "USB ethernet is not attached"
                else
                    # dhcpcd should bring it up soon
                    echo "Waiting for IP on USB ethernet"
                fi
                wait=1
            else
                if ! pgrep -f cgiserver &>/dev/null; then
                    echo "Starting cgi server"
                    $here/cgiserver -p 80 -d ~pi/pionic/cgi &
                    wait=1
                fi
                if [ -d $here/beacon ] && ! pgrep -f beacon; then
                    # advertise our ip
                    echo "Starting beacon server"
                    $here/beacon/beacon send eth1 $station_ip &
                    wait=1
                fi
            fi

            ((wait)) || break

            sleep 1
        done

        # now try to fetch the fixture driver, note local port 61080 redirects to server port 80
        # If we don't get a response then just assume 'None'
        echo "Requesting fixture from server"
        fixture=$($curl "http://localhost:61080/cgi-bin/factory?service=fixture") 
        fixture=${fixture,,}
        [[ $fixture && $fixture != none ]] || fixture=default
        
        echo "Using fixture '$fixture'"

        if [ -x $here/fixtures/$fixture ]; then
            # use built-in fixture driver
            console off
            $here/fixtures/$fixture $here $station
        else
            # otherwise try to download it
            rm -rf $tmp/fixtures
            mkdir $tmp/fixtures
            fixtures="http://localhost:61080/fixtures.tar.gz"
            echo "Fetching $fixtures..."
            $curl $fixtures | tar -C $tmp/fixtures -xz || die "Failed to fetch fixture tarball"
            [[ -e $tmp/fixtures/$fixture ]] || die "Fixture driver not found"
            console off
            $tmp/fixtures/$fixture $here $station
        fi  
        
        # but die if it doesn't
        die "Fixture driver '$fixture' returned"
        ) &
        ;;

    stop)
        if [ -e $tmp/.pid ]; then
            kill $(cat $tmp/.pid) &>/dev/null || true
            rm -f $tmp/.pid
        fi
        ;;

    res*)
        $0 stop
        exec $0 start
        ;;

    *)  die "Usage: $0 stop | start | restart"
        ;;
esac
true

