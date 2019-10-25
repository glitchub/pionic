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

        # wait for network to be up and start daemons
        while true; do
            wait=0
            if ! (($(cat /sys/class/net/eth0/carrier))); then
                echo "Ethernet is not attached"
                wait=1
            elif ! station_ip=$(ipaddr eth0); then
                echo "Waiting for station ID, MAC=$(cat /sys/class/net/eth0/address)"
                wait=1
            else
                station=${station_ip##*.}
                station=${station%/*}
            fi

            if ! [ -d /sys/class/net/eth1 ]; then
                echo "USB ethernet is not attached"
                wait=1
            fi

            if ! ipaddr br0 &>/dev/null; then
                echo "Waiting for br0"
                wait=1
            fi

            ((wait)) || break

            sleep 1
        done

        # start beacon if enabled
        ! [ -d $here/beacon ] || pgrep -f beacon &>/dev/null || $here/beacon/beacon send br0 &
        # Try to fetch the fixture driver name, note local port 61080 redirects to server port 80
        # If we don't get a response then use the default
        echo "Requesting fixture from server"
        fixture=$($curl "http://localhost:61080/cgi-bin/factory?service=fixture") || die "No response from server"
        fixture=${fixture,,}
        [[ $fixture && $fixture != none ]] || fixture=default

        echo "Using fixture '$fixture'"

        if [ -x $here/fixtures/$fixture/fixture.sh ]; then
            # use built-in fixture
            console off
            $here/fixtures/$fixture/fixture.sh $station
        else
            # otherwise try to download it
            rm -rf $tmp/fixtures
            mkdir $tmp/fixtures
            fixtures="http://localhost:61080/fixtures.tar.gz"
            echo "Fetching $fixtures..."
            $curl $fixtures | tar -C $tmp/fixtures -xz || die "Fetch failed"
            [[ -e $tmp/fixtures/$fixture ]] || die "Fixture driver '$fixture' not found"
            console off
            $tmp/fixtures/$fixture/fixture.sh $here $station
        fi

        die "Fixture '$fixture' exit status $?"
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

